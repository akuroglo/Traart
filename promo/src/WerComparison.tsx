import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  interpolate,
  spring,
  useVideoConfig,
} from "remotion";
import { C } from "./shared/colors";
import { ease } from "./shared/animation";

interface BarData {
  label: string;
  sublabel: string;
  wer: number;
  color: string;
  highlighted: boolean;
  delay: number;
}

const bars: BarData[] = [
  {
    label: "GigaAM v3",
    sublabel: "Traart",
    wer: 8.3,
    color: C.green,
    highlighted: true,
    delay: 0,
  },
  {
    label: "Yandex SpeechKit",
    sublabel: "",
    wer: 10,
    color: C.yellow,
    highlighted: false,
    delay: 8,
  },
  {
    label: "Google STT",
    sublabel: "Chirp 2",
    wer: 16.7,
    color: C.orange,
    highlighted: false,
    delay: 16,
  },
  {
    label: "Whisper Large v3",
    sublabel: "TurboScribe",
    wer: 21,
    color: C.red,
    highlighted: false,
    delay: 24,
  },
];

const maxWer = 28;

const Bar: React.FC<{
  data: BarData;
  frame: number;
  fps: number;
  index: number;
}> = ({ data, frame, fps, index }) => {
  const barStart = 40 + data.delay;

  const widthPct = spring({
    frame: Math.max(0, frame - barStart),
    fps,
    config: { damping: 18, stiffness: 80 },
  });

  const labelOpacity = ease(frame, 0, 1, barStart - 5, barStart + 10);
  const valueOpacity = ease(frame, 0, 1, barStart + 15, barStart + 30);

  const targetWidth = (data.wer / maxWer) * 100;
  const currentWidth = targetWidth * widthPct;

  const barHeight = 64;
  const gap = 20;
  const topOffset = 180 + index * (barHeight + gap);

  return (
    <div
      style={{
        position: "absolute",
        left: 300,
        right: 60,
        top: topOffset,
        height: barHeight,
        display: "flex",
        alignItems: "center",
      }}
    >
      {/* Label */}
      <div
        style={{
          position: "absolute",
          right: "100%",
          marginRight: 20,
          width: 230,
          textAlign: "right",
          opacity: labelOpacity,
        }}
      >
        <div
          style={{
            fontSize: 22,
            fontWeight: data.highlighted ? 700 : 500,
            color: data.highlighted ? C.green : C.text,
          }}
        >
          {data.label}
        </div>
        {data.sublabel && (
          <div style={{ fontSize: 14, color: C.textMuted, marginTop: 2 }}>
            {data.sublabel}
          </div>
        )}
      </div>

      {/* Bar background */}
      <div
        style={{
          width: "100%",
          height: barHeight,
          borderRadius: 12,
          background: "rgba(255,255,255,0.04)",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Animated bar */}
        <div
          style={{
            width: `${currentWidth}%`,
            height: "100%",
            borderRadius: 12,
            background: data.highlighted
              ? `linear-gradient(90deg, ${data.color}, ${data.color}dd)`
              : `linear-gradient(90deg, ${data.color}88, ${data.color}55)`,
            boxShadow: data.highlighted
              ? `0 0 30px ${data.color}40`
              : "none",
            display: "flex",
            alignItems: "center",
            justifyContent: "flex-end",
            paddingRight: 16,
            transition: "none",
          }}
        >
          {/* WER value inside bar */}
          <span
            style={{
              fontSize: data.highlighted ? 26 : 22,
              fontWeight: 700,
              color: "white",
              opacity: valueOpacity,
              textShadow: "0 1px 4px rgba(0,0,0,0.3)",
            }}
          >
            {data.wer === 10 ? "~10%" : data.wer === 16.7 ? "~16.7%" : `${data.wer}%`}
          </span>
        </div>
      </div>

      {/* Highlight badge */}
      {data.highlighted && (
        <div
          style={{
            position: "absolute",
            left: `${currentWidth}%`,
            marginLeft: 260,
            opacity: ease(frame, 0, 1, barStart + 30, barStart + 45),
            transform: `scale(${spring({
              frame: Math.max(0, frame - barStart - 30),
              fps,
              config: { damping: 10, stiffness: 150 },
            })})`,
          }}
        >
          <div
            style={{
              padding: "6px 16px",
              borderRadius: 20,
              background: `${C.green}20`,
              border: `1px solid ${C.green}40`,
              fontSize: 14,
              fontWeight: 600,
              color: C.green,
              whiteSpace: "nowrap",
            }}
          >
            SOTA
          </div>
        </div>
      )}
    </div>
  );
};

export const WerComparison: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bgHue = interpolate(frame, [0, 180], [240, 260], {
    extrapolateRight: "clamp",
  });

  // Title animation
  const titleOpacity = ease(frame, 0, 1, 5, 25);
  const titleY = ease(frame, 15, 0, 5, 25);

  // Source note
  const sourceOpacity = ease(frame, 0, 1, 100, 120);

  return (
    <AbsoluteFill
      style={{
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", sans-serif',
        overflow: "hidden",
      }}
    >
      {/* Background */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: `
            radial-gradient(ellipse at 25% 40%, hsla(${bgHue}, 60%, 15%, 1) 0%, transparent 60%),
            radial-gradient(ellipse at 75% 60%, hsla(${bgHue + 30}, 50%, 12%, 1) 0%, transparent 50%),
            linear-gradient(180deg, ${C.bg1} 0%, ${C.bg2} 50%, ${C.bg3} 100%)
          `,
        }}
      />

      {/* Grid overlay */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage: `
            linear-gradient(rgba(108,92,231,0.03) 1px, transparent 1px),
            linear-gradient(90deg, rgba(108,92,231,0.03) 1px, transparent 1px)
          `,
          backgroundSize: "60px 60px",
        }}
      />

      {/* Title */}
      <div
        style={{
          position: "absolute",
          top: 50,
          left: 60,
          right: 60,
          opacity: titleOpacity,
          transform: `translateY(${titleY}px)`,
        }}
      >
        <div
          style={{
            fontSize: 34,
            fontWeight: 700,
            color: C.text,
            letterSpacing: -0.5,
            lineHeight: 1.2,
          }}
        >
          Точность распознавания русской речи
        </div>
        <div
          style={{
            fontSize: 18,
            color: C.textMuted,
            marginTop: 8,
          }}
        >
          WER (Word Error Rate) -- меньше = лучше
        </div>
      </div>

      {/* Bars */}
      {bars.map((bar, i) => (
        <Bar key={bar.label} data={bar} frame={frame} fps={fps} index={i} />
      ))}

      {/* Source */}
      <div
        style={{
          position: "absolute",
          bottom: 30,
          left: 60,
          right: 60,
          opacity: sourceOpacity,
          fontSize: 13,
          color: C.textDim,
        }}
      >
        GigaAM v3: INTERSPEECH 2025 (arXiv:2506.01192). Облачные API: оценки на аналогичных датасетах.
      </div>

      {/* Traart branding */}
      <div
        style={{
          position: "absolute",
          bottom: 30,
          right: 60,
          opacity: sourceOpacity,
          fontSize: 16,
          fontWeight: 600,
          color: C.accent,
        }}
      >
        traart.app
      </div>
    </AbsoluteFill>
  );
};
