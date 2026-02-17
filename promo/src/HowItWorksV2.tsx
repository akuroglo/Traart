import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  interpolate,
  spring,
  useVideoConfig,
  Easing,
} from "remotion";
import { C } from "./shared/colors";
import { ease } from "./shared/animation";
import { MacMenuBarMockup } from "./components/mac-menubar/MacMenuBarMockup";
import { Background } from "./components/ui/Background";
import type { SparkleState } from "./components/mac-menubar/TraartSparkleIcon";

/**
 * HowItWorksV2 — "Problem → Solution"
 * 1920x1080, 1800 frames @ 30fps (60 sec)
 *
 * Storytelling: Hook → Pain → Solution → Demo → Proof → CTA
 *
 * Timeline:
 *   0-90:     HOOK — Large "8.3%" stat with spring bounce
 *   90-150:   Context — "Лучшая точность. А что у конкурентов?"
 *   150-420:  PAIN — 3 glassmorphic cards show problems
 *   420-540:  SOLUTION REVEAL — cards collapse, sparkle icon appears
 *   540-1080: DEMO — MacMenuBarMockup flow (idle → progress → done)
 *   1080-1380: PROOF — WER mini-bars
 *   1380-1620: FEATURES — animated pills
 *   1620-1800: CTA — traart.app
 */
export const HowItWorksV2: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const bgHue = interpolate(frame, [0, 1800], [220, 280], {
    extrapolateRight: "clamp",
  });

  // =======================================
  // SECTION 1: HOOK — "8.3%" stat splash
  // =======================================
  const statScale = spring({
    frame: Math.max(0, frame - 8),
    fps,
    config: { damping: 8, stiffness: 100 },
  });
  const statOpacity = Math.min(
    ease(frame, 0, 1, 5, 20),
    ease(frame, 1, 0, 75, 90)
  );
  const subtitleOpacity = Math.min(
    ease(frame, 0, 1, 25, 45),
    ease(frame, 1, 0, 75, 90)
  );

  // =======================================
  // SECTION 2: CONTEXT
  // =======================================
  const contextOpacity = Math.min(
    ease(frame, 0, 1, 95, 115),
    ease(frame, 1, 0, 140, 155)
  );

  // =======================================
  // SECTION 3: PAIN CARDS
  // =======================================
  const painCards = [
    {
      icon: "☁️",
      title: "Облако = ждать",
      desc: "Загрузка 500МБ файла, ожидание сервера",
      color: C.orange,
      enterFrame: 160,
    },
    {
      icon: "💸",
      title: "Подписки навсегда",
      desc: "$10-30/мес за 20 часов аудио в месяц",
      color: C.red,
      enterFrame: 220,
    },
    {
      icon: "🤖",
      title: "Whisper ≠ русский",
      desc: "WER 16-21% — каждое 5-е слово с ошибкой",
      color: C.yellow,
      enterFrame: 280,
    },
  ];

  // Cards collapse animation
  const cardsExitProgress = ease(frame, 0, 1, 420, 480);

  // =======================================
  // SECTION 4: SOLUTION REVEAL
  // =======================================
  const solutionSparkleScale = spring({
    frame: Math.max(0, frame - 470),
    fps,
    config: { damping: 10, stiffness: 120 },
  });
  const solutionTextOpacity = ease(frame, 0, 1, 490, 520);
  const solutionFadeOut = ease(frame, 1, 0, 530, 545);
  const solutionVisible = frame >= 460 && frame < 545;

  // =======================================
  // SECTION 5: DEMO — MacMenuBarMockup
  // =======================================
  const demoVisible = frame >= 540 && frame < 1080;
  const demoOpacity = Math.min(
    ease(frame, 0, 1, 540, 570),
    ease(frame, 1, 0, 1050, 1080)
  );

  // Demo phases
  let iconState: SparkleState = "idle";
  let iconProgress = 0;
  let showProgressBar = false;
  let progressValue = 0;
  let menuOpacity = 0;
  let activeSubmenu: "none" | "history" | "settings" = "none";
  let highlightedItem: string | undefined;
  let statusText = "Готово";

  if (demoVisible) {
    const dFrame = frame - 540;

    // 0-60: menu bar appears, idle
    // 60-120: menu opens
    menuOpacity = Math.min(
      ease(dFrame, 0, 1, 60, 75),
      // close menu before progress starts
      dFrame < 180 ? 1 : ease(dFrame, 1, 0, 180, 195)
    );

    // 120-360: transcription progress
    if (dFrame >= 180 && dFrame < 400) {
      iconState = "transcribing";
      showProgressBar = false; // show big progress instead
      progressValue = interpolate(dFrame, [180, 380], [0, 1], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      });
      iconProgress = progressValue;
      statusText = "Транскрибация...";
    }

    // 360-420: completed
    if (dFrame >= 400 && dFrame < 480) {
      iconState = "completed";
      statusText = "Готово";
    }

    // 420-480: history submenu
    if (dFrame >= 440 && dFrame < 500) {
      menuOpacity = ease(dFrame, 0, 1, 440, 455);
      activeSubmenu = "history";
      highlightedItem = "history";
    }

    // 480-540: settings submenu
    if (dFrame >= 500) {
      menuOpacity = Math.min(
        ease(dFrame, 0, 1, 500, 515),
        ease(dFrame, 1, 0, 520, 540)
      );
      activeSubmenu = "settings";
      highlightedItem = "settings";
    }
  }

  // Demo captions
  const demoCaptionIdle = demoVisible && (frame - 540) < 180;
  const demoCaptionProgress = demoVisible && (frame - 540) >= 180 && (frame - 540) < 400;
  const demoCaptionDone = demoVisible && (frame - 540) >= 400 && (frame - 540) < 480;

  // Big progress ring for demo
  const bigProgressVisible = demoVisible && (frame - 540) >= 180 && (frame - 540) < 400;
  const bigProgressPct = interpolate(frame - 540, [180, 380], [0, 100], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // =======================================
  // SECTION 6: PROOF — WER mini-bars
  // =======================================
  const proofVisible = frame >= 1080 && frame < 1380;
  const proofOpacity = Math.min(
    ease(frame, 0, 1, 1080, 1110),
    ease(frame, 1, 0, 1350, 1380)
  );

  const werBars = [
    { label: "GigaAM v3 (Traart)", wer: 8.3, color: C.green, highlight: true },
    { label: "Yandex SpeechKit", wer: 10, color: C.yellow, highlight: false },
    { label: "Google Chirp 2", wer: 16.7, color: C.orange, highlight: false },
    { label: "Whisper large-v3", wer: 21, color: C.red, highlight: false },
  ];

  // =======================================
  // SECTION 7: FEATURES
  // =======================================
  const featuresVisible = frame >= 1380 && frame < 1620;
  const featuresOpacity = Math.min(
    ease(frame, 0, 1, 1380, 1410),
    ease(frame, 1, 0, 1590, 1620)
  );

  const features = [
    { icon: "🔒", label: "100% оффлайн", desc: "Ни байта в сеть" },
    { icon: "🎯", label: "WER 8.3%", desc: "В 2× точнее Whisper" },
    { icon: "👥", label: "Диаризация", desc: "Разделение голосов" },
    { icon: "💰", label: "Бесплатно", desc: "Навсегда, MIT лицензия" },
  ];

  // =======================================
  // SECTION 8: CTA
  // =======================================
  const ctaOpacity = ease(frame, 0, 1, 1620, 1660);

  return (
    <AbsoluteFill
      style={{
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", sans-serif',
        overflow: "hidden",
      }}
    >
      <Background hue={bgHue} />

      {/* ========== HOOK: 8.3% stat ========== */}
      {frame < 90 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: statOpacity,
          }}
        >
          <div
            style={{
              fontSize: 180,
              fontWeight: 900,
              color: C.teal,
              letterSpacing: -8,
              transform: `scale(${statScale})`,
              textShadow: `0 0 80px ${C.teal}40`,
            }}
          >
            8.3%
          </div>
          <div
            style={{
              fontSize: 32,
              color: C.textMuted,
              marginTop: 16,
              opacity: subtitleOpacity,
            }}
          >
            WER — лучший результат для русской речи
          </div>
        </div>
      )}

      {/* ========== CONTEXT ========== */}
      {frame >= 90 && frame < 155 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: contextOpacity,
          }}
        >
          <div
            style={{
              fontSize: 48,
              fontWeight: 700,
              color: C.text,
              letterSpacing: -1,
              textAlign: "center",
            }}
          >
            А что у остальных?
          </div>
        </div>
      )}

      {/* ========== PAIN CARDS ========== */}
      {frame >= 150 && frame < 500 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 40,
          }}
        >
          {painCards.map((card, i) => {
            const cardOpacity = ease(frame, 0, 1, card.enterFrame, card.enterFrame + 20);
            const cardY = ease(frame, 30, 0, card.enterFrame, card.enterFrame + 25);
            const cardExitScale = interpolate(cardsExitProgress, [0, 1], [1, 0.3], {
              extrapolateRight: "clamp",
            });
            const cardExitOpacity = 1 - cardsExitProgress;
            const cardSpring = spring({
              frame: Math.max(0, frame - card.enterFrame),
              fps,
              config: { damping: 12, stiffness: 150 },
            });

            return (
              <div
                key={i}
                style={{
                  width: 320,
                  padding: "40px 32px",
                  borderRadius: 20,
                  background: "rgba(255,255,255,0.06)",
                  backdropFilter: "blur(16px)",
                  border: `1px solid ${card.color}25`,
                  boxShadow: `0 8px 32px rgba(0,0,0,0.3), 0 0 40px ${card.color}10`,
                  textAlign: "center",
                  opacity: Math.min(cardOpacity, cardExitOpacity),
                  transform: `translateY(${cardY}px) scale(${Math.min(cardSpring, cardExitScale)})`,
                }}
              >
                <div style={{ fontSize: 48, marginBottom: 16 }}>{card.icon}</div>
                <div
                  style={{
                    fontSize: 22,
                    fontWeight: 700,
                    color: card.color,
                    marginBottom: 8,
                  }}
                >
                  {card.title}
                </div>
                <div style={{ fontSize: 16, color: C.textMuted, lineHeight: 1.4 }}>
                  {card.desc}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* ========== SOLUTION REVEAL ========== */}
      {solutionVisible && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: solutionFadeOut,
          }}
        >
          <div
            style={{
              transform: `scale(${solutionSparkleScale * 3})`,
              marginBottom: 24,
            }}
          >
            <svg width={60} height={60} viewBox="0 0 18 18" fill="none">
              <path
                d="M 9 2 Q 10.26 7.74 16 9 Q 10.26 10.26 9 16 Q 7.74 10.26 2 9 Q 7.74 7.74 9 2 Z"
                fill={C.teal}
              />
              <g stroke={C.teal} strokeLinecap="round">
                <line x1={15} y1={2.25} x2={15} y2={5.25} strokeWidth={1.2} />
                <line x1={13.5} y1={3.75} x2={16.5} y2={3.75} strokeWidth={1.2} />
                <line x1={3} y1={12.75} x2={3} y2={14.25} strokeWidth={1.0} />
                <line x1={2.25} y1={13.5} x2={3.75} y2={13.5} strokeWidth={1.0} />
              </g>
            </svg>
          </div>
          <div
            style={{
              fontSize: 56,
              fontWeight: 800,
              color: C.text,
              letterSpacing: -2,
              opacity: solutionTextOpacity,
            }}
          >
            Или просто Traart.
          </div>
          <div
            style={{
              fontSize: 22,
              color: C.textMuted,
              marginTop: 12,
              opacity: solutionTextOpacity,
            }}
          >
            Локально. Мгновенно. Бесплатно.
          </div>
        </div>
      )}

      {/* ========== DEMO ========== */}
      {demoVisible && (
        <div
          style={{
            position: "absolute",
            top: 100,
            left: "50%",
            transform: "translateX(-50%)",
            opacity: demoOpacity,
            zIndex: 20,
          }}
        >
          <MacMenuBarMockup
            scale={1.8}
            iconState={iconState}
            iconProgress={iconProgress}
            menuOpacity={menuOpacity}
            activeSubmenu={activeSubmenu}
            highlightedItem={highlightedItem}
            showProgressBar={false}
            statusText={statusText}
          />
        </div>
      )}

      {/* Demo: big progress ring */}
      {bigProgressVisible && (
        <div
          style={{
            position: "absolute",
            bottom: 180,
            left: "50%",
            transform: "translateX(-50%)",
            display: "flex",
            alignItems: "center",
            gap: 30,
            opacity: Math.min(
              ease(frame - 540, 0, 1, 185, 200),
              ease(frame - 540, 1, 0, 380, 400)
            ),
            zIndex: 25,
          }}
        >
          <svg width={100} height={100} viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="42" stroke={`${C.teal}20`} strokeWidth="6" fill="none" />
            <circle
              cx="50" cy="50" r="42"
              stroke={C.teal}
              strokeWidth="6" fill="none"
              strokeDasharray={`${(bigProgressPct / 100) * 263.9} 263.9`}
              strokeLinecap="round"
              transform="rotate(-90 50 50)"
            />
            <text
              x="50" y="55"
              textAnchor="middle"
              fill="white" fontSize="24" fontWeight="700"
              fontFamily="-apple-system, sans-serif"
            >
              {Math.round(bigProgressPct)}%
            </text>
          </svg>
          <div style={{ color: "white" }}>
            <div style={{ fontSize: 20, fontWeight: 600 }}>
              {bigProgressPct < 30 ? "Загрузка модели..." : bigProgressPct < 70 ? "Транскрибация..." : "Финализация..."}
            </div>
            <div style={{ fontSize: 14, color: C.textMuted, marginTop: 4 }}>
              interview_2025-02-11.mp4
            </div>
          </div>
        </div>
      )}

      {/* Demo captions */}
      {demoCaptionIdle && (
        <div
          style={{
            position: "absolute",
            bottom: 60,
            left: 0, right: 0,
            textAlign: "center",
            opacity: Math.min(
              ease(frame - 540, 0, 1, 10, 30),
              ease(frame - 540, 1, 0, 160, 180)
            ),
            zIndex: 50,
          }}
        >
          <div style={{ fontSize: 36, fontWeight: 700, color: C.text }}>
            1. Работает в фоне
          </div>
          <div style={{ fontSize: 18, color: C.textMuted, marginTop: 8 }}>
            Traart живёт в menu bar и следит за новыми записями
          </div>
        </div>
      )}

      {demoCaptionProgress && (
        <div
          style={{
            position: "absolute",
            bottom: 60,
            left: 0, right: 0,
            textAlign: "center",
            opacity: Math.min(
              ease(frame - 540, 0, 1, 185, 205),
              ease(frame - 540, 1, 0, 380, 400)
            ),
            zIndex: 50,
          }}
        >
          <div style={{ fontSize: 36, fontWeight: 700, color: C.text }}>
            2. Транскрибирует автоматически
          </div>
          <div style={{ fontSize: 18, color: C.textMuted, marginTop: 8 }}>
            GigaAM v3 — на вашем Mac, без интернета
          </div>
        </div>
      )}

      {demoCaptionDone && (
        <div
          style={{
            position: "absolute",
            bottom: 60,
            left: 0, right: 0,
            textAlign: "center",
            opacity: Math.min(
              ease(frame - 540, 0, 1, 405, 420),
              ease(frame - 540, 1, 0, 460, 480)
            ),
            zIndex: 50,
          }}
        >
          <div style={{ fontSize: 36, fontWeight: 700, color: C.text }}>
            3. Готово!
          </div>
          <div style={{ fontSize: 18, color: C.textMuted, marginTop: 8 }}>
            Текст появляется рядом с оригиналом
          </div>
        </div>
      )}

      {/* ========== PROOF: WER bars ========== */}
      {proofVisible && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: proofOpacity,
          }}
        >
          <div
            style={{
              fontSize: 36,
              fontWeight: 700,
              color: C.text,
              marginBottom: 40,
              letterSpacing: -0.5,
            }}
          >
            Точность распознавания (WER)
          </div>
          <div style={{ width: 800 }}>
            {werBars.map((bar, i) => {
              const barDelay = 1100 + i * 20;
              const barWidth = spring({
                frame: Math.max(0, frame - barDelay),
                fps,
                config: { damping: 18, stiffness: 80 },
              });
              const targetWidth = (bar.wer / 28) * 100;
              return (
                <div
                  key={bar.label}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    marginBottom: 16,
                    opacity: ease(frame, 0, 1, barDelay - 5, barDelay + 15),
                  }}
                >
                  <div
                    style={{
                      width: 200,
                      textAlign: "right",
                      paddingRight: 16,
                      fontSize: 16,
                      fontWeight: bar.highlight ? 700 : 400,
                      color: bar.highlight ? bar.color : C.textMuted,
                    }}
                  >
                    {bar.label}
                  </div>
                  <div
                    style={{
                      flex: 1,
                      height: 36,
                      borderRadius: 8,
                      background: "rgba(255,255,255,0.04)",
                      overflow: "hidden",
                    }}
                  >
                    <div
                      style={{
                        width: `${targetWidth * barWidth}%`,
                        height: "100%",
                        borderRadius: 8,
                        background: bar.highlight
                          ? `linear-gradient(90deg, ${bar.color}, ${bar.color}dd)`
                          : `linear-gradient(90deg, ${bar.color}66, ${bar.color}44)`,
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "flex-end",
                        paddingRight: 12,
                      }}
                    >
                      <span
                        style={{
                          fontSize: 16,
                          fontWeight: 700,
                          color: "white",
                          opacity: ease(frame, 0, 1, barDelay + 15, barDelay + 25),
                        }}
                      >
                        {bar.wer}%
                      </span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
          <div style={{ fontSize: 13, color: C.textDim, marginTop: 24 }}>
            GigaAM v3: INTERSPEECH 2025 (arXiv:2506.01192)
          </div>
        </div>
      )}

      {/* ========== FEATURES ========== */}
      {featuresVisible && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 32,
            opacity: featuresOpacity,
          }}
        >
          {features.map((f, i) => {
            const fScale = spring({
              frame: Math.max(0, frame - 1395 - i * 12),
              fps,
              config: { damping: 12, stiffness: 200 },
            });
            return (
              <div
                key={f.label}
                style={{
                  width: 220,
                  padding: "32px 24px",
                  borderRadius: 20,
                  background: "rgba(255,255,255,0.06)",
                  border: "1px solid rgba(255,255,255,0.1)",
                  textAlign: "center",
                  transform: `scale(${fScale})`,
                }}
              >
                <div style={{ fontSize: 40, marginBottom: 12 }}>{f.icon}</div>
                <div
                  style={{
                    fontSize: 18,
                    fontWeight: 700,
                    color: C.text,
                    marginBottom: 6,
                  }}
                >
                  {f.label}
                </div>
                <div style={{ fontSize: 14, color: C.textMuted }}>{f.desc}</div>
              </div>
            );
          })}
        </div>
      )}

      {/* ========== CTA ========== */}
      {frame >= 1620 && (
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
          <div
            style={{
              fontSize: 80,
              fontWeight: 800,
              color: C.text,
              letterSpacing: -3,
              marginBottom: 16,
            }}
          >
            Traart
          </div>
          <div
            style={{
              fontSize: 26,
              color: C.textMuted,
              textAlign: "center",
              lineHeight: 1.5,
              marginBottom: 40,
            }}
          >
            Лучшая транскрибация русской речи.
            <br />
            Локально. Бесплатно. Без компромиссов.
          </div>
          <div
            style={{
              fontSize: 28,
              fontWeight: 700,
              color: C.teal,
              opacity: ease(frame, 0, 1, 1700, 1730),
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
