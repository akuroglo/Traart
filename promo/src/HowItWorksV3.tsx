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
import { FinderWindow } from "./components/ui/FinderWindow";
import type { FinderFileItem } from "./components/ui/FinderWindow";

/**
 * HowItWorksV3 — "Split Screen Race" (TikTok Teaser)
 * 1920x1080, 840 frames @ 30fps (28 sec)
 *
 * Fast-paced teaser with visual feature demos.
 *
 * Timeline:
 *   0-36:    HOOK — "Час аудио → текст за 38 секунд"
 *   36-54:   "Два способа" split intro
 *   54-270:  RACE — cloud crawls, Traart zooms
 *   270-340: WIN — flash + checkmark burst
 *   340-475: FINDER — transcript file appears next to original
 *   475-595: FEATURES — offline / diarization / free (slam-in)
 *   595-690: BIG CLAIM — "В 2× точнее Whisper"
 *   690-840: CTA — sparkle + pills + url
 */
export const HowItWorksV3: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bgHue = interpolate(frame, [0, 840], [225, 270], {
    extrapolateRight: "clamp",
  });

  // =======================================
  // Animated gradient blobs (mesh-like background)
  // =======================================
  const blob1X = interpolate(frame, [0, 840], [20, 38], { extrapolateRight: "clamp" });
  const blob1Y = interpolate(frame, [0, 840], [30, 55], { extrapolateRight: "clamp" });
  const blob2X = interpolate(frame, [0, 840], [75, 58], { extrapolateRight: "clamp" });
  const blob2Y = interpolate(frame, [0, 840], [60, 38], { extrapolateRight: "clamp" });

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

  const dividerDrop = spring({
    frame: Math.max(0, frame - 55),
    fps,
    config: { damping: 15, stiffness: 200 },
  });

  // Cloud: painfully slow (0 → 45%)
  const cloudPct = frame >= 70
    ? interpolate(frame, [70, 330], [0, 45], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 0;

  // Traart: zooms to 100%
  const traartPct = frame >= 70
    ? interpolate(
        frame,
        [70, 100, 140, 200, 255],
        [0, 8, 30, 75, 100],
        { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
      )
    : 0;
  const traartDone = traartPct >= 100;

  // Cloud pain messages
  const cloudMsg1 = ease(frame, 0, 1, 120, 130);
  const cloudMsg2 = ease(frame, 0, 1, 180, 190);
  const cloudMsg3 = ease(frame, 0, 1, 270, 280);

  // Traart typewriter preview
  const textPreviewChars = frame >= 160
    ? Math.floor(interpolate(frame, [160, 255], [0, 60], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      }))
    : 0;
  const previewText = "Здравствуйте, расскажите о вашем опыте работы с нейросетями...";
  const visibleText = previewText.slice(0, textPreviewChars);

  // =======================================
  // SECTION 4: WIN (270-340) — 2.3 sec
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

  const flashOpacity = frame >= 258 && frame < 270
    ? interpolate(frame, [258, 262, 270], [0, 0.3, 0], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 0;

  // =======================================
  // SECTION 5: FINDER (340-475) — 4.5 sec
  // =======================================
  const finderVisible = frame >= 340 && frame < 480;
  const finderWindowScale = spring({
    frame: Math.max(0, frame - 345),
    fps,
    config: { damping: 12, stiffness: 150 },
  });
  const finderOp = Math.min(
    ease(frame, 0, 1, 340, 355),
    ease(frame, 1, 0, 465, 480)
  );

  // New .md file appears at frame 385
  const mdFileScale = spring({
    frame: Math.max(0, frame - 385),
    fps,
    config: { damping: 10, stiffness: 180 },
  });
  const mdFileOp = ease(frame, 0, 1, 385, 395);

  // Glow on the new file
  const mdGlowOp = frame >= 385 && frame < 440
    ? interpolate(frame, [385, 400, 440], [0, 1, 0], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 0;

  const finderFiles: FinderFileItem[] = [
    {
      name: "interview_2025-02-11.mp4",
      icon: "\uD83C\uDFA5",
      size: "127 МБ",
      dateModified: "11 фев 2025, 14:30",
      kind: "Видео MP4",
    },
    {
      name: "notes_standup.txt",
      icon: "\uD83D\uDCC4",
      size: "4 КБ",
      dateModified: "10 фев 2025, 09:15",
      kind: "Текст",
    },
    {
      name: "interview_2025-02-11.md",
      icon: "\uD83D\uDCDD",
      size: "24 КБ",
      dateModified: "11 фев 2025, 14:31",
      kind: "Markdown",
      opacity: mdFileOp,
      scale: mdFileScale,
      glowColor: mdGlowOp > 0 ? C.teal : undefined,
    },
  ];

  // Caption under Finder
  const finderCaptionOp = ease(frame, 0, 1, 410, 425);
  const finderCaptionScale = spring({
    frame: Math.max(0, frame - 412),
    fps,
    config: { damping: 12, stiffness: 200 },
  });

  // =======================================
  // SECTION 6: FEATURES (475-595) — 4 sec
  // =======================================
  const featuresVisible = frame >= 475 && frame < 600;
  const featuresOp = Math.min(
    ease(frame, 0, 1, 475, 490),
    ease(frame, 1, 0, 585, 600)
  );

  const features = [
    {
      icon: "\uD83D\uDD12",
      title: "100% Оффлайн",
      sub: "Данные не покидают Mac",
      color: C.accent,
      startFrame: 480,
    },
    {
      icon: "\uD83D\uDC65",
      title: "Диаризация",
      sub: "Определяет кто говорит",
      color: C.teal,
      startFrame: 500,
    },
    {
      icon: "\uD83C\uDF81",
      title: "Бесплатно",
      sub: "Навсегда, без подписок",
      color: C.green,
      startFrame: 520,
    },
  ];

  // =======================================
  // SECTION 7: BIG CLAIM (595-690) — 3.2 sec
  // =======================================
  const claimVisible = frame >= 595 && frame < 695;
  const claimScale = spring({
    frame: Math.max(0, frame - 598),
    fps,
    config: { damping: 8, stiffness: 120 },
  });
  const claimOp = Math.min(
    ease(frame, 0, 1, 595, 608),
    ease(frame, 1, 0, 680, 695)
  );

  // =======================================
  // SECTION 8: CTA (690-840) — 5 sec
  // =======================================
  const ctaOp = ease(frame, 0, 1, 690, 710);
  const sparkleCtaScale = spring({
    frame: Math.max(0, frame - 695),
    fps,
    config: { damping: 8, stiffness: 100 },
  });

  // Particle burst
  const particles = Array.from({ length: 16 }, (_, i) => {
    const angle = (i / 16) * Math.PI * 2;
    const dist = spring({
      frame: Math.max(0, frame - 700 - (i % 4)),
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
            &rarr; текст за 38 секунд
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
                &#9729; Облако
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

              {/* Pain messages */}
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
                  &#9203; Загрузка 127 МБ...
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
                  &#128260; Очередь на сервере: ~3 мин
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
                  &#128548; Всё ещё грузит...
                </div>
              </div>
            </div>

            {/* Bottom: sad percentage */}
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

      {/* ========== FINDER — FILE SAVES NEXT TO ORIGINAL ========== */}
      {finderVisible && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: finderOp,
          }}
        >
          {/* Finder window with spring entrance */}
          <div
            style={{
              transform: `scale(${finderWindowScale})`,
              transformOrigin: "center center",
            }}
          >
            <FinderWindow
              title="Interviews"
              files={finderFiles}
              width={720}
            />
          </div>

          {/* Arrow pointing from .mp4 to .md + caption */}
          <div
            style={{
              marginTop: 28,
              textAlign: "center",
              opacity: finderCaptionOp,
              transform: `scale(${finderCaptionScale})`,
            }}
          >
            <div
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 10,
                padding: "10px 24px",
                borderRadius: 16,
                background: `${C.teal}15`,
                border: `1px solid ${C.teal}25`,
              }}
            >
              <TraartSparkleIcon state="completed" size={20} />
              <span
                style={{
                  fontSize: 20,
                  fontWeight: 600,
                  color: C.teal,
                }}
              >
                Транскрипция — рядом с оригиналом
              </span>
            </div>
            <div
              style={{
                marginTop: 8,
                fontSize: 15,
                color: C.textMuted,
                opacity: ease(frame, 0, 1, 425, 440),
              }}
            >
              .mp4 &rarr; .md в той же папке, автоматически
            </div>
          </div>
        </div>
      )}

      {/* ========== FEATURES — SLAM-IN CARDS ========== */}
      {featuresVisible && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 32,
            opacity: featuresOp,
          }}
        >
          {features.map((feat, i) => {
            const fScale = spring({
              frame: Math.max(0, frame - feat.startFrame),
              fps,
              config: { damping: 8, stiffness: 180 },
            });
            const fOp = ease(frame, 0, 1, feat.startFrame, feat.startFrame + 10);
            return (
              <div
                key={feat.title}
                style={{
                  width: 280,
                  padding: "32px 24px",
                  borderRadius: 20,
                  background: "rgba(255,255,255,0.06)",
                  backdropFilter: "blur(16px)",
                  border: `1px solid ${feat.color}20`,
                  textAlign: "center",
                  transform: `scale(${fScale})`,
                  opacity: fOp,
                  boxShadow: `0 8px 32px rgba(0,0,0,0.3), 0 0 20px ${feat.color}10`,
                }}
              >
                <div style={{ fontSize: 48, marginBottom: 12 }}>{feat.icon}</div>
                <div
                  style={{
                    fontSize: 24,
                    fontWeight: 800,
                    color: feat.color,
                    marginBottom: 6,
                    letterSpacing: -0.5,
                  }}
                >
                  {feat.title}
                </div>
                <div style={{ fontSize: 15, color: C.textMuted, lineHeight: 1.4 }}>
                  {feat.sub}
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
              В <span style={{ color: C.teal }}>2&times;</span> точнее
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
      {frame >= 690 && (
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

          {/* Feature pills */}
          <div style={{ display: "flex", gap: 14, marginBottom: 32 }}>
            {["Оффлайн", "WER 8.3%", "Бесплатно", "Диаризация"].map(
              (label, i) => {
                const pillScale = spring({
                  frame: Math.max(0, frame - 720 - i * 6),
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
              opacity: ease(frame, 0, 1, 760, 790),
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
