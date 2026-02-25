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

// ============================================================
// Sparkle SVG elements (from TraartSparkleIcon / StatusBarIconRenderer.swift)
// ViewBox 0 0 18 18, center (9,9), radius 7, waist 0.18
// ============================================================
const SPARKLE_PATH =
  "M 9 2 Q 10.26 7.74 16 9 Q 10.26 10.26 9 16 Q 7.74 10.26 2 9 Q 7.74 7.74 9 2 Z";

const TEAL = "#4ECDC4";
const GREEN = "#33C759";

/** SVG gradient definition — reuse in every <svg> that needs it */
const SparkleGradientDefs: React.FC<{ id?: string; angle?: number }> = ({
  id = "sparkle-grad",
  angle = 135,
}) => {
  const rad = (angle * Math.PI) / 180;
  const x1 = 50 - 50 * Math.cos(rad);
  const y1 = 50 - 50 * Math.sin(rad);
  const x2 = 50 + 50 * Math.cos(rad);
  const y2 = 50 + 50 * Math.sin(rad);
  return (
    <defs>
      <linearGradient
        id={id}
        x1={`${x1}%`}
        y1={`${y1}%`}
        x2={`${x2}%`}
        y2={`${y2}%`}
      >
        <stop offset="0%" stopColor="#4ECDC4" />
        <stop offset="50%" stopColor="#6C5CE7" />
        <stop offset="100%" stopColor="#E879A8" />
      </linearGradient>
    </defs>
  );
};

const GRAD_FILL = "url(#sparkle-grad)";

/** Sparkle shape only (no accent marks) */
const SparkleShape: React.FC<{
  fill?: string;
  fillOpacity?: number;
  stroke?: string;
  strokeWidth?: number;
  strokeDashoffset?: number;
  pathLength?: number;
}> = ({
  fill = "none",
  fillOpacity = 1,
  stroke,
  strokeWidth = 0.8,
  strokeDashoffset = 0,
  pathLength = 1,
}) => (
  <>
    {stroke && (
      <path
        d={SPARKLE_PATH}
        fill="none"
        stroke={stroke}
        strokeWidth={strokeWidth}
        strokeLinejoin="round"
        pathLength={pathLength}
        strokeDasharray={pathLength}
        strokeDashoffset={strokeDashoffset}
      />
    )}
    {fill !== "none" && (
      <path d={SPARKLE_PATH} fill={fill} fillOpacity={fillOpacity} />
    )}
  </>
);

/** Accent + marks */
const AccentMarks: React.FC<{
  color: string;
  opacity?: number;
  scale?: number;
}> = ({ color, opacity = 1, scale = 1 }) => (
  <g
    stroke={color}
    strokeLinecap="round"
    opacity={opacity}
    transform={`translate(9, 9) scale(${scale}) translate(-9, -9)`}
  >
    {/* Top-right + */}
    <line x1={15} y1={2.25} x2={15} y2={5.25} strokeWidth={1.2} />
    <line x1={13.5} y1={3.75} x2={16.5} y2={3.75} strokeWidth={1.2} />
    {/* Bottom-left + */}
    <line x1={3} y1={12.75} x2={3} y2={14.25} strokeWidth={1.0} />
    <line x1={2.25} y1={13.5} x2={3.75} y2={13.5} strokeWidth={1.0} />
  </g>
);

// ============================================================
// Shared: dark gradient background
// ============================================================
const DarkBG: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <AbsoluteFill
    style={{
      background: `linear-gradient(135deg, ${C.bg1} 0%, ${C.bg2} 50%, ${C.bg3} 100%)`,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      fontFamily:
        '-apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
    }}
  >
    {children}
  </AbsoluteFill>
);

// Sparkle icon size in pixels (within 1024x1024 canvas)
const ICON = 350;

// ================================================================
// 1. DRAW — outline draws itself, fills teal, marks pop, text appears
//    90 frames (3s)
// ================================================================
export const LogoDraw: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Outline draws (frame 5→35)
  const drawProgress = interpolate(frame, [5, 35], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Fill fades in (frame 30→48)
  const fillOp = interpolate(frame, [30, 48], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Accent marks pop (frame 42, 48)
  const mark1 = spring({
    frame: Math.max(0, frame - 42),
    fps,
    config: { damping: 8, stiffness: 200 },
  });
  const mark2 = spring({
    frame: Math.max(0, frame - 48),
    fps,
    config: { damping: 8, stiffness: 200 },
  });
  const markOp = Math.max(mark1, mark2);
  const markScale = (mark1 + mark2) / 2;

  // "Traart" text slides up (frame 50→65)
  const textOp = ease(frame, 0, 1, 50, 65);
  const textY = interpolate(frame, [50, 65], [20, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Glow behind sparkle when fill completes
  const glowOp = interpolate(frame, [35, 48, 70], [0, 0.6, 0.2], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <DarkBG>
      {/* Glow */}
      <div
        style={{
          position: "absolute",
          width: ICON * 1.5,
          height: ICON * 1.5,
          borderRadius: "50%",
          background: TEAL,
          filter: "blur(80px)",
          opacity: glowOp * 0.3,
        }}
      />

      <svg width={ICON} height={ICON} viewBox="0 0 18 18" fill="none">
        <SparkleGradientDefs />
        {/* Drawing outline */}
        <SparkleShape
          stroke={GRAD_FILL}
          strokeWidth={0.5}
          strokeDashoffset={drawProgress}
        />
        {/* Fill */}
        {fillOp > 0 && (
          <SparkleShape fill={GRAD_FILL} fillOpacity={fillOp} />
        )}
        {/* Accent marks */}
        <AccentMarks color={TEAL} opacity={markOp} scale={markScale} />
      </svg>

      <div
        style={{
          marginTop: 40,
          fontSize: 80,
          fontWeight: 900,
          color: C.text,
          letterSpacing: -3,
          opacity: textOp,
          transform: `translateY(${textY}px)`,
        }}
      >
        Traart
      </div>
    </DarkBG>
  );
};

// ================================================================
// 2. BOUNCE — playful spring entrance, elements cascade
//    75 frames (2.5s)
// ================================================================
export const LogoBounce: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Sparkle bounces in
  const sparkleScale = spring({
    frame: Math.max(0, frame - 3),
    fps,
    config: { damping: 6, stiffness: 120 },
  });

  // Rotation overshoot
  const sparkleRotate = spring({
    frame: Math.max(0, frame - 3),
    fps,
    config: { damping: 8, stiffness: 80 },
  });
  const rotateAngle = (1 - sparkleRotate) * 45;

  // Marks pop staggered
  const mark1Op = spring({
    frame: Math.max(0, frame - 16),
    fps,
    config: { damping: 6, stiffness: 200 },
  });
  const mark2Op = spring({
    frame: Math.max(0, frame - 22),
    fps,
    config: { damping: 6, stiffness: 200 },
  });

  // Text bounces up
  const textScale = spring({
    frame: Math.max(0, frame - 28),
    fps,
    config: { damping: 8, stiffness: 150 },
  });

  return (
    <DarkBG>
      <div
        style={{
          transform: `scale(${sparkleScale}) rotate(${rotateAngle}deg)`,
        }}
      >
        <svg width={ICON} height={ICON} viewBox="0 0 18 18" fill="none">
          <SparkleGradientDefs />
          <SparkleShape fill={GRAD_FILL} />
          <AccentMarks
            color={TEAL}
            opacity={Math.min(mark1Op, mark2Op)}
            scale={(mark1Op + mark2Op) / 2}
          />
        </svg>
      </div>

      <div
        style={{
          marginTop: 40,
          fontSize: 80,
          fontWeight: 900,
          color: C.text,
          letterSpacing: -3,
          transform: `scale(${textScale})`,
        }}
      >
        Traart
      </div>
    </DarkBG>
  );
};

// ================================================================
// 3. REVEAL — glow rings + rotation reveal
//    75 frames (2.5s)
// ================================================================
export const LogoReveal: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const mainScale = spring({
    frame: Math.max(0, frame - 5),
    fps,
    config: { damping: 12, stiffness: 100 },
  });

  const rotate = interpolate(frame, [0, 30], [180, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Glow ring 1
  const g1Scale = interpolate(frame, [5, 40], [0.5, 2.5], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const g1Op = interpolate(frame, [5, 15, 40], [0, 0.6, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  // Glow ring 2
  const g2Scale = interpolate(frame, [12, 50], [0.5, 3], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const g2Op = interpolate(frame, [12, 22, 50], [0, 0.3, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Text
  const textOp = ease(frame, 0, 1, 30, 48);

  return (
    <DarkBG>
      {/* Glow rings */}
      <div
        style={{
          position: "absolute",
          width: ICON,
          height: ICON,
          borderRadius: "50%",
          border: `3px solid ${TEAL}`,
          transform: `scale(${g1Scale}) translateY(-30px)`,
          opacity: g1Op,
          boxShadow: `0 0 60px ${TEAL}`,
        }}
      />
      <div
        style={{
          position: "absolute",
          width: ICON,
          height: ICON,
          borderRadius: "50%",
          border: `2px solid ${C.accent}`,
          transform: `scale(${g2Scale}) translateY(-30px)`,
          opacity: g2Op,
          boxShadow: `0 0 40px ${C.accent}`,
        }}
      />

      <div
        style={{
          transform: `scale(${mainScale}) rotate(${rotate}deg)`,
        }}
      >
        <svg width={ICON} height={ICON} viewBox="0 0 18 18" fill="none">
          <SparkleGradientDefs />
          <SparkleShape fill={GRAD_FILL} />
          <AccentMarks color={TEAL} />
        </svg>
      </div>

      <div
        style={{
          marginTop: 40,
          fontSize: 80,
          fontWeight: 900,
          color: C.text,
          letterSpacing: -3,
          opacity: textOp,
        }}
      >
        Traart
      </div>
    </DarkBG>
  );
};

// ================================================================
// 4. FLOAT — gentle seamless loop for hero sections
//    120 frames (4s loop)
// ================================================================
export const LogoFloat: React.FC = () => {
  const frame = useCurrentFrame();

  // All oscillations complete full cycles in 120 frames → seamless loop
  const t = (frame / 120) * Math.PI * 2;

  const breathe = Math.sin(t) * 0.03 + 1;
  const floatY = Math.sin(t) * 12;
  const floatX = Math.cos(t * 0.75) * 6;
  const rotate = Math.sin(t * 0.5) * 3;
  const glowPulse = Math.sin(t + Math.PI / 4) * 0.15 + 0.25;

  // Accent marks pulse slightly
  const markPulse = Math.sin(t * 2) * 0.1 + 0.9;

  return (
    <DarkBG>
      {/* Ambient glow */}
      <div
        style={{
          position: "absolute",
          width: ICON * 1.8,
          height: ICON * 1.8,
          borderRadius: "50%",
          background: TEAL,
          filter: "blur(100px)",
          opacity: glowPulse,
          transform: `translateY(-30px)`,
        }}
      />

      <div
        style={{
          transform: `translate(${floatX}px, ${floatY - 30}px) scale(${breathe}) rotate(${rotate}deg)`,
        }}
      >
        <svg width={ICON} height={ICON} viewBox="0 0 18 18" fill="none">
          <SparkleGradientDefs />
          <SparkleShape fill={GRAD_FILL} />
          <AccentMarks color={TEAL} opacity={markPulse} />
        </svg>
      </div>

      <div
        style={{
          marginTop: 10,
          fontSize: 80,
          fontWeight: 900,
          color: C.text,
          letterSpacing: -3,
          transform: `translateY(${floatY * 0.3}px)`,
        }}
      >
        Traart
      </div>
    </DarkBG>
  );
};

// ================================================================
// 5. STATES — cycles through all 4 states: idle → transcribing → done
//    Demonstrates the icon's dynamic nature
//    120 frames (4s)
// ================================================================
export const LogoStates: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Entry
  const entryScale = spring({
    frame: Math.max(0, frame - 2),
    fps,
    config: { damping: 10, stiffness: 150 },
  });

  // Phase timeline:
  // 0-15: idle (gray outline)
  // 15-75: transcribing (fills from bottom 0→100%)
  // 75-95: completed (green)
  // 95-120: back to teal, hold

  const isIdle = frame < 15;
  const isTranscribing = frame >= 15 && frame < 75;
  const isCompleted = frame >= 75 && frame < 95;
  const isFinal = frame >= 95;

  // Fill progress for transcribing state
  const fillProgress = isTranscribing
    ? interpolate(frame, [15, 72], [0, 1], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 0;
  const fillY = 18 - 18 * fillProgress;

  // Color transitions
  const currentColor = isIdle
    ? "#888"
    : isCompleted
    ? GREEN
    : TEAL;
  const currentFill = isIdle ? "none" : isCompleted || isFinal ? currentColor : "none";
  const finalColor = isFinal ? TEAL : currentColor;

  // Completion burst
  const burstScale = spring({
    frame: Math.max(0, frame - 75),
    fps,
    config: { damping: 6, stiffness: 100 },
  });
  const burstOp = isCompleted
    ? interpolate(frame, [75, 80, 95], [0, 0.5, 0], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 0;

  // Status label
  const label = isIdle
    ? "Ожидание"
    : isTranscribing
    ? `Транскрибация ${Math.round(fillProgress * 100)}%`
    : isCompleted
    ? "Готово!"
    : "Traart";

  const labelColor = isIdle
    ? "#888"
    : isCompleted
    ? GREEN
    : TEAL;

  const clipId = "states-fill-clip";

  return (
    <DarkBG>
      {/* Completion burst ring */}
      {burstOp > 0 && (
        <div
          style={{
            position: "absolute",
            width: ICON,
            height: ICON,
            borderRadius: "50%",
            border: `3px solid ${GREEN}`,
            transform: `scale(${burstScale * 2}) translateY(-40px)`,
            opacity: burstOp,
            boxShadow: `0 0 40px ${GREEN}`,
          }}
        />
      )}

      <div style={{ transform: `scale(${entryScale}) translateY(-40px)` }}>
        <svg width={ICON} height={ICON} viewBox="0 0 18 18" fill="none">
          <SparkleGradientDefs />
          <defs>
            <clipPath id={clipId}>
              <path d={SPARKLE_PATH} />
            </clipPath>
          </defs>

          {/* Idle: gray outline */}
          {isIdle && (
            <>
              <path
                d={SPARKLE_PATH}
                fill="none"
                stroke="#888"
                strokeWidth={0.5}
              />
              <AccentMarks color="#888" opacity={0.5} />
            </>
          )}

          {/* Transcribing: outline + gradient fill from bottom */}
          {isTranscribing && (
            <>
              <path
                d={SPARKLE_PATH}
                fill="none"
                stroke={TEAL}
                strokeWidth={0.4}
                strokeOpacity={0.3}
              />
              {fillProgress > 0 && (
                <rect
                  x={0}
                  y={fillY}
                  width={18}
                  height={18 * fillProgress}
                  fill={GRAD_FILL}
                  clipPath={`url(#${clipId})`}
                />
              )}
              <AccentMarks
                color={TEAL}
                opacity={fillProgress > 0.5 ? 1 : 0.35}
              />
            </>
          )}

          {/* Completed: full green */}
          {isCompleted && (
            <>
              <SparkleShape fill={GREEN} />
              <AccentMarks color={GREEN} />
            </>
          )}

          {/* Final: gradient */}
          {isFinal && (
            <>
              <SparkleShape fill={GRAD_FILL} />
              <AccentMarks color={TEAL} />
            </>
          )}
        </svg>
      </div>

      {/* Status label */}
      <div
        style={{
          marginTop: 10,
          fontSize: 48,
          fontWeight: 700,
          color: isFinal ? C.text : labelColor,
          letterSpacing: isFinal ? -3 : -1,
          transition: "color 0.3s",
        }}
      >
        {label}
      </div>

      {/* Subtitle for final state */}
      {isFinal && (
        <div
          style={{
            fontSize: 24,
            color: C.textMuted,
            marginTop: 8,
            opacity: ease(frame, 0, 1, 100, 112),
          }}
        >
          Лучшая транскрибация русской речи
        </div>
      )}
    </DarkBG>
  );
};
