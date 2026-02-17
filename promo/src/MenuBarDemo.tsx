import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  interpolate,
} from "remotion";
import { C } from "./shared/colors";
import { ease } from "./shared/animation";
import { MacMenuBarMockup } from "./components/mac-menubar/MacMenuBarMockup";
import { Background } from "./components/ui/Background";
import type { SparkleState } from "./components/mac-menubar/TraartSparkleIcon";

/**
 * MenuBarDemo — 1200x630, 300 frames @ 30fps (10 sec)
 *
 * Timeline:
 *   0–30:   Fade in, idle state, menu closed
 *  30–90:   Menu opens, idle sparkle icon
 *  90–180:  Transcription in progress (sparkle fills, progress bar)
 * 180–210:  Completed state (green sparkle)
 * 210–240:  History submenu
 * 240–270:  Settings submenu
 * 270–300:  Fade out
 */
export const MenuBarDemo: React.FC = () => {
  const frame = useCurrentFrame();

  const bgHue = interpolate(frame, [0, 300], [240, 270], {
    extrapolateRight: "clamp",
  });

  const S = 1.6;

  // Icon state
  let iconState: SparkleState = "idle";
  let iconProgress = 0;
  if (frame >= 90 && frame < 180) {
    iconState = "transcribing";
    iconProgress = interpolate(frame, [90, 175], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
  } else if (frame >= 180 && frame < 210) {
    iconState = "completed";
  }

  // Menu visibility
  const menuOpacity = Math.min(
    ease(frame, 0, 1, 28, 40),
    ease(frame, 1, 0, 268, 280)
  );

  // Progress bar
  const showProgressBar = frame >= 90 && frame < 180;
  const progressValue = interpolate(frame, [90, 175], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const progressStep =
    progressValue < 0.2
      ? "Загрузка модели"
      : progressValue < 0.7
      ? "Транскрибация"
      : "Финализация";

  const progressEta =
    progressValue < 0.3
      ? "~2м 15с"
      : progressValue < 0.7
      ? "~1м 20с"
      : "~15с";

  // Active submenu
  let activeSubmenu: "none" | "history" | "settings" = "none";
  let highlightedItem: string | undefined;

  if (frame >= 210 && frame < 240) {
    activeSubmenu = "history";
    highlightedItem = "history";
  } else if (frame >= 240 && frame < 270) {
    activeSubmenu = "settings";
    highlightedItem = "settings";
  }

  // Status text
  const statusText =
    iconState === "transcribing"
      ? "Транскрибация..."
      : iconState === "completed"
      ? "Готово"
      : "Готово";

  // Overall fade
  const overallOpacity = Math.min(
    ease(frame, 0, 1, 0, 20),
    ease(frame, 1, 0, 280, 300)
  );

  // Title
  const titleOpacity = Math.min(
    ease(frame, 0, 1, 5, 20),
    ease(frame, 1, 0, 280, 295)
  );

  return (
    <AbsoluteFill
      style={{
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", sans-serif',
        overflow: "hidden",
      }}
    >
      <Background hue={bgHue} />

      {/* Title */}
      <div
        style={{
          position: "absolute",
          top: 24,
          left: 0,
          right: 0,
          textAlign: "center",
          opacity: titleOpacity,
          zIndex: 5,
        }}
      >
        <div
          style={{
            fontSize: 28,
            fontWeight: 700,
            color: C.text,
            letterSpacing: -0.5,
          }}
        >
          Traart Menu Bar
        </div>
        <div style={{ fontSize: 15, color: C.textMuted, marginTop: 4 }}>
          {iconState === "transcribing"
            ? "Транскрибация в процессе..."
            : iconState === "completed"
            ? "Транскрибация завершена"
            : activeSubmenu === "history"
            ? "История транскрибаций"
            : activeSubmenu === "settings"
            ? "Настройки"
            : "Готов к работе"}
        </div>
      </div>

      {/* Mockup */}
      <div
        style={{
          position: "absolute",
          top: 80,
          left: "50%",
          transform: "translateX(-50%)",
          opacity: overallOpacity,
          zIndex: 10,
        }}
      >
        <MacMenuBarMockup
          scale={S}
          iconState={iconState}
          iconProgress={iconProgress}
          menuOpacity={menuOpacity}
          activeSubmenu={activeSubmenu}
          highlightedItem={highlightedItem}
          showProgressBar={showProgressBar}
          progressValue={progressValue}
          progressStep={progressStep}
          progressFileName="meeting_2025-02-11.mp4"
          progressEta={progressEta}
          statusText={statusText}
        />
      </div>

      {/* Branding */}
      <div
        style={{
          position: "absolute",
          bottom: 20,
          right: 40,
          fontSize: 16,
          fontWeight: 600,
          color: C.accent,
          opacity: ease(frame, 0, 1, 20, 40),
        }}
      >
        traart.app
      </div>
    </AbsoluteFill>
  );
};
