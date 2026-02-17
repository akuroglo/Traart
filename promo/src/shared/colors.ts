// Unified color palette for all Traart Remotion compositions.
// Sources: HowItWorks, WerComparison, CostComparison, PrivacyComparison + Swift app colors.

export const C = {
  // Backgrounds
  bg1: "#0a0a1a",
  bg2: "#0f0f2e",
  bg3: "#1a1040",

  // Brand accent (purple)
  accent: "#6C5CE7",
  accentGlow: "#A29BFE",

  // Semantic colors
  green: "#30D158",
  red: "#FF6B6B",
  orange: "#FF9F43",
  yellow: "#FECA57",

  // Text
  text: "#FFFFFF",
  textMuted: "#8888AA",
  textDim: "#555577",

  // macOS menu (light mode)
  menuBg: "rgba(236,236,240,0.96)",
  menuBorder: "rgba(0,0,0,0.12)",
  menuText: "#1d1d1f",
  menuTextDim: "rgba(0,0,0,0.35)",
  menuHover: "#0A82FF",
  menuBarBg: "rgba(228,228,232,0.88)",
  menuSeparator: "rgba(0,0,0,0.1)",
  checkGreen: "#34C759",

  // Traart app real colors (from Swift sources)
  teal: "#00BFBF",
  tealA: "#00B8B8",
  tealB: "#00E0E0",
  appGreen: "#33C759", // completed state
  appRed: "#FF453A", // error state
} as const;

export type ColorKey = keyof typeof C;
