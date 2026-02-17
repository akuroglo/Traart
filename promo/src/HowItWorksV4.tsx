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
import { TraartSparkleIcon } from "./components/mac-menubar/TraartSparkleIcon";

/**
 * HowItWorksV4 — "Typewriter Magic"
 * 1920x1080, 900 frames @ 30fps (30 sec)
 *
 * Focused on the "magic moment": audio → text appearing character by character.
 * Glassmorphic card, audio waveform, typewriter effect with diarization.
 *
 * Timeline:
 *   0-60:    Sparkle icon appears, pulses
 *   60-150:  Audio waveform fades in, file info
 *   150-180: "Processing started" — sparkle fills
 *   180-600: Typewriter: text appears char by char, waveform "consumed"
 *   600-720: Full text visible, stats appear
 *   720-900: CTA
 */
export const HowItWorksV4: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bgHue = interpolate(frame, [0, 900], [230, 265], {
    extrapolateRight: "clamp",
  });

  // Sparkle icon animation
  const sparkleScale = spring({
    frame: Math.max(0, frame - 10),
    fps,
    config: { damping: 8, stiffness: 100 },
  });
  const sparkleOpacity = ease(frame, 0, 1, 5, 20);

  // Sparkle state
  let sparkleState: "idle" | "transcribing" | "completed" = "idle";
  let sparkleProgress = 0;
  if (frame >= 150 && frame < 600) {
    sparkleState = "transcribing";
    sparkleProgress = interpolate(frame, [150, 590], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
  } else if (frame >= 600) {
    sparkleState = "completed";
  }

  // Card opacity
  const cardOpacity = Math.min(
    ease(frame, 0, 1, 50, 80),
    ease(frame, 1, 0, 700, 725)
  );

  // Waveform
  const waveformOpacity = Math.min(
    ease(frame, 0, 1, 65, 90),
    ease(frame, 1, 0, 580, 600)
  );
  // Waveform "consumed" from left
  const waveformConsumed = frame >= 180
    ? interpolate(frame, [180, 590], [0, 100], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 0;

  // File info
  const fileOpacity = ease(frame, 0, 1, 80, 100);

  // Typewriter text
  const transcriptLines = [
    { speaker: "Спикер 1", text: "Здравствуйте, сегодня мы обсудим применение нейросетей в обработке речи.", color: C.teal },
    { speaker: "Спикер 2", text: "Да, это очень актуальная тема. Расскажите, какие модели вы используете?", color: C.accentGlow },
    { speaker: "Спикер 1", text: "Мы работаем с GigaAM — это state-of-the-art модель для русского языка.", color: C.teal },
    { speaker: "Спикер 2", text: "Какой WER удалось достичь?", color: C.accentGlow },
    { speaker: "Спикер 1", text: "8.3 процента — лучший результат на бенчмарках INTERSPEECH 2025.", color: C.teal },
  ];

  const fullText = transcriptLines.map((l) => l.text).join("");
  const totalChars = fullText.length;

  // How many characters are visible
  const charsVisible = frame >= 180
    ? Math.floor(
        interpolate(frame, [180, 590], [0, totalChars], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        })
      )
    : 0;

  // Build visible lines
  let charsRemaining = charsVisible;
  const visibleLines = transcriptLines.map((line) => {
    if (charsRemaining <= 0) return { ...line, visibleText: "", visible: false };
    const show = Math.min(charsRemaining, line.text.length);
    charsRemaining -= show;
    return { ...line, visibleText: line.text.slice(0, show), visible: true };
  });

  // Stats after completion
  const statsVisible = frame >= 600 && frame < 725;
  const statsOpacity = Math.min(
    ease(frame, 0, 1, 610, 640),
    ease(frame, 1, 0, 700, 725)
  );

  // CTA
  const ctaOpacity = ease(frame, 0, 1, 725, 760);

  // Generate deterministic waveform bars
  const waveformBars = Array.from({ length: 80 }, (_, i) => {
    const seed = Math.sin(i * 127.1 + 311.7) * 43758.5453;
    return 0.2 + (seed - Math.floor(seed)) * 0.8;
  });

  // Pulsing glow during transcription
  const glowIntensity = sparkleState === "transcribing"
    ? 0.15 + 0.1 * Math.sin(frame * 0.1)
    : sparkleState === "completed"
    ? 0.3
    : 0;

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

      {/* ========== SPARKLE ICON (top center) ========== */}
      <div
        style={{
          position: "absolute",
          top: 60,
          left: "50%",
          transform: `translateX(-50%) scale(${sparkleScale})`,
          opacity: sparkleOpacity,
          filter: `drop-shadow(0 0 ${20 + glowIntensity * 40}px ${C.teal}${Math.round(glowIntensity * 255).toString(16).padStart(2, "0")})`,
        }}
      >
        <TraartSparkleIcon
          state={sparkleState}
          progress={sparkleProgress}
          size={64}
        />
      </div>

      {/* Status text under sparkle */}
      <div
        style={{
          position: "absolute",
          top: 140,
          left: 0,
          right: 0,
          textAlign: "center",
        }}
      >
        {sparkleState === "idle" && (
          <div
            style={{
              fontSize: 18,
              color: C.textMuted,
              opacity: ease(frame, 0, 1, 30, 50),
            }}
          >
            Traart
          </div>
        )}
        {sparkleState === "transcribing" && (
          <div
            style={{
              fontSize: 16,
              color: C.teal,
              fontWeight: 500,
              fontVariantNumeric: "tabular-nums",
              opacity: ease(frame, 0, 1, 155, 170),
            }}
          >
            Транскрибация... {Math.round(sparkleProgress * 100)}%
          </div>
        )}
        {sparkleState === "completed" && (
          <div
            style={{
              fontSize: 16,
              color: C.appGreen,
              fontWeight: 600,
              opacity: ease(frame, 0, 1, 605, 615),
            }}
          >
            Готово!
          </div>
        )}
      </div>

      {/* ========== GLASSMORPHIC CARD ========== */}
      <div
        style={{
          position: "absolute",
          top: 190,
          left: "50%",
          transform: "translateX(-50%)",
          width: 900,
          minHeight: 520,
          borderRadius: 24,
          background: "rgba(255,255,255,0.05)",
          backdropFilter: "blur(20px)",
          border: `1px solid rgba(255,255,255,0.08)`,
          boxShadow: `0 16px 64px rgba(0,0,0,0.4), 0 0 ${glowIntensity * 80}px ${C.teal}${Math.round(glowIntensity * 60).toString(16).padStart(2, "0")}`,
          padding: "28px 36px",
          opacity: cardOpacity,
        }}
      >
        {/* File header */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 12,
            marginBottom: 20,
            opacity: fileOpacity,
          }}
        >
          <div
            style={{
              width: 36,
              height: 36,
              borderRadius: 8,
              background: `${C.accent}20`,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 18,
            }}
          >
            &#127908;
          </div>
          <div>
            <div style={{ fontSize: 15, fontWeight: 600, color: C.text }}>
              interview_2025-02-11.mp4
            </div>
            <div style={{ fontSize: 12, color: C.textDim }}>
              5:23 &middot; 127 МБ &middot; 2 спикера
            </div>
          </div>
        </div>

        {/* Waveform */}
        <div
          style={{
            position: "relative",
            height: 48,
            marginBottom: 20,
            opacity: waveformOpacity,
            overflow: "hidden",
          }}
        >
          <svg width="828" height="48" viewBox="0 0 828 48">
            {waveformBars.map((h, i) => {
              const barX = i * 10.35;
              const barH = h * 40;
              const isConsumed = (i / 80) * 100 < waveformConsumed;
              return (
                <rect
                  key={i}
                  x={barX}
                  y={24 - barH / 2}
                  width={6}
                  height={barH}
                  rx={3}
                  fill={isConsumed ? C.teal : `${C.accent}40`}
                  opacity={isConsumed ? 0.9 : 0.5}
                />
              );
            })}
          </svg>
          {/* Playhead */}
          {waveformConsumed > 0 && waveformConsumed < 100 && (
            <div
              style={{
                position: "absolute",
                left: `${waveformConsumed}%`,
                top: 0,
                bottom: 0,
                width: 2,
                background: C.teal,
                boxShadow: `0 0 8px ${C.teal}`,
              }}
            />
          )}
        </div>

        {/* Separator */}
        <div
          style={{
            height: 1,
            background: "rgba(255,255,255,0.06)",
            marginBottom: 20,
          }}
        />

        {/* Typewriter transcript */}
        <div style={{ minHeight: 300 }}>
          {visibleLines.map((line, i) => {
            if (!line.visible) return null;
            return (
              <div key={i} style={{ marginBottom: 16 }}>
                <div
                  style={{
                    fontSize: 12,
                    fontWeight: 600,
                    color: line.color,
                    marginBottom: 3,
                    opacity: 0.8,
                  }}
                >
                  {line.speaker}:
                </div>
                <div
                  style={{
                    fontSize: 16,
                    color: C.text,
                    lineHeight: 1.5,
                  }}
                >
                  {line.visibleText}
                  {/* Blinking cursor on last visible line */}
                  {i === visibleLines.filter((l) => l.visible).length - 1 &&
                    line.visibleText.length < line.text.length && (
                      <span
                        style={{
                          display: "inline-block",
                          width: 2,
                          height: 16,
                          background: C.teal,
                          marginLeft: 1,
                          verticalAlign: "middle",
                          opacity: Math.sin(frame * 0.3) > 0 ? 1 : 0,
                        }}
                      />
                    )}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* ========== STATS ========== */}
      {statsVisible && (
        <div
          style={{
            position: "absolute",
            bottom: 80,
            left: 0,
            right: 0,
            display: "flex",
            justifyContent: "center",
            gap: 40,
            opacity: statsOpacity,
          }}
        >
          {[
            { label: "Время", value: "38с", icon: "&#9201;" },
            { label: "Точность", value: "WER 8.3%", icon: "&#127919;" },
            { label: "Оффлайн", value: "0 байт в сеть", icon: "&#128274;" },
          ].map((stat, i) => {
            const sSpring = spring({
              frame: Math.max(0, frame - 620 - i * 10),
              fps,
              config: { damping: 12, stiffness: 200 },
            });
            return (
              <div
                key={stat.label}
                style={{
                  textAlign: "center",
                  transform: `scale(${sSpring})`,
                }}
              >
                <div
                  style={{ fontSize: 24, marginBottom: 4 }}
                  dangerouslySetInnerHTML={{ __html: stat.icon }}
                />
                <div style={{ fontSize: 20, fontWeight: 700, color: C.teal }}>
                  {stat.value}
                </div>
                <div style={{ fontSize: 13, color: C.textMuted }}>{stat.label}</div>
              </div>
            );
          })}
        </div>
      )}

      {/* ========== CTA ========== */}
      {frame >= 720 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: ctaOpacity,
          }}
        >
          <div style={{ transform: `scale(${spring({ frame: Math.max(0, frame - 730), fps, config: { damping: 8, stiffness: 100 } })})` }}>
            <TraartSparkleIcon state="completed" size={80} />
          </div>
          <div
            style={{
              fontSize: 72,
              fontWeight: 800,
              color: C.text,
              letterSpacing: -3,
              marginTop: 20,
              marginBottom: 12,
            }}
          >
            Traart
          </div>
          <div
            style={{
              fontSize: 22,
              color: C.textMuted,
              textAlign: "center",
              lineHeight: 1.5,
              marginBottom: 32,
            }}
          >
            Слышит русскую речь лучше всех.
          </div>
          <div style={{ display: "flex", gap: 16, marginBottom: 32 }}>
            {["WER 8.3%", "Оффлайн", "Бесплатно", "Диаризация"].map(
              (label, i) => (
                <div
                  key={label}
                  style={{
                    padding: "8px 20px",
                    borderRadius: 24,
                    background: `${C.teal}12`,
                    border: `1px solid ${C.teal}25`,
                    color: C.teal,
                    fontSize: 15,
                    fontWeight: 600,
                    opacity: ease(frame, 0, 1, 760 + i * 8, 780 + i * 8),
                  }}
                >
                  {label}
                </div>
              )
            )}
          </div>
          <div
            style={{
              fontSize: 24,
              fontWeight: 700,
              color: C.teal,
              opacity: ease(frame, 0, 1, 820, 850),
              textShadow: `0 0 40px ${C.teal}40`,
            }}
          >
            traart.app
          </div>
        </div>
      )}
    </AbsoluteFill>
  );
};
