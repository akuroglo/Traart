#!/usr/bin/env python3
"""GigaAM v3 transcription engine for Traart.

CLI interface for transcribing audio/video files using GigaAM v3 e2e_rnnt model.
Supports speaker diarization via pyannote.audio.

Usage:
    python transcribe.py <input_file> <output_file> [options]

Options:
    --diarize           Enable speaker diarization
    --speakers N        Expected number of speakers (default: 2)
    --models-dir PATH   Directory containing pre-downloaded models
    --format FORMAT     Output format: md, txt, json, srt or vtt (default: md)
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import shutil

import torch
import torchaudio


def _find_ffmpeg() -> str:
    """Find ffmpeg binary, checking common paths on macOS."""
    # Check if already in PATH
    path = shutil.which("ffmpeg")
    if path:
        return path
    # Common macOS locations
    for candidate in [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg",
    ]:
        if os.path.isfile(candidate):
            return candidate
    # Fallback: static-ffmpeg pip package (bundled binary)
    try:
        import static_ffmpeg
        static_ffmpeg.add_paths()
        path = shutil.which("ffmpeg")
        if path:
            return path
    except ImportError:
        pass
    raise RuntimeError("ffmpeg not found. Install with: brew install ffmpeg")


FFMPEG_PATH = _find_ffmpeg()

SUPPORTED_EXTENSIONS = {
    # Audio
    ".wav", ".mp3", ".m4a", ".flac", ".ogg", ".oga", ".opus",
    ".aac", ".wma", ".amr", ".m4b", ".mp2", ".aiff", ".aif",
    # Video
    ".mp4", ".mkv", ".webm", ".mov", ".avi", ".wmv", ".m4v",
}

SAMPLE_RATE = 16000


def report_progress(progress: float, step: str, detail: str = "", eta_seconds=None):
    """Report progress as JSON line to stderr for Swift app to parse."""
    msg = {"progress": round(progress, 3), "step": step}
    if detail:
        msg["detail"] = detail
    if eta_seconds is not None:
        msg["eta_seconds"] = eta_seconds
    sys.stderr.write(json.dumps(msg, ensure_ascii=False) + "\n")
    sys.stderr.flush()


def report_error(message: str):
    """Report error as JSON line to stderr."""
    sys.stderr.write(json.dumps({"error": message}, ensure_ascii=False) + "\n")
    sys.stderr.flush()


# Collect warnings during transcription
_warnings: List[str] = []


def report_warning(message: str):
    """Report and collect a warning."""
    _warnings.append(message)
    sys.stderr.write(json.dumps({"warning": message}, ensure_ascii=False) + "\n")
    sys.stderr.flush()


def report_warnings_summary():
    """Report collected warnings summary to stderr."""
    if _warnings:
        sys.stderr.write(json.dumps({
            "warnings_count": len(_warnings),
            "warnings": _warnings[:20],  # limit to 20
        }, ensure_ascii=False) + "\n")
        sys.stderr.flush()


def select_device() -> torch.device:
    """Select best available device."""
    if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


def convert_to_wav(input_path: str) -> Tuple[str, bool]:
    """Convert audio/video to 16kHz mono WAV via ffmpeg.

    Returns:
        Tuple of (wav_path, was_converted). If was_converted is True,
        the caller is responsible for cleaning up the temp file.
    """
    cmd = [
        FFMPEG_PATH, "-y", "-hide_banner", "-loglevel", "error",
        "-i", input_path,
        "-ar", str(SAMPLE_RATE),
        "-ac", "1",
        "-c:a", "pcm_s16le",
    ]

    temp_fd, temp_path = tempfile.mkstemp(suffix=".wav")
    os.close(temp_fd)
    cmd.append(temp_path)

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            os.remove(temp_path)
            raise RuntimeError(f"ffmpeg conversion failed: {result.stderr.strip()}")
        return temp_path, True
    except FileNotFoundError:
        os.remove(temp_path)
        raise RuntimeError("ffmpeg not found. Install with: brew install ffmpeg")
    except subprocess.TimeoutExpired:
        os.remove(temp_path)
        raise RuntimeError("ffmpeg conversion timed out after 300 seconds")


def get_audio_duration(audio_path: str) -> float:
    """Get audio duration in seconds using ffprobe."""
    try:
        result = subprocess.run(
            [
                FFMPEG_PATH.replace("ffmpeg", "ffprobe"), "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                audio_path,
            ],
            capture_output=True, text=True, timeout=30,
        )
        return float(result.stdout.strip())
    except Exception:
        return 0.0


def load_asr_model(models_dir: Optional[str] = None):
    """Load GigaAM v3 e2e_rnnt model."""
    import gigaam

    kwargs = {}
    device = select_device()

    # Disable fp16 for CPU and MPS (MPS fp16 can be unstable)
    if device.type != "cuda":
        kwargs["fp16_encoder"] = False

    if models_dir:
        gigaam_dir = os.path.join(models_dir, "gigaam")
        if os.path.isdir(gigaam_dir):
            kwargs["download_root"] = gigaam_dir

    kwargs["device"] = device
    try:
        model = gigaam.load_model("v3_e2e_rnnt", **kwargs)
    except Exception as e:
        import traceback
        report_error(f"Failed to load GigaAM model: {e}\n{traceback.format_exc()}")
        raise
    if model is None:
        raise RuntimeError("gigaam.load_model returned None — model may be corrupted")
    return model


def transcribe_chunk(model, audio_tensor: torch.Tensor, sr: int) -> str:
    """Transcribe a single audio chunk using GigaAM model.

    The chunk is saved to a temp WAV file and passed to the model.
    """
    if len(audio_tensor) < sr * 0.1:
        return ""

    temp_fd, temp_path = tempfile.mkstemp(suffix=".wav")
    os.close(temp_fd)

    try:
        torchaudio.save(temp_path, audio_tensor.unsqueeze(0), sr)
        text = model.transcribe(temp_path)
        return text.strip()
    except Exception as e:
        duration = len(audio_tensor) / sr
        report_warning(f"Не удалось распознать чанк ({duration:.1f}с): {e}")
        return ""
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)


def transcribe_audio(
    audio_tensor: torch.Tensor,
    sr: int,
    model,
    progress_offset: float = 0.0,
    progress_scale: float = 1.0,
    chunk_duration: int = 20,
    chunk_overlap: int = 4,
) -> Tuple[str, List[Dict]]:
    """Transcribe full audio by chunking into segments.

    Returns:
        Tuple of (full_text, segments_list).
    """
    total_samples = len(audio_tensor)
    chunk_samples = int(chunk_duration * sr)
    step_samples = int((chunk_duration - chunk_overlap) * sr)

    if total_samples <= chunk_samples:
        report_progress(progress_offset + progress_scale * 0.1, "transcribing", "single chunk")
        text = transcribe_chunk(model, audio_tensor, sr)
        report_progress(progress_offset + progress_scale, "transcribing", "chunk 1/1")
        segments = []
        if text:
            segments.append({
                "start": 0.0,
                "end": total_samples / sr,
                "text": text,
            })
        return text, segments

    chunks = []
    for start in range(0, total_samples, step_samples):
        end = min(start + chunk_samples, total_samples)
        if (end - start) < sr * 0.3:
            break
        chunks.append((start, end))

    texts = []
    segments = []
    total_chunks = len(chunks)
    chunk_times = []

    for i, (start_sample, end_sample) in enumerate(chunks):
        t0 = time.monotonic()
        chunk = audio_tensor[start_sample:end_sample]
        text = transcribe_chunk(model, chunk, sr)
        chunk_times.append(time.monotonic() - t0)

        if text:
            texts.append(text)
            segments.append({
                "start": round(start_sample / sr, 2),
                "end": round(end_sample / sr, 2),
                "text": text,
            })

        eta = None
        if len(chunk_times) >= 2:
            avg = sum(chunk_times) / len(chunk_times)
            eta = round(avg * (total_chunks - i - 1), 1)

        progress = progress_offset + progress_scale * ((i + 1) / total_chunks)
        report_progress(progress, "transcribing", f"chunk {i + 1}/{total_chunks}", eta_seconds=eta)

    full_text = " ".join(texts)
    return full_text, segments


def transcribe_with_diarization(
    wav_path: str,
    audio_tensor: torch.Tensor,
    sr: int,
    model,
    num_speakers: Optional[int] = None,
    models_dir: Optional[str] = None,
    chunk_duration: int = 20,
    chunk_overlap: int = 4,
    merge_gap: float = 0.8,
    min_segment: float = 0.2,
    expansion_pad: int = 3,
) -> Tuple[str, List[Dict]]:
    """Transcribe with speaker diarization.

    Returns:
        Tuple of (full_text, segments_with_speakers).
    """
    from diarize import diarize

    report_progress(0.16, "diarizing", "running speaker diarization")
    diar_segments = diarize(
        wav_path, num_speakers=num_speakers, models_dir=models_dir,
        gap_threshold=merge_gap, min_duration=min_segment,
    )
    report_progress(0.35, "diarizing", f"found {len(diar_segments)} segments")

    results = []
    total_segments = len(diar_segments)
    total_audio_samples = len(audio_tensor)
    segment_times = []

    for i, seg in enumerate(diar_segments):
        t0 = time.monotonic()
        start_sample = int(seg.start * sr)
        end_sample = int(seg.end * sr)
        segment_audio = audio_tensor[start_sample:end_sample]

        duration = (end_sample - start_sample) / sr

        if duration > chunk_duration - chunk_overlap:
            chunk_samples = int(chunk_duration * sr)
            step_s = int((chunk_duration - chunk_overlap) * sr)
            parts = []
            for chunk_start in range(0, len(segment_audio), step_s):
                chunk = segment_audio[chunk_start:chunk_start + chunk_samples]
                if len(chunk) < sr * 0.3:
                    break
                text = transcribe_chunk(model, chunk, sr)
                if text:
                    parts.append(text)
            text = " ".join(parts)
        else:
            text = transcribe_chunk(model, segment_audio, sr)

        # If segment returned empty text, retry with expanded context
        if not text and duration >= 0.5:
            pad = int(expansion_pad * sr)
            expanded_start = max(0, start_sample - pad)
            expanded_end = min(total_audio_samples, end_sample + pad)
            expanded_audio = audio_tensor[expanded_start:expanded_end]
            text = transcribe_chunk(model, expanded_audio, sr)

        if text:
            results.append({
                "start": round(seg.start, 2),
                "end": round(seg.end, 2),
                "speaker": seg.speaker_id,
                "text": text,
            })
        elif duration >= 0.5:
            # Keep the segment as a placeholder so user sees full timeline
            report_warning(
                f"Пустой сегмент {seg.speaker_id} "
                f"[{seg.start:.1f}–{seg.end:.1f}с] ({duration:.1f}с)"
            )
            results.append({
                "start": round(seg.start, 2),
                "end": round(seg.end, 2),
                "speaker": seg.speaker_id,
                "text": "[...]",
            })

        segment_times.append(time.monotonic() - t0)

        eta = None
        if len(segment_times) >= 2:
            avg = sum(segment_times) / len(segment_times)
            eta = round(avg * (total_segments - i - 1), 1)

        progress = 0.35 + 0.6 * ((i + 1) / total_segments)
        report_progress(progress, "transcribing", f"segment {i + 1}/{total_segments}", eta_seconds=eta)

    # Fallback: if diarization missed the tail of the audio (>10s gap),
    # transcribe the remaining portion using chunk-based approach
    audio_duration = total_audio_samples / sr
    last_diar_end = diar_segments[-1].end if diar_segments else 0
    tail_gap = audio_duration - last_diar_end

    if tail_gap > 10:
        tail_start_sample = int(last_diar_end * sr)
        tail_audio = audio_tensor[tail_start_sample:]
        report_progress(0.95, "transcribing", "processing undetected tail audio")

        chunk_samples = int(chunk_duration * sr)
        step_samples = int((chunk_duration - chunk_overlap) * sr)
        for chunk_start in range(0, len(tail_audio), step_samples):
            chunk = tail_audio[chunk_start:chunk_start + chunk_samples]
            if len(chunk) < sr * 0.3:
                break
            text = transcribe_chunk(model, chunk, sr)
            if text:
                abs_start = last_diar_end + chunk_start / sr
                abs_end = last_diar_end + min(chunk_start + chunk_samples, len(tail_audio)) / sr
                results.append({
                    "start": round(abs_start, 2),
                    "end": round(abs_end, 2),
                    "speaker": "",
                    "text": text,
                })

    # Merge consecutive segments from same speaker with small gap
    merged = []
    for r in results:
        if (merged
                and merged[-1]["speaker"] == r["speaker"]
                and r["speaker"] != ""
                and (r["start"] - merged[-1]["end"]) < merge_gap):
            merged[-1]["end"] = r["end"]
            merged[-1]["text"] += " " + r["text"]
        else:
            merged.append(dict(r))

    full_text = " ".join(r["text"] for r in merged)
    return full_text, merged


def format_output_json(
    source: str,
    duration: float,
    diarization: bool,
    speakers: int,
    full_text: str,
    segments: List[Dict],
) -> str:
    """Format output as JSON."""
    result = {
        "source": source,
        "duration": round(duration, 1),
        "diarization": diarization,
        "speakers": speakers,
        "text": full_text,
        "segments": segments,
    }
    return json.dumps(result, ensure_ascii=False, indent=2)


def format_output_md(
    source: str,
    duration: float,
    diarization: bool,
    speakers: int,
    full_text: str,
    segments: List[Dict],
) -> str:
    """Format output as Markdown."""
    source_name = Path(source).stem
    lines = []
    lines.append(f"# Транскрипция: {source_name}")
    lines.append("")

    dur_min = int(duration // 60)
    dur_sec = int(duration % 60)
    lines.append(f"**Длительность:** {dur_min} мин {dur_sec} сек")
    if diarization and speakers > 0:
        lines.append(f"**Спикеров:** {speakers}")
    lines.append(f"**Файл:** `{Path(source).name}`")
    lines.append("")
    lines.append("---")
    lines.append("")

    if diarization and segments and any(s.get("speaker") for s in segments):
        current_speaker = None
        for seg in segments:
            speaker = seg.get("speaker", "")
            start_m, start_s = divmod(int(seg["start"]), 60)
            end_m, end_s = divmod(int(seg["end"]), 60)
            time_str = f"{start_m:02d}:{start_s:02d}"

            if speaker and speaker != current_speaker:
                lines.append(f"### {speaker}")
                lines.append("")
                current_speaker = speaker

            lines.append(f"*[{time_str}]* {seg['text']}")
            lines.append("")
    elif segments and len(segments) > 1:
        for seg in segments:
            start_m, start_s = divmod(int(seg["start"]), 60)
            time_str = f"{start_m:02d}:{start_s:02d}"
            lines.append(f"*[{time_str}]* {seg['text']}")
            lines.append("")
    else:
        lines.append(full_text)
        lines.append("")

    return "\n".join(lines)


def format_output_txt(
    source: str,
    duration: float,
    diarization: bool,
    full_text: str,
    segments: List[Dict],
) -> str:
    """Format output as plain text."""
    lines = []
    lines.append(f"Source: {source}")
    lines.append(f"Duration: {duration / 60:.1f} min")
    lines.append("=" * 50)
    lines.append("")

    if diarization and segments:
        for seg in segments:
            speaker = seg.get("speaker", "")
            start_m, start_s = divmod(int(seg["start"]), 60)
            end_m, end_s = divmod(int(seg["end"]), 60)
            time_str = f"[{start_m:02d}:{start_s:02d} - {end_m:02d}:{end_s:02d}]"
            if speaker:
                lines.append(f"{time_str} {speaker}:")
            else:
                lines.append(f"{time_str}")
            lines.append(f"  {seg['text']}")
            lines.append("")
    else:
        lines.append(full_text)

    return "\n".join(lines)


def _format_ts_srt(seconds: float) -> str:
    """Format seconds as SRT timestamp: HH:MM:SS,mmm"""
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int(round((seconds - int(seconds)) * 1000))
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def _format_ts_vtt(seconds: float) -> str:
    """Format seconds as VTT timestamp: HH:MM:SS.mmm"""
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int(round((seconds - int(seconds)) * 1000))
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"


def format_output_srt(
    segments: List[Dict],
    diarization: bool,
) -> str:
    """Format output as SRT subtitles."""
    lines = []
    for i, seg in enumerate(segments, 1):
        lines.append(str(i))
        start_ts = _format_ts_srt(seg["start"])
        end_ts = _format_ts_srt(seg["end"])
        lines.append(f"{start_ts} --> {end_ts}")
        speaker = seg.get("speaker", "")
        text = seg["text"]
        if diarization and speaker:
            lines.append(f"[{speaker}] {text}")
        else:
            lines.append(text)
        lines.append("")
    return "\n".join(lines)


def format_output_vtt(
    segments: List[Dict],
    diarization: bool,
) -> str:
    """Format output as WebVTT subtitles."""
    lines = ["WEBVTT", ""]
    for seg in segments:
        start_ts = _format_ts_vtt(seg["start"])
        end_ts = _format_ts_vtt(seg["end"])
        lines.append(f"{start_ts} --> {end_ts}")
        speaker = seg.get("speaker", "")
        text = seg["text"]
        if diarization and speaker:
            lines.append(f"<v {speaker}>{text}")
        else:
            lines.append(text)
        lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Traart transcription engine (GigaAM v3)")
    parser.add_argument("input_file", help="Path to audio/video file")
    parser.add_argument("output_file", help="Path for output file")
    parser.add_argument("--diarize", action="store_true", help="Enable speaker diarization")
    parser.add_argument("--speakers", type=int, default=0, help="Expected number of speakers (0 = auto-detect)")
    parser.add_argument("--models-dir", type=str, default=None, help="Directory with pre-downloaded models")
    parser.add_argument("--format", type=str, default="md", choices=["md", "json", "txt", "srt", "vtt"], help="Output format")
    parser.add_argument("--chunk-duration", type=int, default=20, help="Chunk duration in seconds (10-60)")
    parser.add_argument("--chunk-overlap", type=int, default=4, help="Chunk overlap in seconds (0-10)")
    parser.add_argument("--merge-gap", type=float, default=0.8, help="Max gap to merge same-speaker segments (0.2-5.0)")
    parser.add_argument("--min-segment", type=float, default=0.2, help="Min segment duration in seconds (0.1-1.0)")
    parser.add_argument("--expansion-pad", type=int, default=3, help="Expansion padding for empty segments in seconds (0-10)")
    args = parser.parse_args()

    input_path = os.path.abspath(args.input_file)
    output_path = os.path.abspath(args.output_file)

    if not os.path.exists(input_path):
        report_error(f"Input file not found: {input_path}")
        sys.exit(1)

    ext = Path(input_path).suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        report_error(f"Unsupported file format: {ext}")
        sys.exit(1)

    converted_path = None
    try:
        report_progress(0.01, "preparing", "converting audio")

        duration = get_audio_duration(input_path)

        wav_path, was_converted = convert_to_wav(input_path)
        if was_converted:
            converted_path = wav_path

        report_progress(0.03, "preparing", "loading audio")

        audio, sr = torchaudio.load(wav_path)
        if sr != SAMPLE_RATE:
            audio = torchaudio.functional.resample(audio, sr, SAMPLE_RATE)
            sr = SAMPLE_RATE
        audio = audio.mean(dim=0)  # mono

        if duration <= 0:
            duration = len(audio) / sr

        report_progress(0.05, "loading_model", "loading GigaAM v3")

        # Heartbeat during model loading so progress doesn't freeze
        model_loaded = threading.Event()
        def _model_heartbeat():
            p = 0.05
            while not model_loaded.is_set():
                model_loaded.wait(timeout=1.5)
                if not model_loaded.is_set():
                    p = min(p + 0.008, 0.13)
                    report_progress(p, "loading_model", "loading GigaAM v3")

        hb = threading.Thread(target=_model_heartbeat, daemon=True)
        hb.start()
        model = load_asr_model(args.models_dir)
        model_loaded.set()
        report_progress(0.14, "loading_model", "model ready")

        if args.diarize:
            num_spk = args.speakers if args.speakers > 0 else None
            try:
                full_text, segments = transcribe_with_diarization(
                    wav_path, audio, sr, model,
                    num_speakers=num_spk,
                    models_dir=args.models_dir,
                    chunk_duration=args.chunk_duration,
                    chunk_overlap=args.chunk_overlap,
                    merge_gap=args.merge_gap,
                    min_segment=args.min_segment,
                    expansion_pad=args.expansion_pad,
                )
                num_speakers = len(set(s.get("speaker", "") for s in segments))
            except Exception as e:
                # Diarization failed — fall back to plain transcription
                report_warning(f"Диаризация недоступна: {e}")
                report_progress(0.15, "transcribing", "fallback: транскрибация без диаризации")
                args.diarize = False
                full_text, segments = transcribe_audio(
                    audio, sr, model,
                    progress_offset=0.15,
                    progress_scale=0.78,
                    chunk_duration=args.chunk_duration,
                    chunk_overlap=args.chunk_overlap,
                )
                num_speakers = 0
        else:
            report_progress(0.15, "transcribing", "starting transcription")
            full_text, segments = transcribe_audio(
                audio, sr, model,
                progress_offset=0.15,
                progress_scale=0.78,
                chunk_duration=args.chunk_duration,
                chunk_overlap=args.chunk_overlap,
            )
            num_speakers = 0

        report_progress(0.95, "saving", "writing output")

        if args.format == "json":
            output = format_output_json(
                source=input_path,
                duration=duration,
                diarization=args.diarize,
                speakers=num_speakers,
                full_text=full_text,
                segments=segments,
            )
        elif args.format == "md":
            output = format_output_md(
                source=input_path,
                duration=duration,
                diarization=args.diarize,
                speakers=num_speakers,
                full_text=full_text,
                segments=segments,
            )
        elif args.format == "srt":
            output = format_output_srt(
                segments=segments,
                diarization=args.diarize,
            )
        elif args.format == "vtt":
            output = format_output_vtt(
                segments=segments,
                diarization=args.diarize,
            )
        else:
            output = format_output_txt(
                source=input_path,
                duration=duration,
                diarization=args.diarize,
                full_text=full_text,
                segments=segments,
            )

        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(output)

        report_warnings_summary()
        report_progress(1.0, "complete", f"saved to {output_path}")

    except Exception as e:
        report_error(str(e))
        sys.exit(1)

    finally:
        if converted_path and os.path.exists(converted_path):
            os.remove(converted_path)


if __name__ == "__main__":
    main()
