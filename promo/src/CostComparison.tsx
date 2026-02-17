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

interface CostItem {
  label: string;
  monthly: number;
  yearly: number;
  color: string;
  delay: number;
}

const cloudServices: CostItem[] = [
  { label: "AWS Transcribe", monthly: 28.80, yearly: 345.60, color: C.red, delay: 0 },
  { label: "Google STT", monthly: 19.20, yearly: 230.40, color: C.orange, delay: 6 },
  { label: "Azure Speech", monthly: 20.00, yearly: 240.00, color: "#4A90D9", delay: 12 },
  { label: "TurboScribe", monthly: 10.00, yearly: 120.00, color: C.yellow, delay: 18 },
  { label: "Notta Pro", monthly: 8.17, yearly: 98.04, color: "#E056A0", delay: 24 },
  { label: "Yandex SpeechKit", monthly: 6.40, yearly: 76.80, color: "#FF5555", delay: 30 },
];

const maxYearly = 400;

export const CostComparison: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bgHue = interpolate(frame, [0, 210], [240, 270], {
    extrapolateRight: "clamp",
  });

  // Title
  const titleOpacity = ease(frame, 0, 1, 5, 25);
  const titleY = ease(frame, 15, 0, 5, 25);

  // Traart big zero
  const zeroScale = spring({
    frame: Math.max(0, frame - 30),
    fps,
    config: { damping: 8, stiffness: 100 },
  });
  const zeroOpacity = ease(frame, 0, 1, 28, 45);

  // Cloud stack start
  const stackStart = 55;

  // Summary text
  const summaryOpacity = ease(frame, 0, 1, 140, 165);

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
          left: 60,
          right: 60,
          opacity: titleOpacity,
          transform: `translateY(${titleY}px)`,
        }}
      >
        <div
          style={{
            fontSize: 32,
            fontWeight: 700,
            color: C.text,
            letterSpacing: -0.5,
          }}
        >
          Стоимость транскрибации за год
        </div>
        <div style={{ fontSize: 17, color: C.textMuted, marginTop: 6 }}>
          Расчет для 20 часов аудио в месяц (240 часов/год)
        </div>
      </div>

      {/* Left side: Traart $0 */}
      <div
        style={{
          position: "absolute",
          left: 60,
          top: 150,
          width: 340,
          height: 400,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          opacity: zeroOpacity,
        }}
      >
        <div
          style={{
            background: `rgba(48, 209, 88, 0.06)`,
            border: `2px solid ${C.green}30`,
            borderRadius: 24,
            padding: "40px 50px",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            transform: `scale(${zeroScale})`,
            boxShadow: `0 0 60px ${C.green}15`,
          }}
        >
          <div
            style={{
              fontSize: 24,
              fontWeight: 600,
              color: C.green,
              marginBottom: 8,
            }}
          >
            Traart
          </div>
          <div
            style={{
              fontSize: 120,
              fontWeight: 800,
              color: C.green,
              lineHeight: 1,
              letterSpacing: -4,
            }}
          >
            $0
          </div>
          <div
            style={{
              fontSize: 18,
              color: C.textMuted,
              marginTop: 12,
            }}
          >
            навсегда
          </div>

          {/* Feature pills */}
          <div
            style={{
              display: "flex",
              gap: 8,
              marginTop: 20,
              flexWrap: "wrap",
              justifyContent: "center",
            }}
          >
            {["Безлимит", "WER 8.3%", "Оффлайн"].map((label, i) => (
              <div
                key={label}
                style={{
                  padding: "4px 12px",
                  borderRadius: 16,
                  background: `${C.green}12`,
                  border: `1px solid ${C.green}25`,
                  fontSize: 12,
                  fontWeight: 500,
                  color: C.green,
                  opacity: ease(frame, 0, 1, 50 + i * 8, 65 + i * 8),
                }}
              >
                {label}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Divider */}
      <div
        style={{
          position: "absolute",
          left: 440,
          top: 160,
          bottom: 80,
          width: 1,
          background: `linear-gradient(180deg, transparent, ${C.accent}30, transparent)`,
          opacity: ease(frame, 0, 1, 40, 60),
        }}
      />

      <div
        style={{
          position: "absolute",
          left: 427,
          top: "50%",
          transform: "translateY(-50%)",
          fontSize: 16,
          fontWeight: 600,
          color: C.accent,
          opacity: ease(frame, 0, 1, 50, 65),
          background: C.bg2,
          padding: "4px 8px",
          borderRadius: 8,
        }}
      >
        vs
      </div>

      {/* Right side: Cloud costs stacking */}
      <div
        style={{
          position: "absolute",
          left: 480,
          top: 140,
          right: 60,
        }}
      >
        {cloudServices.map((service, i) => {
          const barDelay = stackStart + service.delay;
          const barWidth = spring({
            frame: Math.max(0, frame - barDelay),
            fps,
            config: { damping: 18, stiffness: 80 },
          });
          const labelOp = ease(frame, 0, 1, barDelay - 3, barDelay + 12);
          const targetWidth = (service.yearly / maxYearly) * 100;

          return (
            <div
              key={service.label}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 12,
                marginBottom: 12,
                opacity: labelOp,
              }}
            >
              <div
                style={{
                  width: 140,
                  textAlign: "right",
                  fontSize: 14,
                  fontWeight: 500,
                  color: C.textMuted,
                  flexShrink: 0,
                }}
              >
                {service.label}
              </div>
              <div
                style={{
                  flex: 1,
                  height: 36,
                  borderRadius: 8,
                  background: "rgba(255,255,255,0.03)",
                  overflow: "hidden",
                  position: "relative",
                }}
              >
                <div
                  style={{
                    width: `${targetWidth * barWidth}%`,
                    height: "100%",
                    borderRadius: 8,
                    background: `linear-gradient(90deg, ${service.color}66, ${service.color}44)`,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "flex-end",
                    paddingRight: 10,
                  }}
                >
                  <span
                    style={{
                      fontSize: 14,
                      fontWeight: 700,
                      color: "white",
                      opacity: ease(frame, 0, 1, barDelay + 12, barDelay + 22),
                      whiteSpace: "nowrap",
                    }}
                  >
                    ${service.yearly}
                  </span>
                </div>
              </div>
            </div>
          );
        })}

        {/* Total cloud cost callout */}
        <div
          style={{
            marginTop: 24,
            marginLeft: 152,
            opacity: summaryOpacity,
            display: "flex",
            alignItems: "center",
            gap: 12,
          }}
        >
          <div
            style={{
              padding: "10px 20px",
              borderRadius: 12,
              background: `${C.red}15`,
              border: `1px solid ${C.red}30`,
            }}
          >
            <span style={{ fontSize: 14, color: C.textMuted }}>
              За 3 года:{" "}
            </span>
            <span style={{ fontSize: 20, fontWeight: 700, color: C.red }}>
              $230 -- $1037
            </span>
          </div>
        </div>
      </div>

      {/* Source */}
      <div
        style={{
          position: "absolute",
          bottom: 24,
          left: 60,
          right: 60,
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          opacity: ease(frame, 0, 1, 120, 145),
        }}
      >
        <div style={{ fontSize: 12, color: C.textDim }}>
          Цены актуальны на февраль 2026. Источники: официальные страницы тарифов.
        </div>
        <div style={{ fontSize: 16, fontWeight: 600, color: C.accent }}>
          traart.app
        </div>
      </div>
    </AbsoluteFill>
  );
};
