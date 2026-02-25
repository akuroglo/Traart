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
import { MacMenuBar } from "./components/mac-menubar/MacMenuBar";
import { MacMenu } from "./components/mac-menubar/MacMenu";
import {
  MenuItem,
  MenuSeparator,
  MenuTitle,
} from "./components/mac-menubar/MenuItem";
import { TraartSparkleIcon } from "./components/mac-menubar/TraartSparkleIcon";
import { MacMenuBarMockup } from "./components/mac-menubar/MacMenuBarMockup";
import { FinderWindow } from "./components/ui/FinderWindow";
import type { FinderFileItem } from "./components/ui/FinderWindow";

/**
 * HowItWorksV5 — "Dynamic 3-Step Walkthrough"
 * 1920x1080, 810 frames @ 30fps (27 sec)
 *
 * Same screens as HowItWorks v1 but with spring physics, flash transitions,
 * scanning highlights, Finder window, animated mesh background.
 *
 * Timeline:
 *   0-55:    INTRO — "Как работает Traart" spring slam
 *   58-190:  STEP 1 — Menu bar drops in, dropdown opens, items scan-highlight
 *   195-370: STEP 2 — Progress ring + sparkle filling + typewriter text
 *   375-530: STEP 3 — Checkmark burst → Finder window with .md file
 *   535-600: BONUS — History submenu (MacMenuBarMockup)
 *   605-658: BONUS — Settings submenu (MacMenuBarMockup)
 *   662-810: OUTRO — Traart + particles + pills + url
 */

// ============================================================
// Menu bar icon helper (idle / progress / done)
// ============================================================
const TraartMenuBarIcon: React.FC<{
  state: "idle" | "progress" | "done";
  progress?: number;
  scale?: number;
}> = ({ state, progress = 0, scale = 1 }) => {
  if (state === "idle") {
    return (
      <span
        style={{
          fontSize: 14 * scale,
          display: "flex",
          alignItems: "center",
          gap: 2 * scale,
          opacity: 0.7,
        }}
      >
        <TraartSparkleIcon state="idle" size={16 * scale} />
      </span>
    );
  }
  if (state === "progress") {
    return (
      <span
        style={{
          fontSize: 12 * scale,
          fontWeight: 500,
          display: "flex",
          alignItems: "center",
          gap: 4 * scale,
          color: C.teal,
        }}
      >
        <TraartSparkleIcon
          state="transcribing"
          progress={progress / 100}
          size={16 * scale}
        />
        {Math.round(progress)}%
      </span>
    );
  }
  return (
    <span
      style={{
        fontSize: 14 * scale,
        display: "flex",
        alignItems: "center",
        gap: 2 * scale,
      }}
    >
      <TraartSparkleIcon state="completed" size={16 * scale} />
    </span>
  );
};

// ============================================================
// Main Composition
// ============================================================
export const HowItWorksV5: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const S = 1.8;

  const bgHue = interpolate(frame, [0, 810], [230, 275], {
    extrapolateRight: "clamp",
  });

  // Animated mesh blobs
  const blob1X = interpolate(frame, [0, 810], [22, 38], { extrapolateRight: "clamp" });
  const blob1Y = interpolate(frame, [0, 810], [28, 52], { extrapolateRight: "clamp" });
  const blob2X = interpolate(frame, [0, 810], [78, 60], { extrapolateRight: "clamp" });
  const blob2Y = interpolate(frame, [0, 810], [65, 40], { extrapolateRight: "clamp" });

  // ======================================================
  // FLASH TRANSITIONS
  // ======================================================
  const flash1 =
    frame >= 52 && frame < 63
      ? interpolate(frame, [52, 56, 63], [0, 0.2, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        })
      : 0;
  const flash2 =
    frame >= 367 && frame < 378
      ? interpolate(frame, [367, 371, 378], [0, 0.25, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        })
      : 0;
  const flash3 =
    frame >= 656 && frame < 667
      ? interpolate(frame, [656, 660, 667], [0, 0.2, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        })
      : 0;

  // ======================================================
  // SECTION 1: INTRO (0-55)
  // ======================================================
  const introScale = spring({
    frame: Math.max(0, frame - 5),
    fps,
    config: { damping: 9, stiffness: 180 },
  });
  const introOp = Math.min(
    ease(frame, 0, 1, 3, 12),
    ease(frame, 1, 0, 44, 55)
  );

  // ======================================================
  // SECTION 2: STEP 1 — MENU BAR + DROPDOWN (58-190)
  // ======================================================
  const step1Visible = frame >= 58 && frame < 195;
  const step1Op = Math.min(
    ease(frame, 0, 1, 58, 68),
    ease(frame, 1, 0, 182, 195)
  );

  // Badge springs in
  const badge1Scale = spring({
    frame: Math.max(0, frame - 60),
    fps,
    config: { damping: 10, stiffness: 200 },
  });

  // Menu bar drops from top
  const menuBarDrop = spring({
    frame: Math.max(0, frame - 64),
    fps,
    config: { damping: 12, stiffness: 150 },
  });

  // Dropdown opens with spring
  const dropdownSpring = spring({
    frame: Math.max(0, frame - 80),
    fps,
    config: { damping: 12, stiffness: 180 },
  });
  const dropdownOp = ease(frame, 0, 1, 80, 92);

  // Scanning highlights — each item highlighted for ~13 frames
  const hlCopy = frame >= 95 && frame < 108;
  const hlTranscribe = frame >= 108 && frame < 121;
  const hlNewFiles = frame >= 121 && frame < 134;
  const hlHistory = frame >= 134 && frame < 147;
  const hlSettings = frame >= 147 && frame < 162;

  // Step 1 caption
  const step1CaptionOp = Math.min(
    ease(frame, 0, 1, 70, 82),
    ease(frame, 1, 0, 180, 192)
  );

  // ======================================================
  // SECTION 3: STEP 2 — PROGRESS (195-370)
  // ======================================================
  const step2Visible = frame >= 195 && frame < 375;
  const step2Op = Math.min(
    ease(frame, 0, 1, 195, 208),
    ease(frame, 1, 0, 362, 375)
  );

  const badge2Scale = spring({
    frame: Math.max(0, frame - 198),
    fps,
    config: { damping: 10, stiffness: 200 },
  });

  // Progress 0→100%
  const progressValue = interpolate(
    frame,
    [212, 250, 280, 320, 340],
    [0, 12, 35, 72, 100],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  // Menu bar icon state
  let iconState: "idle" | "progress" | "done" = "idle";
  if (frame >= 208 && frame < 345) iconState = "progress";
  else if (frame >= 345) iconState = "done";

  // Menu bar during step 2
  const menuBar2Drop = spring({
    frame: Math.max(0, frame - 200),
    fps,
    config: { damping: 12, stiffness: 150 },
  });

  // Progress ring spring
  const ringScale = spring({
    frame: Math.max(0, frame - 216),
    fps,
    config: { damping: 12, stiffness: 180 },
  });

  // Typewriter text
  const typeChars =
    frame >= 255
      ? Math.floor(
          interpolate(frame, [255, 340], [0, 72], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })
        )
      : 0;
  const previewFull =
    "Здравствуйте, сегодня мы обсудим применение нейросетей в обработке речи.";
  const previewVisible = previewFull.slice(0, typeChars);

  // Step 2 caption
  const step2CaptionOp = Math.min(
    ease(frame, 0, 1, 202, 215),
    ease(frame, 1, 0, 360, 372)
  );

  // ======================================================
  // SECTION 4: STEP 3 — WIN + FINDER (375-530)
  // ======================================================
  const step3Visible = frame >= 375 && frame < 538;
  const step3Op = Math.min(
    ease(frame, 0, 1, 375, 388),
    ease(frame, 1, 0, 525, 538)
  );

  const badge3Scale = spring({
    frame: Math.max(0, frame - 378),
    fps,
    config: { damping: 10, stiffness: 200 },
  });

  // Checkmark burst (375-420)
  const checkScale = spring({
    frame: Math.max(0, frame - 380),
    fps,
    config: { damping: 7, stiffness: 140 },
  });
  const checkOp = Math.min(
    ease(frame, 0, 1, 378, 386),
    ease(frame, 1, 0, 414, 424)
  );
  const doneTextScale = spring({
    frame: Math.max(0, frame - 390),
    fps,
    config: { damping: 10, stiffness: 200 },
  });

  // Finder window (420-530)
  const finderScale = spring({
    frame: Math.max(0, frame - 422),
    fps,
    config: { damping: 12, stiffness: 150 },
  });
  const finderOp = Math.min(
    ease(frame, 0, 1, 420, 432),
    ease(frame, 1, 0, 523, 536)
  );

  // .md file springs in
  const mdScale = spring({
    frame: Math.max(0, frame - 450),
    fps,
    config: { damping: 10, stiffness: 180 },
  });
  const mdOp = ease(frame, 0, 1, 450, 460);
  const mdGlow =
    frame >= 450 && frame < 495
      ? interpolate(frame, [450, 465, 495], [0, 1, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        })
      : 0;

  const finderFiles: FinderFileItem[] = [
    {
      name: "interview_2025-02-11.mp4",
      icon: "\uD83C\uDFA5",
      size: "127 МБ",
      dateModified: "11 фев, 14:30",
      kind: "MP4",
    },
    {
      name: "notes_standup.txt",
      icon: "\uD83D\uDCC4",
      size: "4 КБ",
      dateModified: "10 фев, 09:15",
      kind: "Текст",
    },
    {
      name: "interview_2025-02-11.md",
      icon: "\uD83D\uDCDD",
      size: "24 КБ",
      dateModified: "11 фев, 14:31",
      kind: "Markdown",
      opacity: mdOp,
      scale: mdScale,
      glowColor: mdGlow > 0 ? C.teal : undefined,
    },
  ];

  const finderCaptionOp = ease(frame, 0, 1, 465, 480);

  // ======================================================
  // SECTION 5: BONUS — HISTORY (535-600)
  // ======================================================
  const histVisible = frame >= 535 && frame < 608;
  const histOp = Math.min(
    ease(frame, 0, 1, 535, 548),
    ease(frame, 1, 0, 595, 608)
  );
  const histScale = spring({
    frame: Math.max(0, frame - 538),
    fps,
    config: { damping: 12, stiffness: 180 },
  });

  // ======================================================
  // SECTION 6: BONUS — SETTINGS (605-658)
  // ======================================================
  const settVisible = frame >= 605 && frame < 665;
  const settOp = Math.min(
    ease(frame, 0, 1, 605, 618),
    ease(frame, 1, 0, 652, 665)
  );
  const settScale = spring({
    frame: Math.max(0, frame - 608),
    fps,
    config: { damping: 12, stiffness: 180 },
  });

  // ======================================================
  // SECTION 7: OUTRO (662-810)
  // ======================================================
  const outroOp = ease(frame, 0, 1, 665, 685);
  const sparkleOutroScale = spring({
    frame: Math.max(0, frame - 668),
    fps,
    config: { damping: 8, stiffness: 100 },
  });
  const titleOutroScale = spring({
    frame: Math.max(0, frame - 678),
    fps,
    config: { damping: 9, stiffness: 150 },
  });

  // Particle burst for outro
  const particles = Array.from({ length: 12 }, (_, i) => {
    const angle = (i / 12) * Math.PI * 2;
    const dist = spring({
      frame: Math.max(0, frame - 672 - (i % 3)),
      fps,
      config: { damping: 20, stiffness: 80 },
    });
    return {
      x: Math.cos(angle) * dist * 100,
      y: Math.sin(angle) * dist * 100,
      opacity: Math.max(0, 1 - dist * 1.3),
      size: 3 + (i % 3) * 2,
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
      {/* ========== ANIMATED MESH BACKGROUND ========== */}
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

      {/* ========== FLASH OVERLAYS ========== */}
      {flash1 > 0 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: C.teal,
            opacity: flash1,
            zIndex: 200,
            pointerEvents: "none",
          }}
        />
      )}
      {flash2 > 0 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: C.appGreen,
            opacity: flash2,
            zIndex: 200,
            pointerEvents: "none",
          }}
        />
      )}
      {flash3 > 0 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: C.teal,
            opacity: flash3,
            zIndex: 200,
            pointerEvents: "none",
          }}
        />
      )}

      {/* ========== INTRO ========== */}
      {frame < 56 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: introOp,
            transform: `scale(${introScale})`,
          }}
        >
          <div
            style={{
              fontSize: 72,
              fontWeight: 800,
              color: C.text,
              letterSpacing: -3,
              marginBottom: 16,
            }}
          >
            Как работает Traart
          </div>
          <div
            style={{
              fontSize: 28,
              color: C.textMuted,
              opacity: ease(frame, 0, 1, 18, 32),
            }}
          >
            Транскрибация за 3 шага
          </div>
        </div>
      )}

      {/* ========== STEP 1: MENU BAR + DROPDOWN ========== */}
      {step1Visible && (
        <div style={{ position: "absolute", inset: 0, opacity: step1Op }}>
          {/* Step badge */}
          <div
            style={{
              position: "absolute",
              top: 40,
              left: 80,
              transform: `scale(${badge1Scale})`,
              display: "flex",
              alignItems: "center",
              gap: 12,
            }}
          >
            <div
              style={{
                width: 38,
                height: 38,
                borderRadius: "50%",
                background: C.accent,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontSize: 18,
                fontWeight: 800,
                color: "#fff",
                boxShadow: `0 0 20px ${C.accent}50`,
              }}
            >
              1
            </div>
            <div style={{ fontSize: 22, fontWeight: 700, color: C.text }}>
              Живёт в menu bar
            </div>
          </div>

          {/* Menu bar drops from top */}
          <div
            style={{
              position: "absolute",
              top: interpolate(menuBarDrop, [0, 1], [-80, 130]),
              left: "50%",
              transform: "translateX(-50%)",
              opacity: menuBarDrop,
              zIndex: 20,
            }}
          >
            <MacMenuBar
              scale={S}
              traartContent={
                <div
                  style={{
                    position: "absolute",
                    left: 16 * S,
                    top: 0,
                    bottom: 0,
                    display: "flex",
                    alignItems: "center",
                    gap: 4 * S,
                  }}
                >
                  <TraartMenuBarIcon state="idle" scale={S} />
                </div>
              }
            />

            {/* Dropdown with scanning highlights */}
            {dropdownOp > 0 && (
              <div
                style={{
                  position: "absolute",
                  top: 34 * S,
                  left: 4 * S,
                  opacity: dropdownOp,
                  transform: `scaleY(${dropdownSpring}) scaleX(${0.5 + dropdownSpring * 0.5})`,
                  transformOrigin: "top left",
                  zIndex: 30,
                }}
              >
                <MacMenu width={310} scale={S}>
                  <MenuTitle
                    label="Traart"
                    subtitle="Статус: Готово"
                    scale={S}
                    rightIcon={
                      <div
                        style={{
                          width: 28 * S,
                          height: 28 * S,
                          borderRadius: "50%",
                          background: `linear-gradient(135deg, ${C.accent}, ${C.accentGlow})`,
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          fontSize: 14 * S,
                          fontWeight: 700,
                          color: "white",
                        }}
                      >
                        A
                      </div>
                    }
                  />
                  <MenuSeparator scale={S} />
                  <MenuItem
                    label="Копировать последнюю транскрипцию"
                    shortcut="⇧⌘C"
                    bold
                    highlighted={hlCopy}
                    scale={S}
                  />
                  <MenuItem
                    label="Транскрибировать файл..."
                    shortcut="⌘O"
                    highlighted={hlTranscribe}
                    scale={S}
                  />
                  <MenuSeparator scale={S} />
                  <MenuItem
                    label="Новые файлы"
                    hasSubmenu
                    highlighted={hlNewFiles}
                    scale={S}
                  />
                  <MenuItem
                    label="История"
                    hasSubmenu
                    highlighted={hlHistory}
                    scale={S}
                  />
                  <MenuItem
                    label="Открыть папку транскрипций"
                    shortcut="⇧⌘O"
                    scale={S}
                  />
                  <MenuSeparator scale={S} />
                  <MenuItem
                    label="Настройки"
                    hasSubmenu
                    highlighted={hlSettings}
                    scale={S}
                  />
                  <MenuSeparator scale={S} />
                  <MenuItem label="О программе" scale={S} />
                  <MenuItem label="Выход" shortcut="⌘Q" scale={S} />
                </MacMenu>
              </div>
            )}
          </div>

          {/* Bottom caption */}
          <div
            style={{
              position: "absolute",
              bottom: 60,
              left: 0,
              right: 0,
              textAlign: "center",
              opacity: step1CaptionOp,
            }}
          >
            <div style={{ fontSize: 20, color: C.textMuted }}>
              Traart работает в фоне и следит за новыми записями
            </div>
          </div>
        </div>
      )}

      {/* ========== STEP 2: PROGRESS ========== */}
      {step2Visible && (
        <div style={{ position: "absolute", inset: 0, opacity: step2Op }}>
          {/* Step badge */}
          <div
            style={{
              position: "absolute",
              top: 40,
              left: 80,
              transform: `scale(${badge2Scale})`,
              display: "flex",
              alignItems: "center",
              gap: 12,
            }}
          >
            <div
              style={{
                width: 38,
                height: 38,
                borderRadius: "50%",
                background: C.teal,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontSize: 18,
                fontWeight: 800,
                color: "#fff",
                boxShadow: `0 0 20px ${C.teal}50`,
              }}
            >
              2
            </div>
            <div style={{ fontSize: 22, fontWeight: 700, color: C.text }}>
              Автоматическая транскрибация
            </div>
          </div>

          {/* Menu bar with progress icon */}
          <div
            style={{
              position: "absolute",
              top: interpolate(menuBar2Drop, [0, 1], [-80, 130]),
              left: "50%",
              transform: "translateX(-50%)",
              opacity: menuBar2Drop,
              zIndex: 20,
            }}
          >
            <MacMenuBar
              scale={S}
              traartContent={
                <div
                  style={{
                    position: "absolute",
                    left: 16 * S,
                    top: 0,
                    bottom: 0,
                    display: "flex",
                    alignItems: "center",
                    gap: 4 * S,
                  }}
                >
                  <TraartMenuBarIcon
                    state={iconState}
                    progress={progressValue}
                    scale={S}
                  />
                </div>
              }
            />
          </div>

          {/* Center: Progress ring + info */}
          <div
            style={{
              position: "absolute",
              top: 310,
              left: "50%",
              transform: "translateX(-50%)",
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: 24,
            }}
          >
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 36,
                transform: `scale(${ringScale})`,
              }}
            >
              {/* Progress ring */}
              <svg width={130} height={130} viewBox="0 0 130 130">
                <circle
                  cx="65"
                  cy="65"
                  r="55"
                  stroke="rgba(108,92,231,0.15)"
                  strokeWidth="8"
                  fill="none"
                />
                <circle
                  cx="65"
                  cy="65"
                  r="55"
                  stroke={C.teal}
                  strokeWidth="8"
                  fill="none"
                  strokeDasharray={`${(progressValue / 100) * 345.58} 345.58`}
                  strokeLinecap="round"
                  transform="rotate(-90 65 65)"
                />
                <text
                  x="65"
                  y="70"
                  textAnchor="middle"
                  fill="white"
                  fontSize="30"
                  fontWeight="700"
                  fontFamily="-apple-system, sans-serif"
                >
                  {Math.round(progressValue)}%
                </text>
              </svg>

              {/* Step info */}
              <div>
                <div
                  style={{
                    fontSize: 22,
                    fontWeight: 600,
                    color: C.text,
                    marginBottom: 8,
                  }}
                >
                  {progressValue < 25
                    ? "Загрузка модели..."
                    : progressValue < 70
                    ? "Транскрибация..."
                    : "Финализация..."}
                </div>
                <div
                  style={{
                    fontSize: 16,
                    color: C.textMuted,
                    marginBottom: 12,
                  }}
                >
                  meeting_2025-02-11.mp4
                </div>
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                  }}
                >
                  <TraartSparkleIcon
                    state="transcribing"
                    progress={progressValue / 100}
                    size={22}
                  />
                  <span
                    style={{
                      fontSize: 14,
                      color: C.teal,
                      fontWeight: 500,
                    }}
                  >
                    GigaAM v3
                  </span>
                </div>
              </div>
            </div>

            {/* Typewriter preview */}
            {typeChars > 0 && (
              <div
                style={{
                  maxWidth: 560,
                  padding: "14px 20px",
                  borderRadius: 12,
                  background: "rgba(255,255,255,0.05)",
                  border: `1px solid ${C.teal}15`,
                  fontSize: 15,
                  color: C.textMuted,
                  lineHeight: 1.6,
                  opacity: ease(frame, 0, 1, 257, 268),
                }}
              >
                <span
                  style={{
                    color: C.teal,
                    fontSize: 12,
                    fontWeight: 600,
                  }}
                >
                  Спикер 1:{" "}
                </span>
                {previewVisible}
                <span
                  style={{
                    display: "inline-block",
                    width: 2,
                    height: 16,
                    background: C.teal,
                    marginLeft: 1,
                    verticalAlign: "middle",
                    opacity: Math.sin(frame * 0.35) > 0 ? 1 : 0,
                  }}
                />
              </div>
            )}
          </div>

          {/* Bottom caption */}
          <div
            style={{
              position: "absolute",
              bottom: 60,
              left: 0,
              right: 0,
              textAlign: "center",
              opacity: step2CaptionOp,
            }}
          >
            <div style={{ fontSize: 20, color: C.textMuted }}>
              GigaAM v3 — лучшее распознавание русской речи (WER 8.3%)
            </div>
          </div>
        </div>
      )}

      {/* ========== STEP 3: WIN + FINDER ========== */}
      {step3Visible && (
        <div style={{ position: "absolute", inset: 0, opacity: step3Op }}>
          {/* Step badge */}
          <div
            style={{
              position: "absolute",
              top: 40,
              left: 80,
              transform: `scale(${badge3Scale})`,
              display: "flex",
              alignItems: "center",
              gap: 12,
              zIndex: 10,
            }}
          >
            <div
              style={{
                width: 38,
                height: 38,
                borderRadius: "50%",
                background: C.appGreen,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontSize: 18,
                fontWeight: 800,
                color: "#fff",
                boxShadow: `0 0 20px ${C.appGreen}50`,
              }}
            >
              3
            </div>
            <div style={{ fontSize: 22, fontWeight: 700, color: C.text }}>
              Результат готов
            </div>
          </div>

          {/* Checkmark burst (brief, before Finder) */}
          {checkOp > 0 && (
            <div
              style={{
                position: "absolute",
                inset: 0,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                opacity: checkOp,
              }}
            >
              <div style={{ transform: `scale(${checkScale})` }}>
                <svg width={110} height={110} viewBox="0 0 110 110">
                  <circle cx="55" cy="55" r="50" fill={C.appGreen} />
                  <path
                    d="M32 55 L48 71 L78 41"
                    stroke="white"
                    strokeWidth="6"
                    fill="none"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </div>
              <div
                style={{
                  fontSize: 36,
                  fontWeight: 800,
                  color: C.teal,
                  marginTop: 16,
                  transform: `scale(${doneTextScale})`,
                  textShadow: `0 0 30px ${C.teal}40`,
                }}
              >
                Готово за 38 секунд!
              </div>
            </div>
          )}

          {/* Finder window appears after checkmark */}
          {finderOp > 0 && (
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
              <div
                style={{
                  transform: `scale(${finderScale})`,
                  transformOrigin: "center center",
                }}
              >
                <FinderWindow
                  title="Interviews"
                  files={finderFiles}
                  width={700}
                />
              </div>

              {/* Caption below Finder */}
              <div
                style={{
                  marginTop: 24,
                  textAlign: "center",
                  opacity: finderCaptionOp,
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
                      fontSize: 18,
                      fontWeight: 600,
                      color: C.teal,
                    }}
                  >
                    Транскрипция — рядом с оригиналом
                  </span>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* ========== BONUS: HISTORY ========== */}
      {histVisible && (
        <div style={{ position: "absolute", inset: 0, opacity: histOp }}>
          {/* Title */}
          <div
            style={{
              position: "absolute",
              top: 40,
              left: 80,
              display: "flex",
              alignItems: "center",
              gap: 12,
              transform: `scale(${histScale})`,
            }}
          >
            <div style={{ fontSize: 22, fontWeight: 700, color: C.text }}>
              &#128203; Вся история под рукой
            </div>
          </div>

          {/* MacMenuBarMockup showing history */}
          <div
            style={{
              position: "absolute",
              top: 110,
              left: "50%",
              transform: `translateX(-50%) scale(${histScale})`,
              transformOrigin: "top center",
              zIndex: 20,
            }}
          >
            <MacMenuBarMockup
              scale={1.5}
              iconState="completed"
              menuOpacity={1}
              activeSubmenu="history"
              highlightedItem="history"
              statusText="Готово"
            />
          </div>

          {/* Caption */}
          <div
            style={{
              position: "absolute",
              bottom: 60,
              left: 0,
              right: 0,
              textAlign: "center",
              opacity: ease(frame, 0, 1, 545, 558),
            }}
          >
            <div style={{ fontSize: 20, color: C.textMuted }}>
              Открыть, скопировать, транскрибировать заново — в один клик
            </div>
          </div>
        </div>
      )}

      {/* ========== BONUS: SETTINGS ========== */}
      {settVisible && (
        <div style={{ position: "absolute", inset: 0, opacity: settOp }}>
          {/* Title */}
          <div
            style={{
              position: "absolute",
              top: 40,
              left: 80,
              display: "flex",
              alignItems: "center",
              gap: 12,
              transform: `scale(${settScale})`,
            }}
          >
            <div style={{ fontSize: 22, fontWeight: 700, color: C.text }}>
              &#9881;&#65039; Гибкие настройки
            </div>
          </div>

          {/* MacMenuBarMockup showing settings */}
          <div
            style={{
              position: "absolute",
              top: 110,
              left: "50%",
              transform: `translateX(-50%) scale(${settScale})`,
              transformOrigin: "top center",
              zIndex: 20,
            }}
          >
            <MacMenuBarMockup
              scale={1.5}
              iconState="completed"
              menuOpacity={1}
              activeSubmenu="settings"
              highlightedItem="settings"
              statusText="Готово"
            />
          </div>

          {/* Caption */}
          <div
            style={{
              position: "absolute",
              bottom: 60,
              left: 0,
              right: 0,
              textAlign: "center",
              opacity: ease(frame, 0, 1, 615, 628),
            }}
          >
            <div style={{ fontSize: 20, color: C.textMuted }}>
              Качество, диаризация, формат — всё настраивается
            </div>
          </div>
        </div>
      )}

      {/* ========== OUTRO ========== */}
      {frame >= 662 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: outroOp,
          }}
        >
          {/* Particles */}
          {particles.map((p, i) => (
            <div
              key={i}
              style={{
                position: "absolute",
                left: "50%",
                top: "35%",
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
          <div
            style={{
              transform: `scale(${sparkleOutroScale})`,
              marginBottom: 20,
            }}
          >
            <TraartSparkleIcon state="completed" size={72} />
          </div>

          {/* Title */}
          <div
            style={{
              fontSize: 76,
              fontWeight: 900,
              color: C.text,
              letterSpacing: -3,
              marginBottom: 12,
              transform: `scale(${titleOutroScale})`,
            }}
          >
            Traart
          </div>

          {/* Subtitle */}
          <div
            style={{
              fontSize: 24,
              color: C.textMuted,
              textAlign: "center",
              marginBottom: 28,
              lineHeight: 1.5,
              opacity: ease(frame, 0, 1, 690, 708),
            }}
          >
            Лучшая транскрибация русской речи.
            <br />
            Локально. Бесплатно. Без компромиссов.
          </div>

          {/* Feature pills with staggered springs */}
          <div style={{ display: "flex", gap: 14, marginBottom: 32 }}>
            {["100% оффлайн", "WER 8.3%", "Диаризация", "macOS"].map(
              (label, i) => {
                const pillScale = spring({
                  frame: Math.max(0, frame - 712 - i * 6),
                  fps,
                  config: { damping: 10, stiffness: 200 },
                });
                return (
                  <div
                    key={label}
                    style={{
                      padding: "10px 24px",
                      borderRadius: 30,
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

          {/* URL */}
          <div
            style={{
              fontSize: 22,
              fontWeight: 700,
              color: C.teal,
              opacity: ease(frame, 0, 1, 755, 785),
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
