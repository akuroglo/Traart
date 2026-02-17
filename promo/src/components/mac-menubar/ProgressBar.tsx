import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import { C } from "../../shared/colors";

/**
 * Progress bar matching TranscriptionProgressView.swift layout.
 * 280x58, teal->cyan gradient, animated shimmer via interpolate.
 */
export const ProgressBar: React.FC<{
  /** 0..1 */
  progress: number;
  step?: string;
  fileName?: string;
  etaString?: string;
  scale?: number;
}> = ({
  progress,
  step = "Транскрибация",
  fileName = "audio.mp4",
  etaString,
  scale = 1,
}) => {
  const frame = useCurrentFrame();
  const pct = Math.round(progress * 100);
  const barWidth = 260 * scale;
  const barHeight = 5 * scale;
  const fillWidth = barWidth * Math.min(Math.max(progress, 0.02), 1);

  // Shimmer: 1.8s cycle = 54 frames @ 30fps
  const shimmerW = 40 * scale;
  const shimmerX = interpolate(
    frame % 54,
    [0, 54],
    [-shimmerW, barWidth + shimmerW],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  return (
    <div
      style={{
        width: 280 * scale,
        height: 58 * scale,
        padding: `${6 * scale}px ${10 * scale}px`,
        boxSizing: "border-box",
      }}
    >
      {/* Step + ETA row */}
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "baseline",
          fontSize: 13 * scale,
          fontWeight: 500,
          color: C.menuText,
        }}
      >
        <span>
          {step} &middot; {pct}%
        </span>
        <span
          style={{
            fontSize: 11 * scale,
            fontWeight: 400,
            color: etaString
              ? "rgba(0,0,0,0.55)"
              : "rgba(0,0,0,0.35)",
            fontVariantNumeric: "tabular-nums",
          }}
        >
          {etaString || "Оценка времени..."}
        </span>
      </div>

      {/* File name */}
      <div
        style={{
          fontSize: 11 * scale,
          color: "rgba(0,0,0,0.55)",
          marginTop: 1 * scale,
          overflow: "hidden",
          textOverflow: "ellipsis",
          whiteSpace: "nowrap",
        }}
      >
        {fileName}
      </div>

      {/* Bar */}
      <div
        style={{
          marginTop: 5 * scale,
          width: barWidth,
          height: barHeight,
          borderRadius: 2.5 * scale,
          background: "rgba(0,0,0,0.08)",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Gradient fill */}
        <div
          style={{
            width: fillWidth,
            height: "100%",
            borderRadius: 2.5 * scale,
            background: `linear-gradient(90deg, ${C.tealA}, ${C.tealB})`,
            position: "relative",
            overflow: "hidden",
          }}
        >
          {/* Shimmer highlight */}
          <div
            style={{
              position: "absolute",
              top: 0,
              left: shimmerX,
              width: shimmerW,
              height: "100%",
              background:
                "linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent)",
            }}
          />
        </div>
      </div>
    </div>
  );
};
