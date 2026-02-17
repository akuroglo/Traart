"""Speaker diarization using pyannote.audio.

Identifies and separates different speakers in audio files.
Uses pyannote/speaker-diarization-3.1 with local model loading.
"""

import sys
import os
import warnings
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

import torch

# Fallback token for pyannote model download (read-only, MIT-licensed models)
_HF_TOKEN = os.environ.get("HF_TOKEN", "")

_PYANNOTE_MODELS = [
    "pyannote/speaker-diarization-3.1",
    "pyannote/segmentation-3.0",
]


@dataclass
class Segment:
    start: float
    end: float
    speaker_id: str


def _select_device() -> torch.device:
    """Select best available device: MPS for Apple Silicon, otherwise CPU."""
    if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


def _ensure_pyannote_models(models_dir: Optional[str] = None):
    """Download pyannote models if missing. Uses embedded HF token."""
    if not _HF_TOKEN:
        return

    if models_dir:
        pyannote_dir = os.path.join(models_dir, "pyannote")
    else:
        pyannote_dir = os.path.expanduser("~/.cache/pyannote")

    for model_id in _PYANNOTE_MODELS:
        model_name = model_id.split("/")[-1]
        target_dir = os.path.join(pyannote_dir, model_name)

        if os.path.isdir(target_dir) and any(os.scandir(target_dir)):
            continue

        try:
            from huggingface_hub import snapshot_download
            print(f"Downloading {model_id}...", file=sys.stderr)
            snapshot_download(
                repo_id=model_id,
                token=_HF_TOKEN,
                local_dir=target_dir,
            )
        except Exception as e:
            print(f"Warning: could not download {model_id}: {e}", file=sys.stderr)


def _load_pipeline(models_dir: Optional[str] = None):
    """Load pyannote speaker diarization pipeline.

    If models_dir is provided, loads from local directory.
    Otherwise falls back to HuggingFace Hub cache.
    Auto-downloads models if missing.

    Temporarily patches torch.load with weights_only=False for pyannote
    compatibility with PyTorch 2.6+, then restores the original immediately.
    """
    # Auto-download if missing
    _ensure_pyannote_models(models_dir)

    _original_torch_load = torch.load

    def _patched_load(*args, **kwargs):
        kwargs["weights_only"] = False
        return _original_torch_load(*args, **kwargs)

    torch.load = _patched_load
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            from pyannote.audio import Pipeline

            if models_dir:
                diarization_dir = os.path.join(models_dir, "pyannote", "speaker-diarization-3.1")
                if os.path.isdir(diarization_dir):
                    pipeline = Pipeline.from_pretrained(diarization_dir)
                else:
                    pipeline = Pipeline.from_pretrained(
                        "pyannote/speaker-diarization-3.1",
                        use_auth_token=_HF_TOKEN,
                    )
            else:
                pipeline = Pipeline.from_pretrained(
                    "pyannote/speaker-diarization-3.1",
                    use_auth_token=_HF_TOKEN,
                )
    finally:
        torch.load = _original_torch_load

    return pipeline


def _merge_segments(segments: List[Segment], gap_threshold: float = 1.0) -> List[Segment]:
    """Merge consecutive segments from the same speaker if gap < threshold."""
    if not segments:
        return segments

    merged = [segments[0]]
    for seg in segments[1:]:
        prev = merged[-1]
        if seg.speaker_id == prev.speaker_id and (seg.start - prev.end) < gap_threshold:
            merged[-1] = Segment(start=prev.start, end=seg.end, speaker_id=prev.speaker_id)
        else:
            merged.append(seg)

    return merged


def _filter_short(segments: List[Segment], min_duration: float = 0.3) -> List[Segment]:
    """Filter out segments shorter than min_duration."""
    return [s for s in segments if (s.end - s.start) >= min_duration]


def diarize(
    audio_path: str,
    num_speakers: Optional[int] = None,
    models_dir: Optional[str] = None,
    gap_threshold: float = 1.0,
    min_duration: float = 0.3,
) -> List[Segment]:
    """Run speaker diarization on an audio file.

    Args:
        audio_path: Path to audio file (16kHz mono WAV preferred).
        num_speakers: Expected number of speakers (improves accuracy).
        models_dir: Directory containing pre-downloaded models.
        gap_threshold: Max gap between same-speaker segments to merge.
        min_duration: Minimum segment duration to keep.

    Returns:
        List of Segment(start, end, speaker_id) sorted by start time.
    """
    device = _select_device()
    pipeline = _load_pipeline(models_dir)
    if pipeline is None:
        raise RuntimeError(
            "Pyannote pipeline не загружен. "
            "Для диаризации нужен HF_TOKEN (huggingface.co/settings/tokens). "
            "Без него транскрибация будет работать без разделения по спикерам."
        )
    pipeline = pipeline.to(device)

    kwargs = {}
    if num_speakers is not None:
        kwargs["num_speakers"] = num_speakers

    diarization_result = pipeline(audio_path, **kwargs)

    segments = []
    for turn, _, speaker in diarization_result.itertracks(yield_label=True):
        segments.append(Segment(start=turn.start, end=turn.end, speaker_id=speaker))

    segments = _merge_segments(segments, gap_threshold=gap_threshold)
    segments = _filter_short(segments, min_duration=min_duration)

    return segments
