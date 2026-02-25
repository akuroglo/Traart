import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  interpolate,
  spring,
  useVideoConfig,
} from "remotion";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { LightLeak } from "@remotion/light-leaks";
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

// ============================================================
// Scene durations (local frames)
// ============================================================
const D = {
  intro: 60,
  step1: 140,
  step2: 185,
  step3: 165,
  history: 70,
  settings: 120,
  outro: 167,
  // Transitions (fade reduces total duration)
  fade1: 15,
  fade2: 12,
  fade3: 8,
  // Overlays (light leaks — don't reduce duration)
  leak1: 20,
  leak2: 25,
  leak3: 20,
} as const;

// Total = sum(scenes) - sum(fades) = 907 - 35 = 872
export const TOTAL_FRAMES = 872;

const S = 1.8; // UI scale for macOS components

// ============================================================
// Menu bar icon helper
// ============================================================
const MenuBarIcon: React.FC<{
  state: "idle" | "progress" | "done";
  progress?: number;
}> = ({ state, progress = 0 }) => {
  if (state === "idle") {
    return (
      <span style={{ display: "flex", alignItems: "center", opacity: 0.7 }}>
        <TraartSparkleIcon state="idle" size={16 * S} />
      </span>
    );
  }
  if (state === "progress") {
    return (
      <span
        style={{
          fontSize: 12 * S,
          fontWeight: 500,
          display: "flex",
          alignItems: "center",
          gap: 4 * S,
          color: C.teal,
        }}
      >
        <TraartSparkleIcon
          state="transcribing"
          progress={progress / 100}
          size={16 * S}
        />
        {Math.round(progress)}%
      </span>
    );
  }
  return (
    <span style={{ display: "flex", alignItems: "center" }}>
      <TraartSparkleIcon state="completed" size={16 * S} />
    </span>
  );
};

// ============================================================
// Centered scene headline (large, readable)
// ============================================================
const SceneHeadline: React.FC<{
  step?: number;
  title: string;
  subtitle?: string;
  color?: string;
}> = ({ step, title, subtitle, color = C.teal }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const scale = spring({
    frame: Math.max(0, frame - 3),
    fps,
    config: { damping: 10, stiffness: 180 },
  });
  const op = ease(frame, 0, 1, 2, 12);
  const subOp = subtitle ? ease(frame, 0, 1, 10, 22) : 0;
  return (
    <div
      style={{
        position: "absolute",
        top: subtitle ? 45 : 70,
        left: 0,
        right: 0,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 8,
        zIndex: 50,
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 18,
          transform: `scale(${scale})`,
          opacity: op,
        }}
      >
        {step !== undefined && (
          <div
            style={{
              width: 54,
              height: 54,
              borderRadius: "50%",
              background: color,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 26,
              fontWeight: 800,
              color: "#fff",
              boxShadow: `0 0 30px ${color}50`,
              flexShrink: 0,
            }}
          >
            {step}
          </div>
        )}
        <div
          style={{
            fontSize: 44,
            fontWeight: 800,
            color: C.text,
            letterSpacing: -1,
          }}
        >
          {title}
        </div>
      </div>
      {subtitle && (
        <div style={{ fontSize: 22, color: C.textMuted, opacity: subOp }}>
          {subtitle}
        </div>
      )}
    </div>
  );
};

// ============================================================
// Bottom caption helper
// ============================================================
const BottomCaption: React.FC<{
  text: string;
  sceneDuration: number;
}> = ({ text, sceneDuration }) => {
  const frame = useCurrentFrame();
  const op = Math.min(
    ease(frame, 0, 1, 8, 20),
    ease(frame, 1, 0, sceneDuration - 20, sceneDuration - 5)
  );
  return (
    <div
      style={{
        position: "absolute",
        bottom: 50,
        left: 0,
        right: 0,
        textAlign: "center",
        opacity: op,
      }}
    >
      <div style={{ fontSize: 32, color: C.textMuted }}>{text}</div>
    </div>
  );
};

// ============================================================
// SCENE: Intro (60 frames)
// ============================================================
const IntroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleScale = spring({
    frame: Math.max(0, frame - 5),
    fps,
    config: { damping: 9, stiffness: 180 },
  });
  const op = ease(frame, 1, 0, 44, 58);

  return (
    <AbsoluteFill
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        opacity: op,
      }}
    >
      <div
        style={{
          transform: `scale(${titleScale})`,
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
    </AbsoluteFill>
  );
};

// ============================================================
// SCENE: Step 1 — Menu bar + dropdown (140 frames)
// ============================================================
const Step1Scene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Menu bar drops from top
  const menuBarDrop = spring({
    frame: Math.max(0, frame - 6),
    fps,
    config: { damping: 12, stiffness: 150 },
  });

  // Dropdown opens
  const ddSpring = spring({
    frame: Math.max(0, frame - 22),
    fps,
    config: { damping: 12, stiffness: 180 },
  });
  const ddOp = ease(frame, 0, 1, 22, 34);

  // Scanning highlights — 5 key items, ~13 frames each
  const hlCopy = frame >= 38 && frame < 51;
  const hlTranscribe = frame >= 51 && frame < 64;
  const hlNewFiles = frame >= 64 && frame < 77;
  const hlHistory = frame >= 77 && frame < 90;
  const hlSettings = frame >= 90 && frame < 105;

  return (
    <AbsoluteFill>
      <SceneHeadline step={1} title="Живёт в меню-баре" color={C.accent} />

      {/* Menu bar */}
      <div
        style={{
          position: "absolute",
          top: interpolate(menuBarDrop, [0, 1], [-80, 185]),
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
              <MenuBarIcon state="idle" />
            </div>
          }
        />

        {/* Dropdown with scanning highlights */}
        {ddOp > 0 && (
          <div
            style={{
              position: "absolute",
              top: 34 * S,
              left: 4 * S,
              opacity: ddOp,
              transform: `scaleY(${ddSpring}) scaleX(${0.5 + ddSpring * 0.5})`,
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
              <MenuItem label="Копировать последнюю транскрипцию" shortcut="⇧⌘C" bold highlighted={hlCopy} scale={S} />
              <MenuItem label="Транскрибировать файл..." shortcut="⌘O" highlighted={hlTranscribe} scale={S} />
              <MenuSeparator scale={S} />
              <MenuItem label="Новые файлы" hasSubmenu highlighted={hlNewFiles} scale={S} />
              <MenuItem label="История" hasSubmenu highlighted={hlHistory} scale={S} />
              <MenuItem label="Открыть папку транскрипций" shortcut="⇧⌘O" scale={S} />
              <MenuSeparator scale={S} />
              <MenuItem label="Настройки" hasSubmenu highlighted={hlSettings} scale={S} />
              <MenuSeparator scale={S} />
              <MenuItem label="О программе" scale={S} />
              <MenuItem label="Выход" shortcut="⌘Q" scale={S} />
            </MacMenu>
          </div>
        )}
      </div>

      <BottomCaption
        text="Traart работает в фоне и следит за новыми записями"
        sceneDuration={D.step1}
      />
    </AbsoluteFill>
  );
};

// ============================================================
// SCENE: Step 2 — Progress (185 frames)
// ============================================================
const Step2Scene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Progress 0→100%
  const progressValue = interpolate(
    frame,
    [20, 55, 85, 125, 148],
    [0, 12, 35, 72, 100],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  // Menu bar drops
  const menuBarDrop = spring({
    frame: Math.max(0, frame - 5),
    fps,
    config: { damping: 12, stiffness: 150 },
  });

  // Progress ring springs in
  const ringScale = spring({
    frame: Math.max(0, frame - 18),
    fps,
    config: { damping: 12, stiffness: 180 },
  });

  // Typewriter text
  const typeChars =
    frame >= 60
      ? Math.floor(
          interpolate(frame, [60, 148], [0, 72], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })
        )
      : 0;
  const previewFull =
    "Здравствуйте, сегодня мы обсудим применение нейросетей в обработке речи.";
  const previewVisible = previewFull.slice(0, typeChars);

  return (
    <AbsoluteFill>
      <SceneHeadline step={2} title="Транскрибирует сам" subtitle="Автоматически находит новые файлы" color={C.teal} />

      {/* Menu bar with progress icon */}
      <div
        style={{
          position: "absolute",
          top: interpolate(menuBarDrop, [0, 1], [-80, 185]),
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
              <MenuBarIcon state="progress" progress={progressValue} />
            </div>
          }
        />
      </div>

      {/* Progress ring + info */}
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
          <svg width={130} height={130} viewBox="0 0 130 130">
            <circle cx="65" cy="65" r="55" stroke="rgba(108,92,231,0.15)" strokeWidth="8" fill="none" />
            <circle
              cx="65" cy="65" r="55"
              stroke={C.teal} strokeWidth="8" fill="none"
              strokeDasharray={`${(progressValue / 100) * 345.58} 345.58`}
              strokeLinecap="round" transform="rotate(-90 65 65)"
            />
            <text
              x="65" y="70" textAnchor="middle" fill="white"
              fontSize="30" fontWeight="700" fontFamily="-apple-system, sans-serif"
            >
              {Math.round(progressValue)}%
            </text>
          </svg>

          <div>
            <div style={{ fontSize: 22, fontWeight: 600, color: C.text, marginBottom: 8 }}>
              {progressValue < 25
                ? "Загрузка модели..."
                : progressValue < 70
                ? "Транскрибация..."
                : "Финализация..."}
            </div>
            <div style={{ fontSize: 16, color: C.textMuted, marginBottom: 12 }}>
              meeting_2025-02-11.mp4
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <TraartSparkleIcon state="transcribing" progress={progressValue / 100} size={22} />
              <span style={{ fontSize: 14, color: C.teal, fontWeight: 500 }}>GigaAM v3</span>
            </div>
          </div>
        </div>

        {/* Typewriter preview */}
        {typeChars > 0 && (
          <div
            style={{
              maxWidth: 640,
              padding: "18px 26px",
              borderRadius: 14,
              background: "rgba(255,255,255,0.05)",
              border: `1px solid ${C.teal}15`,
              fontSize: 19,
              color: C.textMuted,
              lineHeight: 1.6,
              opacity: ease(frame, 0, 1, 62, 72),
            }}
          >
            <span style={{ color: C.teal, fontSize: 15, fontWeight: 600 }}>
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

      <BottomCaption
        text="GigaAM v3 — лучшее распознавание русской речи (WER 8.3%)"
        sceneDuration={D.step2}
      />
    </AbsoluteFill>
  );
};

// ============================================================
// SCENE: Step 3 — Win + Finder (165 frames)
// ============================================================
const Step3Scene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Finder springs in immediately
  const finderScale = spring({
    frame: Math.max(0, frame - 6),
    fps,
    config: { damping: 12, stiffness: 150 },
  });
  const finderOp = ease(frame, 0, 1, 4, 16);

  // .md file springs in
  const mdScale = spring({
    frame: Math.max(0, frame - 38),
    fps,
    config: { damping: 10, stiffness: 180 },
  });
  const mdOp = ease(frame, 0, 1, 36, 46);
  const mdGlow =
    frame >= 36 && frame < 80
      ? interpolate(frame, [36, 52, 80], [0, 1, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        })
      : 0;

  const finderFiles: FinderFileItem[] = [
    { name: "interview_2025-02-11.mp4", icon: "\uD83C\uDFA5", size: "127 МБ", dateModified: "11 фев, 14:30", kind: "MP4" },
    { name: "notes_standup.txt", icon: "\uD83D\uDCC4", size: "4 КБ", dateModified: "10 фев, 09:15", kind: "Текст" },
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

  // "Готово за 38 секунд" tag
  const tagOp = ease(frame, 0, 1, 55, 68);

  return (
    <AbsoluteFill>
      <SceneHeadline step={3} title="Файл готов" color={C.appGreen} />

      {/* Finder window */}
      <div
        style={{
          position: "absolute",
          top: 200,
          left: "50%",
          transform: `translateX(-50%) scale(${finderScale})`,
          opacity: finderOp,
          transformOrigin: "top center",
        }}
      >
        <FinderWindow title="Interviews" files={finderFiles} width={880} />
      </div>

      {/* "Готово за 38 секунд" tag */}
      {tagOp > 0 && (
        <div
          style={{
            position: "absolute",
            bottom: 110,
            left: "50%",
            transform: "translateX(-50%)",
            opacity: tagOp,
          }}
        >
          <div
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 12,
              padding: "12px 28px",
              borderRadius: 20,
              background: `${C.appGreen}15`,
              border: `1px solid ${C.appGreen}30`,
            }}
          >
            <TraartSparkleIcon state="completed" size={22} />
            <span style={{ fontSize: 22, fontWeight: 600, color: C.appGreen }}>
              Готово за 38 секунд
            </span>
          </div>
        </div>
      )}

      <BottomCaption
        text="Транскрипция сохраняется рядом с оригиналом"
        sceneDuration={D.step3}
      />
    </AbsoluteFill>
  );
};

// ============================================================
// SCENE: History bonus (70 frames)
// ============================================================
const HistoryScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const mockupScale = spring({
    frame: Math.max(0, frame - 3),
    fps,
    config: { damping: 12, stiffness: 180 },
  });

  return (
    <AbsoluteFill>
      <SceneHeadline title="Вся история под рукой" />

      <div
        style={{
          position: "absolute",
          top: 170,
          left: "50%",
          transform: `translateX(-50%) scale(${mockupScale})`,
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
    </AbsoluteFill>
  );
};

// ============================================================
// SCENE: Settings bonus (120 frames) — animated feature cards
// ============================================================
const settingCards = [
  { icon: "\uD83D\uDCDD", title: "Формат вывода", detail: "Markdown \u00B7 TXT \u00B7 SRT", color: C.accent },
  { icon: "\uD83C\uDFA8", title: "Качество распознавания", detail: "5 режимов — от быстрого до максимума", color: C.teal },
  { icon: "\uD83D\uDCC1", title: "Куда сохранять", detail: "Рядом с файлом или в свою папку", color: C.appGreen },
];

const SettingsScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  return (
    <AbsoluteFill>
      <SceneHeadline title="Настрой под себя" />

      <div
        style={{
          position: "absolute",
          top: 180,
          left: "50%",
          transform: "translateX(-50%)",
          display: "flex",
          flexDirection: "column",
          gap: 22,
        }}
      >
        {settingCards.map((card, i) => {
          const delay = 8 + i * 20;
          const cardScale = spring({
            frame: Math.max(0, frame - delay),
            fps,
            config: { damping: 12, stiffness: 180 },
          });
          const cardOp = ease(frame, 0, 1, delay, delay + 14);
          // Glow pulse when card first appears
          const glowOp =
            frame >= delay && frame < delay + 40
              ? interpolate(frame, [delay, delay + 12, delay + 40], [0, 0.8, 0], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                })
              : 0;

          return (
            <div
              key={i}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 24,
                padding: "22px 36px",
                borderRadius: 18,
                background: "rgba(255,255,255,0.06)",
                border: `1px solid ${card.color}30`,
                width: 520,
                transform: `scale(${cardScale}) translateX(${(1 - cardScale) * (i % 2 === 0 ? -40 : 40)}px)`,
                opacity: cardOp,
                boxShadow: glowOp > 0
                  ? `0 0 40px ${card.color}${Math.round(glowOp * 40).toString(16).padStart(2, "0")}, inset 0 0 30px ${card.color}${Math.round(glowOp * 15).toString(16).padStart(2, "0")}`
                  : "none",
              }}
            >
              <div style={{ fontSize: 40, flexShrink: 0 }}>{card.icon}</div>
              <div>
                <div
                  style={{
                    fontSize: 24,
                    fontWeight: 700,
                    color: C.text,
                    marginBottom: 4,
                  }}
                >
                  {card.title}
                </div>
                <div style={{ fontSize: 17, color: C.textMuted }}>
                  {card.detail}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};

// ============================================================
// SCENE: Outro (167 frames)
// ============================================================
const OutroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const sparkleScale = spring({
    frame: Math.max(0, frame - 3),
    fps,
    config: { damping: 8, stiffness: 100 },
  });
  const titleScale = spring({
    frame: Math.max(0, frame - 12),
    fps,
    config: { damping: 9, stiffness: 150 },
  });

  // Particle burst
  const particles = Array.from({ length: 12 }, (_, i) => {
    const angle = (i / 12) * Math.PI * 2;
    const dist = spring({
      frame: Math.max(0, frame - 6 - (i % 3)),
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
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
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

      <div style={{ transform: `scale(${sparkleScale})`, marginBottom: 20 }}>
        <TraartSparkleIcon state="completed" size={72} />
      </div>

      <div
        style={{
          fontSize: 76,
          fontWeight: 900,
          color: C.text,
          letterSpacing: -3,
          marginBottom: 12,
          transform: `scale(${titleScale})`,
        }}
      >
        Traart
      </div>

      <div
        style={{
          fontSize: 28,
          color: C.textMuted,
          textAlign: "center",
          marginBottom: 32,
          lineHeight: 1.5,
          opacity: ease(frame, 0, 1, 28, 45),
        }}
      >
        Лучшая транскрибация русской речи.
        <br />
        Локально. Бесплатно. Без компромиссов.
      </div>

      {/* Feature pills with staggered springs */}
      <div style={{ display: "flex", gap: 14, marginBottom: 32 }}>
        {["100% оффлайн", "Лучшее качество", "Деление по голосам", "Для macOS"].map(
          (label, i) => {
            const pillScale = spring({
              frame: Math.max(0, frame - 48 - i * 6),
              fps,
              config: { damping: 10, stiffness: 200 },
            });
            return (
              <div
                key={label}
                style={{
                  padding: "12px 28px",
                  borderRadius: 30,
                  background: `${C.teal}12`,
                  border: `1px solid ${C.teal}25`,
                  color: C.teal,
                  fontSize: 19,
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
          fontSize: 28,
          fontWeight: 700,
          color: C.teal,
          opacity: ease(frame, 0, 1, 90, 120),
          textShadow: `0 0 40px ${C.teal}40`,
        }}
      >
        traart.ru
      </div>
    </AbsoluteFill>
  );
};

// ============================================================
// MAIN COMPOSITION
// ============================================================
export const HowItWorksV6: React.FC = () => {
  const frame = useCurrentFrame();

  const bgHue = interpolate(frame, [0, TOTAL_FRAMES], [230, 275], {
    extrapolateRight: "clamp",
  });
  const blob1X = interpolate(frame, [0, TOTAL_FRAMES], [22, 38], { extrapolateRight: "clamp" });
  const blob1Y = interpolate(frame, [0, TOTAL_FRAMES], [28, 52], { extrapolateRight: "clamp" });
  const blob2X = interpolate(frame, [0, TOTAL_FRAMES], [78, 60], { extrapolateRight: "clamp" });
  const blob2Y = interpolate(frame, [0, TOTAL_FRAMES], [65, 40], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill
      style={{
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", sans-serif',
        overflow: "hidden",
      }}
    >
      {/* ========== GLOBAL ANIMATED BACKGROUND ========== */}
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

      {/* ========== TRANSITION SERIES ========== */}
      <TransitionSeries>
        {/* INTRO */}
        <TransitionSeries.Sequence durationInFrames={D.intro}>
          <IntroScene />
        </TransitionSeries.Sequence>

        {/* Light leak: teal (intro → step 1) */}
        <TransitionSeries.Overlay durationInFrames={D.leak1}>
          <LightLeak seed={1} hueShift={180} />
        </TransitionSeries.Overlay>

        {/* STEP 1 */}
        <TransitionSeries.Sequence durationInFrames={D.step1}>
          <Step1Scene />
        </TransitionSeries.Sequence>

        {/* Fade crossfade (step 1 → step 2) */}
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: D.fade1 })}
        />

        {/* STEP 2 */}
        <TransitionSeries.Sequence durationInFrames={D.step2}>
          <Step2Scene />
        </TransitionSeries.Sequence>

        {/* Light leak: green (step 2 → step 3) */}
        <TransitionSeries.Overlay durationInFrames={D.leak2}>
          <LightLeak seed={3} hueShift={120} />
        </TransitionSeries.Overlay>

        {/* STEP 3 */}
        <TransitionSeries.Sequence durationInFrames={D.step3}>
          <Step3Scene />
        </TransitionSeries.Sequence>

        {/* Fade (step 3 → history) */}
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: D.fade2 })}
        />

        {/* HISTORY */}
        <TransitionSeries.Sequence durationInFrames={D.history}>
          <HistoryScene />
        </TransitionSeries.Sequence>

        {/* Fade (history → settings) */}
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: D.fade3 })}
        />

        {/* SETTINGS */}
        <TransitionSeries.Sequence durationInFrames={D.settings}>
          <SettingsScene />
        </TransitionSeries.Sequence>

        {/* Light leak: blue (settings → outro) */}
        <TransitionSeries.Overlay durationInFrames={D.leak3}>
          <LightLeak seed={5} hueShift={240} />
        </TransitionSeries.Overlay>

        {/* OUTRO */}
        <TransitionSeries.Sequence durationInFrames={D.outro}>
          <OutroScene />
        </TransitionSeries.Sequence>
      </TransitionSeries>
    </AbsoluteFill>
  );
};
