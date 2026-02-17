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
import { ProgressBar } from "./components/mac-menubar/ProgressBar";

/**
 * HowItWorksV3 — "Split Screen Race" (TikTok Teaser)
 * 1920x1080, 660 frames @ 30fps (22 sec)
 *
 * Fast-paced teaser: hook → split race → win → stats punch → CTA
 *
 * Timeline:
 *   0-36:    HOOK — "Час аудио → текст" (fast scale-in)
 *   36-54:   "Два способа" — split screen drops in
 *   54-270:  RACE — cloud crawls, Traart zooms
 *   270-330: WIN — checkmark burst, cloud still loading
 *   330-432: STATS PUNCH — 3 numbers fly in rapid succession
 *   432-540: BIG CLAIM — "В 2× точнее Whisper"
 *   540-660: CTA — sparkle + Traart + pills + url
 */
export const HowItWorksV3: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bgHue = interpolate(frame, [0, 660], [225, 270], {
    extrapolateRight: "clamp",
  });

  // =======================================
  // Animated gradient blobs (mesh-like background)
  // =======================================
  const blob1X = interpolate(frame, [0, 660], [20, 35], { extrapolateRight: "clamp" });
  const blob1Y = interpolate(frame, [0, 660], [30, 50], { extrapolateRight: "clamp" });
  const blob2X = interpolate(frame, [0, 660], [75, 60], { extrapolateRight: "clamp" });
  const blob2Y = interpolate(frame, [0, 660], [60, 40], { extrapolateRight: "clamp" });

  // =======================================
  // SECTION 1: HOOK (0-36) — 1.2 sec
  // =======================================
  const hookScale = spring({
    frame: Math.max(0, frame - 3),
    fps,
    config: { damping: 9, stiffness: 200 },
  });
  const hookOpacity = Math.min(
    ease(frame, 0, 1, 2, 8),
    ease(frame, 1, 0, 28, 36)
  );

  // =======================================
  // SECTION 2: "Два способа" (36-54) — 0.6 sec
  // =======================================
  const splitIntroScale = spring({
    frame: Math.max(0, frame - 37),
    fps,
    config: { damping: 12, stiffness: 250 },
  });
  const splitIntroOp = Math.min(
    ease(frame, 0, 1, 36, 42),
    ease(frame, 1, 0, 48, 55)
  );

  // =======================================
  // SECTION 3: RACE (54-270) — 7.2 sec
  // =======================================
  const raceVisible = frame >= 54 && frame < 340;
  const raceOpacity = Math.min(
    ease(frame, 0, 1, 54, 62),
    ease(frame, 1, 0, 325, 340)
  );

  // Divider slides in from top
  const dividerDrop = spring({
    frame: Math.max(0, frame - 55),
    fps,
    config: { damping: 15, stiffness: 200 },
  });

  // Cloud upload: painfully slow (0 → 45% over full race)
  const cloudPct = frame >= 70
    ? interpolate(frame, [70, 330], [0, 45], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 0;

  // Traart progress: zooms to 100%
  const traartPct = frame >= 70
    ? interpolate(
        frame,
        [70, 100, 140, 200, 255],
        [0, 8, 30, 75, 100],
        { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
      )
    : 0;
  const traartDone = traartPct >= 100;

  // Cloud pain messages appear staggered
  const cloudMsg1 = ease(frame, 0, 1, 120, 130); // "Загрузка..."
  const cloudMsg2 = ease(frame, 0, 1, 180, 190); // "Очередь: ~3 мин"
  const cloudMsg3 = ease(frame, 0, 1, 270, 280); // "Всё ещё грузит..."

  // Traart text appearing (typewriter-style preview)
  const textPreviewChars = frame >= 160
    ? Math.floor(interpolate(frame, [160, 255], [0, 60], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      }))
    : 0;
  const previewText = "Здравствуйте, расскажите о вашем опыте работы с нейросетями...";
  const visibleText = previewText.slice(0, textPreviewChars);

  // =======================================
  // SECTION 4: WIN (270-330) — 2 sec
  // =======================================
  const checkBurst = spring({
    frame: Math.max(0, frame - 260),
    fps,
    config: { damping: 7, stiffness: 140 },
  });

  const winLabelScale = spring({
    frame: Math.max(0, frame - 268),
    fps,
    config: { damping: 10, stiffness: 200 },
  });

  // Flash effect on win
  const flashOpacity = frame >= 258 && frame < 270
    ? interpolate(frame, [258, 262, 270], [0, 0.3, 0], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 0;

  // =======================================
  // SECTION 5: STATS PUNCH (330-432) — 3.4 sec
  // =======================================
  const stats = [
    { value: "8.3%", label: "WER", sub: "точность", color: C.teal, frame: 335 },
    { value: "0₽", label: "навсегда", sub: "бесплатно", color: C.green, frame: 365 },
    { value: "0 байт", label: "в сеть", sub: "оффлайн", color: C.accent, frame: 395 },
  ];
  const statsVisible = frame >= 330 && frame < 440;
  const statsOverallOp = Math.min(
    ease(frame, 0, 1, 330, 340),
    ease(frame, 1, 0, 425, 440)
  );

  // =======================================
  // SECTION 6: BIG CLAIM (432-540) — 3.6 sec
  // =======================================
  const claimVisible = frame >= 432 && frame < 545;
  const claimScale = spring({
    frame: Math.max(0, frame - 435),
    fps,
    config: { damping: 8, stiffness: 120 },
  });
  const claimOp = Math.min(
    ease(frame, 0, 1, 432, 445),
    ease(frame, 1, 0, 530, 545)
  );

  // =======================================
  // SECTION 7: CTA (540-660) — 4 sec
  // =======================================
  const ctaOp = ease(frame, 0, 1, 540, 560);
  const sparkleCtaScale = spring({
    frame: Math.max(0, frame - 545),
    fps,
    config: { damping: 8, stiffness: 100 },
  });

  // Particle burst on CTA (sparkles flying out)
  const particles = Array.from({ length: 16 }, (_, i) => {
    const angle = (i / 16) * Math.PI * 2;
    const dist = spring({
      frame: Math.max(0, frame - 550 - (i % 4)),
      fps,
      config: { damping: 20, stiffness: 80 },
    });
    return {
      x: Math.cos(angle) * dist * 120,
      y: Math.sin(angle) * dist * 120,
      opacity: Math.max(0, 1 - dist * 1.2),
      size: 4 + (i % 3) * 2,
      color: i % 3 === 0 ? C.teal : i % 3 === 1 ? C.accent : C.green,
    };
  });

  return (
    <AbsoluteFill
      style={{
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", sans-serif',
        overflow: "hidden",
      }}
    >
      {/* ========== ANIMATED BACKGROUND ========== */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: `linear-gradient(135deg, ${C.bg1} 0%, ${C.bg2} 50%, ${C.bg3} 100%)`,
        }}
      />
      {/* Drifting blobs */}
      <div
        style={{
          position: "absolute",
          left: `${blob1X}%`,
          top: `${blob1Y}%`,
          width: 600,
          height: 600,
          borderRadius: "50%",
          background: `hsla(${bgHue}, 70%, 20%, 0.6)`,
          filter: "blur(120px)",
          transform: "translate(-50%, -50%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: `${blob2X}%`,
          top: `${blob2Y}%`,
          width: 500,
          height: 500,
          borderRadius: "50%",
          background: `hsla(${bgHue + 40}, 60%, 15%, 0.5)`,
          filter: "blur(100px)",
          transform: "translate(-50%, -50%)",
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

      {/* ========== FLASH EFFECT ========== */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: C.teal,
          opacity: flashOpacity,
          zIndex: 100,
          pointerEvents: "none",
        }}
      />

      {/* ========== HOOK ========== */}
      {frame < 38 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: hookOpacity,
            transform: `scale(${hookScale})`,
          }}
        >
          <div
            style={{
              fontSize: 72,
              fontWeight: 900,
              color: C.text,
              letterSpacing: -3,
              textAlign: "center",
              lineHeight: 1.1,
            }}
          >
            Час аудио
          </div>
          <div
            style={{
              fontSize: 36,
              color: C.teal,
              fontWeight: 600,
              marginTop: 8,
            }}
          >
            → текст за 38 секунд
          </div>
        </div>
      )}

      {/* ========== SPLIT INTRO ========== */}
      {frame >= 36 && frame < 56 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            opacity: splitIntroOp,
            transform: `scale(${splitIntroScale})`,
          }}
        >
          <div
            style={{
              fontSize: 52,
              fontWeight: 800,
              color: C.text,
              letterSpacing: -1,
            }}
          >
            Два способа
          </div>
        </div>
      )}

      {/* ========== SPLIT SCREEN RACE ========== */}
      {raceVisible && (
        <div style={{ position: "absolute", inset: 0, opacity: raceOpacity }}>
          {/* Divider */}
          <div
            style={{
              position: "absolute",
              left: 959,
              top: 0,
              width: 3,
              height: `${dividerDrop * 100}%`,
              background: `linear-gradient(180deg, ${C.accent}80, ${C.accent}20)`,
              zIndex: 15,
            }}
          />

          {/* ---- LEFT: CLOUD (red zone) ---- */}
          <div
            style={{
              position: "absolute",
              left: 0,
              top: 0,
              width: 958,
              bottom: 0,
              overflow: "hidden",
            }}
          >
            {/* Red ambient */}
            <div
              style={{
                position: "absolute",
                inset: 0,
                background: `radial-gradient(ellipse at 50% 50%, ${C.red}08 0%, transparent 70%)`,
              }}
            />

            {/* Label */}
            <div
              style={{
                position: "absolute",
                top: 50,
                left: 0,
                right: 0,
                textAlign: "center",
                opacity: ease(frame, 0, 1, 58, 68),
              }}
            >
              <span
                style={{
                  padding: "6px 20px",
                  borderRadius: 16,
                  background: `${C.red}18`,
                  border: `1px solid ${C.red}30`,
                  fontSize: 18,
                  fontWeight: 600,
                  color: C.red,
                }}
              >
                Облако
              </span>
            </div>

            {/* File icon */}
            <div
              style={{
                position: "absolute",
                top: 130,
                left: "50%",
                transform: `translateX(-50%) scale(${spring({ frame: Math.max(0, frame - 62), fps, config: { damping: 12, stiffness: 200 } })})`,
                textAlign: "center",
              }}
            >
              <div style={{ fontSize: 56 }}>&#127908;</div>
              <div style={{ fontSize: 13, color: C.textMuted, marginTop: 4 }}>
                interview.mp4
              </div>
            </div>

            {/* Upload bar */}
            <div
              style={{
                position: "absolute",
                top: 310,
                left: "50%",
                transform: "translateX(-50%)",
                width: 340,
              }}
            >
              {/* Bar */}
              <div
                style={{
                  height: 8,
                  borderRadius: 4,
                  background: "rgba(255,255,255,0.06)",
                  overflow: "hidden",
                  opacity: ease(frame, 0, 1, 72, 82),
                }}
              >
                <div
                  style={{
                    width: `${cloudPct}%`,
                    height: "100%",
                    borderRadius: 4,
                    background: `linear-gradient(90deg, ${C.red}88, ${C.red}55)`,
                  }}
                />
              </div>
              <div
                style={{
                  textAlign: "center",
                  marginTop: 10,
                  fontSize: 14,
                  color: C.textDim,
                  fontVariantNumeric: "tabular-nums",
                  opacity: ease(frame, 0, 1, 80, 90),
                }}
              >
                Загрузка: {Math.round(cloudPct)}%
              </div>

              {/* Pain messages stagger in */}
              <div style={{ marginTop: 40, textAlign: "center" }}>
                <div
                  style={{
                    opacity: cloudMsg1,
                    fontSize: 15,
                    color: C.orange,
                    marginBottom: 12,
                    transform: `translateX(${(1 - cloudMsg1) * 20}px)`,
                  }}
                >
                  ⏳ Загрузка 127 МБ...
                </div>
                <div
                  style={{
                    opacity: cloudMsg2,
                    fontSize: 15,
                    color: C.red,
                    marginBottom: 12,
                    transform: `translateX(${(1 - cloudMsg2) * 20}px)`,
                  }}
                >
                  🔄 Очередь на сервере: ~3 мин
                </div>
                <div
                  style={{
                    opacity: cloudMsg3,
                    fontSize: 15,
                    color: C.red,
                    fontWeight: 600,
                    transform: `translateX(${(1 - cloudMsg3) * 20}px)`,
                  }}
                >
                  😤 Всё ещё грузит...
                </div>
              </div>
            </div>

            {/* Bottom: sad result */}
            {frame >= 280 && (
              <div
                style={{
                  position: "absolute",
                  bottom: 80,
                  left: 40,
                  right: 40,
                  textAlign: "center",
                  opacity: ease(frame, 0, 1, 280, 295),
                }}
              >
                <div
                  style={{
                    fontSize: 64,
                    fontWeight: 900,
                    color: C.red,
                    fontVariantNumeric: "tabular-nums",
                    opacity: 0.3,
                  }}
                >
                  {Math.round(cloudPct)}%
                </div>
              </div>
            )}
          </div>

          {/* ---- RIGHT: TRAART (teal zone) ---- */}
          <div
            style={{
              position: "absolute",
              left: 962,
              top: 0,
              right: 0,
              bottom: 0,
              overflow: "hidden",
            }}
          >
            {/* Teal ambient */}
            <div
              style={{
                position: "absolute",
                inset: 0,
                background: `radial-gradient(ellipse at 50% 50%, ${C.teal}08 0%, transparent 70%)`,
              }}
            />

            {/* Label */}
            <div
              style={{
                position: "absolute",
                top: 50,
                left: 0,
                right: 0,
                textAlign: "center",
                opacity: ease(frame, 0, 1, 58, 68),
              }}
            >
              <span
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  gap: 6,
                  padding: "6px 20px",
                  borderRadius: 16,
                  background: `${C.teal}18`,
                  border: `1px solid ${C.teal}30`,
                  fontSize: 18,
                  fontWeight: 600,
                  color: C.teal,
                }}
              >
                <TraartSparkleIcon state="idle" size={16} />
                Traart
              </span>
            </div>

            {/* File icon */}
            <div
              style={{
                position: "absolute",
                top: 130,
                left: "50%",
                transform: `translateX(-50%) scale(${spring({ frame: Math.max(0, frame - 64), fps, config: { damping: 12, stiffness: 200 } })})`,
                textAlign: "center",
              }}
            >
              <div style={{ fontSize: 56 }}>&#127908;</div>
              <div style={{ fontSize: 13, color: C.textMuted, marginTop: 4 }}>
                interview.mp4
              </div>
            </div>

            {/* Progress section */}
            <div
              style={{
                position: "absolute",
                top: 280,
                left: "50%",
                transform: "translateX(-50%)",
                width: 380,
              }}
            >
              {!traartDone ? (
                <>
                  {/* Sparkle + status */}
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      gap: 8,
                      marginBottom: 12,
                      opacity: ease(frame, 0, 1, 72, 82),
                    }}
                  >
                    <TraartSparkleIcon
                      state="transcribing"
                      progress={traartPct / 100}
                      size={20}
                    />
                    <span style={{ fontSize: 15, color: C.teal, fontWeight: 500 }}>
                      Локально на Mac
                    </span>
                  </div>
                  {/* ProgressBar component */}
                  <div style={{ opacity: ease(frame, 0, 1, 75, 85) }}>
                    <ProgressBar
                      progress={traartPct / 100}
                      step={
                        traartPct < 15
                          ? "Загрузка модели"
                          : traartPct < 80
                          ? "Транскрибация"
                          : "Финализация"
                      }
                      fileName="interview.mp4"
                      etaString={
                        traartPct < 20
                          ? "~38с"
                          : traartPct < 60
                          ? "~20с"
                          : "~5с"
                      }
                    />
                  </div>

                  {/* Live text preview */}
                  {textPreviewChars > 0 && (
                    <div
                      style={{
                        marginTop: 16,
                        padding: "10px 14px",
                        borderRadius: 10,
                        background: "rgba(255,255,255,0.04)",
                        border: `1px solid ${C.teal}15`,
                        fontSize: 13,
                        color: C.textMuted,
                        lineHeight: 1.5,
                        opacity: ease(frame, 0, 1, 162, 172),
                      }}
                    >
                      <span style={{ color: C.teal, fontSize: 11 }}>Спикер 1: </span>
                      {visibleText}
                      <span
                        style={{
                          display: "inline-block",
                          width: 2,
                          height: 14,
                          background: C.teal,
                          marginLeft: 1,
                          verticalAlign: "middle",
                          opacity: Math.sin(frame * 0.35) > 0 ? 1 : 0,
                        }}
                      />
                    </div>
                  )}
                </>
              ) : (
                /* WIN state */
                <div style={{ textAlign: "center" }}>
                  <div style={{ transform: `scale(${checkBurst})` }}>
                    <svg width={72} height={72} viewBox="0 0 72 72">
                      <circle cx="36" cy="36" r="32" fill={C.appGreen} />
                      <path
                        d="M22 36 L32 46 L50 28"
                        stroke="white"
                        strokeWidth="5"
                        fill="none"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                  </div>
                  <div
                    style={{
                      fontSize: 28,
                      fontWeight: 800,
                      color: C.teal,
                      marginTop: 12,
                      transform: `scale(${winLabelScale})`,
                      textShadow: `0 0 30px ${C.teal}40`,
                    }}
                  >
                    38 секунд!
                  </div>

                  {/* Result preview */}
                  <div
                    style={{
                      marginTop: 16,
                      padding: "10px 14px",
                      borderRadius: 10,
                      background: "rgba(255,255,255,0.04)",
                      border: `1px solid ${C.teal}20`,
                      fontSize: 13,
                      color: C.textMuted,
                      textAlign: "left",
                      lineHeight: 1.5,
                      opacity: ease(frame, 0, 1, 270, 285),
                    }}
                  >
                    <div style={{ color: C.teal, fontSize: 11, marginBottom: 2 }}>Спикер 1:</div>
                    Здравствуйте, расскажите о вашем опыте работы с нейросетями...
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ========== STATS PUNCH ========== */}
      {statsVisible && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 60,
            opacity: statsOverallOp,
          }}
        >
          {stats.map((stat, i) => {
            const sScale = spring({
              frame: Math.max(0, frame - stat.frame),
              fps,
              config: { damping: 8, stiffness: 180 },
            });
            const sOp = ease(frame, 0, 1, stat.frame, stat.frame + 8);
            return (
              <div
                key={stat.label}
                style={{
                  textAlign: "center",
                  transform: `scale(${sScale})`,
                  opacity: sOp,
                }}
              >
                <div
                  style={{
                    fontSize: 72,
                    fontWeight: 900,
                    color: stat.color,
                    lineHeight: 1,
                    textShadow: `0 0 40px ${stat.color}40`,
                    letterSpacing: -2,
                  }}
                >
                  {stat.value}
                </div>
                <div style={{ fontSize: 18, fontWeight: 600, color: C.text, marginTop: 8 }}>
                  {stat.label}
                </div>
                <div style={{ fontSize: 14, color: C.textMuted, marginTop: 2 }}>
                  {stat.sub}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* ========== BIG CLAIM ========== */}
      {claimVisible && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: claimOp,
          }}
        >
          <div
            style={{
              transform: `scale(${claimScale})`,
              textAlign: "center",
            }}
          >
            <div
              style={{
                fontSize: 100,
                fontWeight: 900,
                color: C.text,
                letterSpacing: -4,
                lineHeight: 1,
              }}
            >
              В <span style={{ color: C.teal }}>2×</span> точнее
            </div>
            <div
              style={{
                fontSize: 36,
                color: C.textMuted,
                marginTop: 12,
                fontWeight: 500,
              }}
            >
              Whisper large-v3
            </div>
          </div>
        </div>
      )}

      {/* ========== CTA ========== */}
      {frame >= 540 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: ctaOp,
          }}
        >
          {/* Particle burst */}
          {particles.map((p, i) => (
            <div
              key={i}
              style={{
                position: "absolute",
                left: "50%",
                top: "38%",
                width: p.size,
                height: p.size,
                borderRadius: "50%",
                background: p.color,
                opacity: p.opacity,
                transform: `translate(${p.x - p.size / 2}px, ${p.y - p.size / 2}px)`,
                boxShadow: `0 0 ${p.size * 2}px ${p.color}`,
              }}
            />
          ))}

          {/* Sparkle icon */}
          <div style={{ transform: `scale(${sparkleCtaScale})`, marginBottom: 20 }}>
            <TraartSparkleIcon state="completed" size={72} />
          </div>

          <div
            style={{
              fontSize: 80,
              fontWeight: 900,
              color: C.text,
              letterSpacing: -3,
              marginBottom: 12,
            }}
          >
            Traart
          </div>

          {/* Feature pills with staggered springs */}
          <div style={{ display: "flex", gap: 14, marginBottom: 32 }}>
            {["Оффлайн", "WER 8.3%", "Бесплатно", "Диаризация"].map(
              (label, i) => {
                const pillScale = spring({
                  frame: Math.max(0, frame - 570 - i * 6),
                  fps,
                  config: { damping: 10, stiffness: 200 },
                });
                return (
                  <div
                    key={label}
                    style={{
                      padding: "8px 20px",
                      borderRadius: 24,
                      background: `${C.teal}12`,
                      border: `1px solid ${C.teal}25`,
                      color: C.teal,
                      fontSize: 16,
                      fontWeight: 600,
                      transform: `scale(${pillScale})`,
                    }}
                  >
                    {label}
                  </div>
                );
              }
            )}
          </div>

          <div
            style={{
              fontSize: 26,
              fontWeight: 700,
              color: C.teal,
              opacity: ease(frame, 0, 1, 610, 635),
              textShadow: `0 0 40px ${C.teal}50`,
            }}
          >
            traart.app
          </div>
        </div>
      )}
    </AbsoluteFill>
  );
};
