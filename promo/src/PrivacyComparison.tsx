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

// --- SVG Icons ---

const LaptopIcon: React.FC<{ color: string; size: number }> = ({
  color,
  size,
}) => (
  <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
    <rect
      x="8"
      y="10"
      width="48"
      height="34"
      rx="4"
      stroke={color}
      strokeWidth="3"
      fill="none"
    />
    <rect x="14" y="16" width="36" height="22" rx="2" fill={`${color}15`} />
    <path
      d="M4 44h56c0 4-4 8-8 8H12c-4 0-8-4-8-8z"
      stroke={color}
      strokeWidth="3"
      fill="none"
    />
  </svg>
);

const ShieldIcon: React.FC<{ color: string; size: number }> = ({
  color,
  size,
}) => (
  <svg width={size} height={size} viewBox="0 0 48 48" fill="none">
    <path
      d="M24 4L6 12v12c0 11.1 7.7 21.5 18 24 10.3-2.5 18-12.9 18-24V12L24 4z"
      fill={`${color}20`}
      stroke={color}
      strokeWidth="2.5"
    />
    <path
      d="M16 24l5 5 10-10"
      stroke={color}
      strokeWidth="3"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

const TextIcon: React.FC<{ color: string; size: number }> = ({
  color,
  size,
}) => (
  <svg width={size} height={size} viewBox="0 0 48 48" fill="none">
    <rect
      x="6"
      y="4"
      width="36"
      height="40"
      rx="4"
      fill={`${color}10`}
      stroke={color}
      strokeWidth="2.5"
    />
    <line x1="14" y1="14" x2="34" y2="14" stroke={color} strokeWidth="2" strokeLinecap="round" />
    <line x1="14" y1="22" x2="30" y2="22" stroke={color} strokeWidth="2" strokeLinecap="round" />
    <line x1="14" y1="30" x2="26" y2="30" stroke={color} strokeWidth="2" strokeLinecap="round" />
  </svg>
);

const CloudIcon: React.FC<{ color: string; size: number }> = ({
  color,
  size,
}) => (
  <svg width={size} height={size} viewBox="0 0 64 48" fill="none">
    <path
      d="M16 40c-6.6 0-12-5.4-12-12s5.4-12 12-12c.7-6.3 6-11.2 12.5-11.2 5 0 9.3 2.9 11.4 7.2C41.6 11 43.7 10 46 10c5.5 0 10 4.5 10 10 0 .7-.1 1.3-.2 2C59.3 23.5 62 27.4 62 32c0 5.5-4.5 10-10 10H16z"
      fill={`${color}15`}
      stroke={color}
      strokeWidth="2.5"
    />
  </svg>
);

const ServerIcon: React.FC<{ color: string; size: number }> = ({
  color,
  size,
}) => (
  <svg width={size} height={size} viewBox="0 0 48 56" fill="none">
    <rect x="4" y="4" width="40" height="14" rx="3" fill={`${color}15`} stroke={color} strokeWidth="2" />
    <circle cx="12" cy="11" r="2" fill={color} />
    <circle cx="18" cy="11" r="2" fill={color} />
    <rect x="4" y="22" width="40" height="14" rx="3" fill={`${color}15`} stroke={color} strokeWidth="2" />
    <circle cx="12" cy="29" r="2" fill={color} />
    <circle cx="18" cy="29" r="2" fill={color} />
    <rect x="4" y="40" width="40" height="14" rx="3" fill={`${color}15`} stroke={color} strokeWidth="2" />
    <circle cx="12" cy="47" r="2" fill={color} />
    <circle cx="18" cy="47" r="2" fill={color} />
  </svg>
);

const WarningIcon: React.FC<{ color: string; size: number }> = ({
  color,
  size,
}) => (
  <svg width={size} height={size} viewBox="0 0 48 48" fill="none">
    <path
      d="M24 4L2 42h44L24 4z"
      fill={`${color}20`}
      stroke={color}
      strokeWidth="2.5"
      strokeLinejoin="round"
    />
    <line x1="24" y1="18" x2="24" y2="30" stroke={color} strokeWidth="3" strokeLinecap="round" />
    <circle cx="24" cy="36" r="2" fill={color} />
  </svg>
);

// Arrow component
const FlowArrow: React.FC<{
  frame: number;
  startFrame: number;
  x: number;
  y: number;
  width: number;
  color: string;
  dashed?: boolean;
}> = ({ frame, startFrame, x, y, width, color, dashed }) => {
  const progress = ease(frame, 0, 1, startFrame, startFrame + 20);
  const opacity = ease(frame, 0, 1, startFrame - 5, startFrame + 10);

  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width,
        height: 3,
        opacity,
      }}
    >
      <div
        style={{
          width: `${progress * 100}%`,
          height: "100%",
          background: dashed ? "none" : color,
          borderTop: dashed ? `3px dashed ${color}` : "none",
        }}
      />
      {/* Arrow head */}
      <div
        style={{
          position: "absolute",
          right: 0,
          top: -6,
          opacity: progress > 0.9 ? 1 : 0,
        }}
      >
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <path d="M2 2l10 5-10 5V2z" fill={color} />
        </svg>
      </div>
    </div>
  );
};

export const PrivacyComparison: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bgHue = interpolate(frame, [0, 210], [240, 265], {
    extrapolateRight: "clamp",
  });

  // Title
  const titleOpacity = ease(frame, 0, 1, 5, 25);
  const titleY = ease(frame, 15, 0, 5, 25);

  // Left (Traart) elements
  const leftLaptopOp = ease(frame, 0, 1, 25, 42);
  const leftArrowStart = 45;
  const leftTextOp = ease(frame, 0, 1, 65, 80);
  const leftShieldOp = ease(frame, 0, 1, 80, 95);

  // Right (Cloud) elements
  const rightLaptopOp = ease(frame, 0, 1, 35, 52);
  const rightArrow1Start = 55;
  const rightCloudOp = ease(frame, 0, 1, 75, 90);
  const rightArrow2Start = 90;
  const rightServerOp = ease(frame, 0, 1, 110, 125);
  const rightArrow3Start = 125;
  const rightWarningOp = ease(frame, 0, 1, 145, 160);

  // Divider
  const dividerOp = ease(frame, 0, 1, 30, 50);

  // Labels
  const labelTraartOp = ease(frame, 0, 1, 35, 50);
  const labelCloudOp = ease(frame, 0, 1, 45, 60);

  // Summary badges
  const badgeStart = 155;

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

      {/* Grid */}
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
          top: 36,
          left: 0,
          right: 0,
          textAlign: "center",
          opacity: titleOpacity,
          transform: `translateY(${titleY}px)`,
        }}
      >
        <div
          style={{
            fontSize: 36,
            fontWeight: 700,
            color: C.text,
            letterSpacing: -0.5,
          }}
        >
          Куда уходят ваши данные?
        </div>
      </div>

      {/* Center divider */}
      <div
        style={{
          position: "absolute",
          left: 598,
          top: 100,
          bottom: 70,
          width: 2,
          background: `linear-gradient(180deg, transparent, ${C.accent}30, transparent)`,
          opacity: dividerOp,
        }}
      />

      {/* ======= LEFT: Traart (local) ======= */}
      <div
        style={{
          position: "absolute",
          left: 30,
          top: 100,
          width: 550,
        }}
      >
        {/* Header */}
        <div
          style={{
            textAlign: "center",
            marginBottom: 20,
            opacity: labelTraartOp,
          }}
        >
          <div
            style={{
              display: "inline-block",
              padding: "6px 20px",
              borderRadius: 20,
              background: `${C.green}15`,
              border: `1px solid ${C.green}30`,
              fontSize: 18,
              fontWeight: 600,
              color: C.green,
            }}
          >
            Traart (оффлайн)
          </div>
        </div>

        {/* Flow: Laptop -> Text (all local) */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 10,
            position: "relative",
            height: 180,
          }}
        >
          {/* Laptop */}
          <div style={{ opacity: leftLaptopOp, textAlign: "center" }}>
            <LaptopIcon color={C.green} size={80} />
            <div
              style={{
                fontSize: 13,
                color: C.textMuted,
                marginTop: 6,
              }}
            >
              Ваш Mac
            </div>
          </div>

          {/* Arrow */}
          <div style={{ width: 100, position: "relative", height: 20 }}>
            <FlowArrow
              frame={frame}
              startFrame={leftArrowStart}
              x={0}
              y={8}
              width={100}
              color={C.green}
            />
          </div>

          {/* Text result */}
          <div style={{ opacity: leftTextOp, textAlign: "center" }}>
            <TextIcon color={C.green} size={70} />
            <div
              style={{
                fontSize: 13,
                color: C.textMuted,
                marginTop: 6,
              }}
            >
              Текст
            </div>
          </div>

          {/* Shield */}
          <div
            style={{
              marginLeft: 30,
              opacity: leftShieldOp,
              textAlign: "center",
              transform: `scale(${spring({
                frame: Math.max(0, frame - 80),
                fps,
                config: { damping: 10, stiffness: 150 },
              })})`,
            }}
          >
            <ShieldIcon color={C.green} size={70} />
          </div>
        </div>

        {/* Green message */}
        <div
          style={{
            textAlign: "center",
            marginTop: 20,
            opacity: ease(frame, 0, 1, 90, 110),
          }}
        >
          <div
            style={{
              fontSize: 20,
              fontWeight: 700,
              color: C.green,
              marginBottom: 6,
            }}
          >
            0 байт в сеть
          </div>
          <div style={{ fontSize: 14, color: C.textMuted }}>
            Все данные остаются на вашем Mac
          </div>
        </div>

        {/* Compliance badges */}
        <div
          style={{
            display: "flex",
            justifyContent: "center",
            gap: 10,
            marginTop: 16,
          }}
        >
          {["152-ФЗ", "GDPR", "Нет регистрации"].map((label, i) => (
            <div
              key={label}
              style={{
                padding: "4px 14px",
                borderRadius: 16,
                background: `${C.green}10`,
                border: `1px solid ${C.green}20`,
                fontSize: 12,
                fontWeight: 500,
                color: C.green,
                opacity: ease(frame, 0, 1, badgeStart + i * 6, badgeStart + 15 + i * 6),
              }}
            >
              {label}
            </div>
          ))}
        </div>
      </div>

      {/* ======= RIGHT: Cloud ======= */}
      <div
        style={{
          position: "absolute",
          left: 620,
          top: 100,
          width: 560,
        }}
      >
        {/* Header */}
        <div
          style={{
            textAlign: "center",
            marginBottom: 20,
            opacity: labelCloudOp,
          }}
        >
          <div
            style={{
              display: "inline-block",
              padding: "6px 20px",
              borderRadius: 20,
              background: `${C.red}15`,
              border: `1px solid ${C.red}30`,
              fontSize: 18,
              fontWeight: 600,
              color: C.red,
            }}
          >
            Облачные сервисы
          </div>
        </div>

        {/* Flow: Laptop -> Internet -> Server -> ??? */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 6,
            position: "relative",
            height: 180,
          }}
        >
          {/* Laptop */}
          <div style={{ opacity: rightLaptopOp, textAlign: "center" }}>
            <LaptopIcon color={C.orange} size={70} />
            <div style={{ fontSize: 12, color: C.textMuted, marginTop: 4 }}>
              Ваш Mac
            </div>
          </div>

          {/* Arrow 1 */}
          <div style={{ width: 60, position: "relative", height: 20 }}>
            <FlowArrow
              frame={frame}
              startFrame={rightArrow1Start}
              x={0}
              y={8}
              width={60}
              color={C.orange}
              dashed
            />
          </div>

          {/* Cloud / Internet */}
          <div style={{ opacity: rightCloudOp, textAlign: "center" }}>
            <CloudIcon color={C.orange} size={60} />
            <div style={{ fontSize: 11, color: C.textMuted, marginTop: 2 }}>
              Интернет
            </div>
          </div>

          {/* Arrow 2 */}
          <div style={{ width: 60, position: "relative", height: 20 }}>
            <FlowArrow
              frame={frame}
              startFrame={rightArrow2Start}
              x={0}
              y={8}
              width={60}
              color={C.red}
              dashed
            />
          </div>

          {/* Server */}
          <div style={{ opacity: rightServerOp, textAlign: "center" }}>
            <ServerIcon color={C.red} size={60} />
            <div style={{ fontSize: 11, color: C.textMuted, marginTop: 2 }}>
              Серверы US/EU
            </div>
          </div>

          {/* Arrow 3 */}
          <div style={{ width: 50, position: "relative", height: 20 }}>
            <FlowArrow
              frame={frame}
              startFrame={rightArrow3Start}
              x={0}
              y={8}
              width={50}
              color={C.red}
              dashed
            />
          </div>

          {/* Warning */}
          <div
            style={{
              opacity: rightWarningOp,
              textAlign: "center",
              transform: `scale(${spring({
                frame: Math.max(0, frame - 145),
                fps,
                config: { damping: 10, stiffness: 150 },
              })})`,
            }}
          >
            <WarningIcon color={C.red} size={55} />
            <div style={{ fontSize: 13, fontWeight: 600, color: C.red, marginTop: 2 }}>
              ???
            </div>
          </div>
        </div>

        {/* Red warnings */}
        <div
          style={{
            textAlign: "center",
            marginTop: 20,
            opacity: ease(frame, 0, 1, 150, 170),
          }}
        >
          <div
            style={{
              fontSize: 18,
              fontWeight: 700,
              color: C.red,
              marginBottom: 8,
            }}
          >
            Ваш голос на чужих серверах
          </div>
        </div>

        {/* Risk badges */}
        <div
          style={{
            display: "flex",
            justifyContent: "center",
            gap: 10,
            marginTop: 10,
          }}
        >
          {["Утечки данных", "Обучение AI", "Vendor lock-in"].map(
            (label, i) => (
              <div
                key={label}
                style={{
                  padding: "4px 14px",
                  borderRadius: 16,
                  background: `${C.red}10`,
                  border: `1px solid ${C.red}20`,
                  fontSize: 12,
                  fontWeight: 500,
                  color: C.red,
                  opacity: ease(
                    frame,
                    0,
                    1,
                    badgeStart + 5 + i * 6,
                    badgeStart + 20 + i * 6
                  ),
                }}
              >
                {label}
              </div>
            )
          )}
        </div>
      </div>

      {/* Source & branding */}
      <div
        style={{
          position: "absolute",
          bottom: 24,
          left: 60,
          right: 60,
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          opacity: ease(frame, 0, 1, 160, 180),
        }}
      >
        <div style={{ fontSize: 12, color: C.textDim }}>
          Голос -- биометрические данные (152-ФЗ ст. 11, GDPR ст. 9)
        </div>
        <div style={{ fontSize: 16, fontWeight: 600, color: C.accent }}>
          traart.app
        </div>
      </div>
    </AbsoluteFill>
  );
};
