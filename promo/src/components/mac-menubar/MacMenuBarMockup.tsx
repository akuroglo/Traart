import React from "react";
import { C } from "../../shared/colors";
import { MacMenuBar } from "./MacMenuBar";
import { MacMenu } from "./MacMenu";
import { MenuItem, MenuSeparator, MenuTitle } from "./MenuItem";
import { CheckboxItem } from "./CheckboxItem";
import { HistoryEntry } from "./HistoryEntry";
import { SettingsSubmenu } from "./SettingsSubmenu";
import { ProgressBar } from "./ProgressBar";
import { TraartSparkleIcon, SparkleState } from "./TraartSparkleIcon";

export interface MacMenuBarMockupProps {
  scale?: number;

  // Icon state
  iconState: SparkleState;
  /** 0..1 for transcribing state */
  iconProgress?: number;

  // Menu visibility
  menuOpacity?: number;
  /** Which submenu to show: "none" | "history" | "settings" */
  activeSubmenu?: "none" | "history" | "settings";

  // Highlighted menu items
  highlightedItem?: string;

  // Progress bar (shown inside menu during transcription)
  showProgressBar?: boolean;
  progressValue?: number;
  progressStep?: string;
  progressFileName?: string;
  progressEta?: string;

  // Status text
  statusText?: string;

  // Settings submenu overrides
  settingsQuality?: number;
  settingsAutoTranscribe?: boolean;
  settingsDiarization?: boolean;
}

/**
 * Orchestrating component: pixel-perfect macOS menu bar mockup for Traart.
 * Props-driven, no internal animations — all state comes from outside.
 */
export const MacMenuBarMockup: React.FC<MacMenuBarMockupProps> = ({
  scale = 1,
  iconState,
  iconProgress = 0,
  menuOpacity = 0,
  activeSubmenu = "none",
  highlightedItem,
  showProgressBar = false,
  progressValue = 0,
  progressStep,
  progressFileName,
  progressEta,
  statusText = "Готово",
  settingsQuality = 2,
  settingsAutoTranscribe = true,
  settingsDiarization = true,
}) => {
  const S = scale;
  const showMenu = menuOpacity > 0;

  return (
    <div style={{ position: "relative", display: "inline-block" }}>
      {/* Menu bar strip */}
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
            <TraartSparkleIcon
              state={iconState}
              progress={iconProgress}
              size={16 * S}
            />
            {iconState === "transcribing" && (
              <span
                style={{
                  fontSize: 12 * S,
                  fontWeight: 500,
                  color: C.teal,
                  fontVariantNumeric: "tabular-nums",
                }}
              >
                {Math.round(iconProgress * 100)}%
              </span>
            )}
          </div>
        }
      />

      {/* Dropdown menu */}
      {showMenu && (
        <div
          style={{
            position: "absolute",
            top: 34 * S,
            left: 4 * S,
            display: "flex",
            gap: 4 * S,
            opacity: menuOpacity,
            transform: `translateY(${(1 - menuOpacity) * -8}px)`,
            zIndex: 30,
          }}
        >
          {/* Main menu */}
          <MacMenu width={310} scale={S}>
            <MenuTitle
              label="Traart"
              subtitle={`Статус: ${statusText}`}
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
                  }}
                >
                  <TraartSparkleIcon
                    state={iconState === "error" ? "error" : iconState === "completed" ? "completed" : "idle"}
                    size={16 * S}
                  />
                </div>
              }
            />
            {/* Progress bar shown during transcription */}
            {showProgressBar && (
              <>
                <MenuSeparator scale={S} />
                <ProgressBar
                  progress={progressValue}
                  step={progressStep}
                  fileName={progressFileName}
                  etaString={progressEta}
                  scale={S}
                />
                <MenuItem label="Отменить транскрибацию" shortcut="⌘." scale={S} />
              </>
            )}
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
            <MenuItem
              label="История"
              hasSubmenu
              highlighted={highlightedItem === "history"}
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
              highlighted={highlightedItem === "settings"}
              scale={S}
            />
            <MenuSeparator scale={S} />
            <MenuItem label="О программе" scale={S} />
            <MenuItem label="Выход" shortcut="⌘Q" scale={S} />
          </MacMenu>

          {/* History submenu */}
          {activeSubmenu === "history" && (
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
          )}

          {/* Settings submenu */}
          {activeSubmenu === "settings" && (
            <SettingsSubmenu
              scale={S}
              qualityValue={settingsQuality}
              autoTranscribe={settingsAutoTranscribe}
              diarization={settingsDiarization}
            />
          )}
        </div>
      )}
    </div>
  );
};
