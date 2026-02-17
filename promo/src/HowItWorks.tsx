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
import { CheckboxItem } from "./components/mac-menubar/CheckboxItem";
import { HistoryEntry } from "./components/mac-menubar/HistoryEntry";
import { SettingsSubmenu } from "./components/mac-menubar/SettingsSubmenu";
import { TraartSparkleIcon } from "./components/mac-menubar/TraartSparkleIcon";
import { Caption } from "./components/ui/Caption";
import { StepBadge } from "./components/ui/StepBadge";
import { Background } from "./components/ui/Background";

// ============================================================
// Traart Icon in menu bar (with percentage for progress state)
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
          marginRight: 6 * scale,
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
    const pct = Math.round(progress);
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
        {pct}%
      </span>
    );
  }

  // done
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
// Main Composition — 20 sec @ 30fps = 600 frames
// ============================================================
export const HowItWorks: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // TIMELINE at 30fps:
  // 0–90:    Title "Как работает Traart"
  // 95–210:  Step 1 — menu bar idle → menu opens
  // 210–340: Step 2 — progress 0% → 100%
  // 340–420: Step 3 — completed checkmark
  // 420–495: Bonus — history submenu
  // 495–560: Bonus — settings submenu
  // 555–600: Outro

  // Background hue shift
  const bgHue = interpolate(frame, [0, 600], [240, 280], {
    extrapolateRight: "clamp",
  });

  // UI scale for the macOS components (make them big enough to see)
  const S = 2.0;

  // === Step 2 animated progress ===
  const progressValue = interpolate(
    frame,
    [225, 260, 280, 310, 325],
    [0, 15, 30, 65, 100],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  // === Menu open animation (Step 1) ===
  const menuOpenOpacity = Math.min(
    ease(frame, 0, 1, 145, 160),
    ease(frame, 1, 0, 195, 210)
  );

  // === History menu animation ===
  const historyMenuOpacity = Math.min(
    ease(frame, 0, 1, 425, 440),
    ease(frame, 1, 0, 485, 498)
  );

  // === Settings menu animation ===
  const settingsMenuOpacity = Math.min(
    ease(frame, 0, 1, 498, 513),
    ease(frame, 1, 0, 548, 560)
  );

  // === Determine menu bar icon state ===
  let iconState: "idle" | "progress" | "done" = "idle";
  if (frame >= 220 && frame < 330) iconState = "progress";
  if (frame >= 330 && frame < 420) iconState = "done";

  // === Menu bar visibility ===
  const menuBarOpacity = Math.min(
    ease(frame, 0, 1, 100, 115),
    ease(frame, 1, 0, 550, 565)
  );

  return (
    <AbsoluteFill
      style={{
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", sans-serif',
        overflow: "hidden",
      }}
    >
      {/* Animated background */}
      <Background hue={bgHue} />

      {/* ============================================ */}
      {/* INTRO: Title */}
      {/* ============================================ */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          opacity: Math.min(
            ease(frame, 0, 1, 5, 30),
            ease(frame, 1, 0, 80, 100)
          ),
          transform: `translateY(${ease(frame, 10, 0, 5, 30)}px)`,
          zIndex: 10,
        }}
      >
        <div
          style={{
            fontSize: 68,
            fontWeight: 800,
            color: C.text,
            letterSpacing: -2,
            marginBottom: 16,
          }}
        >
          Как работает Traart
        </div>
        <div style={{ fontSize: 26, color: C.textMuted }}>
          Транскрибация за 3 шага
        </div>
      </div>

      {/* ============================================ */}
      {/* macOS MENU BAR (persistent across steps) */}
      {/* ============================================ */}
      <div
        style={{
          position: "absolute",
          top: 180,
          left: "50%",
          transform: "translateX(-50%)",
          opacity: menuBarOpacity,
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

        {/* ============================================ */}
        {/* STEP 1: Dropdown menu (main menu) */}
        {/* ============================================ */}
        {menuOpenOpacity > 0 && (
          <div
            style={{
              position: "absolute",
              top: 34 * S,
              left: 4 * S,
              opacity: menuOpenOpacity,
              transform: `translateY(${(1 - menuOpenOpacity) * -8}px)`,
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
                scale={S}
              />
              <MenuItem
                label="Транскрибировать файл..."
                shortcut="⌘O"
                scale={S}
              />
              <MenuSeparator scale={S} />
              <MenuItem label="Новые файлы" hasSubmenu scale={S} />
              <MenuItem label="История" hasSubmenu scale={S} />
              <MenuItem
                label="Открыть папку транскрипций"
                shortcut="⇧⌘O"
                scale={S}
              />
              <MenuSeparator scale={S} />
              <MenuItem label="Настройки" hasSubmenu scale={S} />
              <MenuSeparator scale={S} />
              <MenuItem label="О программе" scale={S} />
              <MenuItem label="Выход" shortcut="⌘Q" scale={S} />
            </MacMenu>
          </div>
        )}

        {/* ============================================ */}
        {/* BONUS: History submenu */}
        {/* ============================================ */}
        {historyMenuOpacity > 0 && (
          <div
            style={{
              position: "absolute",
              top: 34 * S,
              left: 4 * S,
              display: "flex",
              gap: 4 * S,
              opacity: historyMenuOpacity,
              transform: `translateY(${(1 - historyMenuOpacity) * -8}px)`,
              zIndex: 30,
            }}
          >
            {/* Main menu with History highlighted */}
            <MacMenu width={310} scale={S}>
              <MenuTitle label="Traart" subtitle="Статус: Готово" scale={S} />
              <MenuSeparator scale={S} />
              <MenuItem
                label="Копировать последнюю транскрипцию"
                shortcut="⇧⌘C"
                bold
                scale={S}
              />
              <MenuItem
                label="Транскрибировать файл..."
                shortcut="⌘O"
                scale={S}
              />
              <MenuSeparator scale={S} />
              <MenuItem label="Новые файлы" hasSubmenu scale={S} />
              <MenuItem label="История" hasSubmenu highlighted scale={S} />
              <MenuItem
                label="Открыть папку транскрипций"
                shortcut="⇧⌘O"
                scale={S}
              />
              <MenuSeparator scale={S} />
              <MenuItem label="Настройки" hasSubmenu scale={S} />
              <MenuSeparator scale={S} />
              <MenuItem label="О программе" scale={S} />
              <MenuItem label="Выход" shortcut="⌘Q" scale={S} />
            </MacMenu>

            {/* History submenu */}
            <MacMenu width={300} scale={S}>
              <HistoryEntry
                name="meeting_2025-02-11.mp4"
                duration="40с"
                status="done"
                scale={S}
              />
              <HistoryEntry
                name="audio_recording.m4a"
                duration="38с"
                status="done"
                highlighted
                scale={S}
              />
              <HistoryEntry
                name="interview_final.m4a"
                duration="3м 29с"
                status="done"
                scale={S}
              />
              <HistoryEntry
                name="podcast_ep12.mp4"
                duration="2м 38с"
                status="done"
                scale={S}
              />
              <MenuSeparator scale={S} />
              <MenuItem label="Очистить историю" scale={S} />
            </MacMenu>
          </div>
        )}

        {/* ============================================ */}
        {/* BONUS: Settings submenu */}
        {/* ============================================ */}
        {settingsMenuOpacity > 0 && (
          <div
            style={{
              position: "absolute",
              top: 34 * S,
              left: 4 * S,
              display: "flex",
              gap: 4 * S,
              opacity: settingsMenuOpacity,
              transform: `translateY(${(1 - settingsMenuOpacity) * -8}px)`,
              zIndex: 30,
            }}
          >
            {/* Main menu with Settings highlighted */}
            <MacMenu width={310} scale={S}>
              <MenuTitle label="Traart" subtitle="Статус: Готово" scale={S} />
              <MenuSeparator scale={S} />
              <MenuItem
                label="Копировать последнюю транскрипцию"
                shortcut="⇧⌘C"
                bold
                scale={S}
              />
              <MenuItem
                label="Транскрибировать файл..."
                shortcut="⌘O"
                scale={S}
              />
              <MenuSeparator scale={S} />
              <MenuItem label="Новые файлы" hasSubmenu scale={S} />
              <MenuItem label="История" hasSubmenu scale={S} />
              <MenuItem
                label="Открыть папку транскрипций"
                shortcut="⇧⌘O"
                scale={S}
              />
              <MenuSeparator scale={S} />
              <MenuItem label="Настройки" hasSubmenu highlighted scale={S} />
              <MenuSeparator scale={S} />
              <MenuItem label="О программе" scale={S} />
              <MenuItem label="Выход" shortcut="⌘Q" scale={S} />
            </MacMenu>

            {/* Settings submenu */}
            <SettingsSubmenu scale={S} />
          </div>
        )}
      </div>

      {/* ============================================ */}
      {/* STEP 1 caption */}
      {/* ============================================ */}
      <StepBadge step={1} frame={frame} enterFrame={100} exitFrame={210} />
      <Caption
        text="Работает в фоне"
        subtitle="Traart живёт в menu bar и следит за новыми записями"
        frame={frame}
        enterFrame={105}
        exitFrame={210}
        position="bottom"
      />

      {/* ============================================ */}
      {/* STEP 2 caption — progress */}
      {/* ============================================ */}
      <StepBadge step={2} frame={frame} enterFrame={215} exitFrame={340} />
      <Caption
        text="Автоматическая транскрибация"
        subtitle="GigaAM v3 — лучшее распознавание русской речи"
        frame={frame}
        enterFrame={218}
        exitFrame={340}
        position="bottom"
      />

      {/* Animated progress bar (center, below menu bar) */}
      {frame >= 220 && frame < 340 && (
        <div
          style={{
            position: "absolute",
            top: 420,
            left: "50%",
            transform: "translateX(-50%)",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 20,
            opacity: Math.min(
              ease(frame, 0, 1, 220, 235),
              ease(frame, 1, 0, 325, 340)
            ),
            zIndex: 25,
          }}
        >
          {/* Large progress display */}
          <div style={{ display: "flex", alignItems: "center", gap: 30 }}>
            <svg width={120} height={120} viewBox="0 0 120 120">
              <circle
                cx="60"
                cy="60"
                r="50"
                stroke="rgba(108,92,231,0.15)"
                strokeWidth="8"
                fill="none"
              />
              <circle
                cx="60"
                cy="60"
                r="50"
                stroke={C.accent}
                strokeWidth="8"
                fill="none"
                strokeDasharray={`${(progressValue / 100) * 314.16} 314.16`}
                strokeLinecap="round"
                transform="rotate(-90 60 60)"
              />
              <text
                x="60"
                y="65"
                textAnchor="middle"
                fill="white"
                fontSize="28"
                fontWeight="700"
                fontFamily="-apple-system, sans-serif"
              >
                {Math.round(progressValue)}%
              </text>
            </svg>

            <div style={{ color: "white" }}>
              <div style={{ fontSize: 22, fontWeight: 600, marginBottom: 6 }}>
                {progressValue < 30
                  ? "Загрузка модели..."
                  : progressValue < 70
                  ? "Транскрибация..."
                  : "Финализация..."}
              </div>
              <div style={{ fontSize: 16, color: C.textMuted }}>
                meeting_2025-02-11.mp4
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ============================================ */}
      {/* STEP 3 caption — completed */}
      {/* ============================================ */}
      <StepBadge step={3} frame={frame} enterFrame={340} exitFrame={420} />
      <Caption
        text="Готово!"
        subtitle="Результат появляется рядом с оригиналом"
        frame={frame}
        enterFrame={343}
        exitFrame={420}
        position="bottom"
      />

      {/* Completed notification */}
      {frame >= 340 && frame < 420 && (
        <div
          style={{
            position: "absolute",
            top: 420,
            left: "50%",
            transform: "translateX(-50%)",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 16,
            opacity: Math.min(
              ease(frame, 0, 1, 342, 358),
              ease(frame, 1, 0, 405, 420)
            ),
            zIndex: 25,
          }}
        >
          {/* Checkmark animation */}
          <div
            style={{
              transform: `scale(${spring({
                frame: Math.max(0, frame - 345),
                fps,
                config: { damping: 8, stiffness: 120 },
              })})`,
            }}
          >
            <svg width={100} height={100} viewBox="0 0 100 100">
              <circle cx="50" cy="50" r="45" fill={C.checkGreen} />
              <path
                d="M30 50 L44 64 L70 38"
                stroke="white"
                strokeWidth="6"
                fill="none"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </div>

          {/* File info */}
          <div
            style={{
              background: "rgba(255,255,255,0.08)",
              borderRadius: 12,
              padding: "16px 28px",
              border: "1px solid rgba(255,255,255,0.1)",
              display: "flex",
              alignItems: "center",
              gap: 16,
            }}
          >
            <div style={{ fontSize: 28 }}>&#128196;</div>
            <div>
              <div
                style={{
                  fontSize: 17,
                  fontWeight: 600,
                  color: "white",
                  marginBottom: 4,
                }}
              >
                meeting_2025-02-11.md
              </div>
              <div style={{ fontSize: 14, color: C.textMuted }}>
                Создан рядом с оригиналом
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ============================================ */}
      {/* BONUS captions */}
      {/* ============================================ */}
      <Caption
        text="Вся история под рукой"
        subtitle="Открыть, скопировать, транскрибировать заново — в один клик"
        frame={frame}
        enterFrame={425}
        exitFrame={498}
        position="bottom"
      />

      <Caption
        text="Гибкие настройки"
        subtitle="Качество, диаризация, формат — всё настраивается"
        frame={frame}
        enterFrame={500}
        exitFrame={558}
        position="bottom"
      />

      {/* ============================================ */}
      {/* OUTRO */}
      {/* ============================================ */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          opacity: ease(frame, 0, 1, 558, 578),
          transform: `translateY(${ease(frame, 15, 0, 558, 578)}px)`,
          zIndex: 50,
        }}
      >
        <div
          style={{
            fontSize: 76,
            fontWeight: 800,
            color: C.text,
            letterSpacing: -2,
            marginBottom: 16,
          }}
        >
          Traart
        </div>

        <div
          style={{
            fontSize: 24,
            color: C.textMuted,
            textAlign: "center",
            marginBottom: 32,
            lineHeight: 1.5,
          }}
        >
          Лучшая транскрибация русской речи.
          <br />
          Локально. Бесплатно. Без компромиссов.
        </div>

        {/* Feature pills */}
        <div style={{ display: "flex", gap: 16 }}>
          {["100% оффлайн", "WER 8.3%", "Диаризация", "macOS"].map(
            (label, i) => (
              <div
                key={label}
                style={{
                  padding: "10px 24px",
                  borderRadius: 30,
                  background: "rgba(108,92,231,0.12)",
                  border: "1px solid rgba(108,92,231,0.25)",
                  color: C.accentGlow,
                  fontSize: 16,
                  fontWeight: 600,
                  opacity: ease(frame, 0, 1, 572 + i * 5, 585 + i * 5),
                }}
              >
                {label}
              </div>
            )
          )}
        </div>

        <div
          style={{
            marginTop: 32,
            fontSize: 20,
            color: C.accent,
            fontWeight: 600,
            opacity: ease(frame, 0, 1, 590, 600),
          }}
        >
          traart.app
        </div>
      </div>
    </AbsoluteFill>
  );
};
