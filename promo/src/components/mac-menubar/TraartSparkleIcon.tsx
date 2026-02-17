import React from "react";
import { C } from "../../shared/colors";

export type SparkleState = "idle" | "transcribing" | "completed" | "error";

/**
 * SVG sparkle icon matching StatusBarIconRenderer.swift.
 * 4 quad bezier curves forming a 4-pointed star, plus accent + marks.
 * ViewBox 0 0 18 18 (same as Swift iconSize).
 */
export const TraartSparkleIcon: React.FC<{
  state: SparkleState;
  /** 0..1 fill progress (only used when state="transcribing") */
  progress?: number;
  size?: number;
}> = ({ state, progress = 0, size = 18 }) => {
  // Sparkle path: center (9,9), radius 7, waist 0.18
  // Converted from AppKit (y-up) to SVG (y-down) coordinates
  const sparklePath =
    "M 9 2 Q 10.26 7.74 16 9 Q 10.26 10.26 9 16 Q 7.74 10.26 2 9 Q 7.74 7.74 9 2 Z";

  const clipId = `sparkle-clip-${Math.random().toString(36).slice(2, 8)}`;

  if (state === "idle") {
    return (
      <svg width={size} height={size} viewBox="0 0 18 18" fill="none">
        <path d={sparklePath} fill="#444" />
        <AccentMarks color="#444" />
      </svg>
    );
  }

  if (state === "transcribing") {
    const clamped = Math.min(Math.max(progress, 0), 1);
    const fillY = 18 - 18 * clamped;
    const markAlpha = clamped > 0.5 ? 1.0 : 0.35;
    return (
      <svg width={size} height={size} viewBox="0 0 18 18" fill="none">
        <defs>
          <clipPath id={clipId}>
            <path d={sparklePath} />
          </clipPath>
        </defs>
        {/* Dimmed outline */}
        <path
          d={sparklePath}
          stroke={C.teal}
          strokeWidth={1}
          strokeOpacity={0.25}
          fill="none"
        />
        {/* Fill from bottom */}
        {clamped > 0 && (
          <rect
            x={0}
            y={fillY}
            width={18}
            height={18 * clamped}
            fill={C.teal}
            clipPath={`url(#${clipId})`}
          />
        )}
        <AccentMarks color={C.teal} opacity={markAlpha} />
      </svg>
    );
  }

  if (state === "completed") {
    return (
      <svg width={size} height={size} viewBox="0 0 18 18" fill="none">
        <path d={sparklePath} fill={C.appGreen} />
        <AccentMarks color={C.appGreen} />
      </svg>
    );
  }

  // error
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none">
      <path d={sparklePath} fill={C.appRed} />
      <AccentMarks color={C.appRed} />
    </svg>
  );
};

/** Small + accent marks (sparkle decorations). */
const AccentMarks: React.FC<{ color: string; opacity?: number }> = ({
  color,
  opacity = 1,
}) => (
  <g stroke={color} strokeLinecap="round" opacity={opacity}>
    {/* Top-right + */}
    <line x1={15} y1={2.25} x2={15} y2={5.25} strokeWidth={1.2} />
    <line x1={13.5} y1={3.75} x2={16.5} y2={3.75} strokeWidth={1.2} />
    {/* Bottom-left + */}
    <line x1={3} y1={12.75} x2={3} y2={14.25} strokeWidth={1.0} />
    <line x1={2.25} y1={13.5} x2={3.75} y2={13.5} strokeWidth={1.0} />
  </g>
);
