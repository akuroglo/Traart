import React from "react";
import { C } from "../../shared/colors";

/** Animated dark background with radial gradients + subtle grid overlay. */
export const Background: React.FC<{
  /** Hue for the radial gradients (changes over time for animation) */
  hue?: number;
}> = ({ hue = 240 }) => (
  <>
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: `
          radial-gradient(ellipse at 25% 40%, hsla(${hue}, 60%, 15%, 1) 0%, transparent 60%),
          radial-gradient(ellipse at 75% 60%, hsla(${hue + 30}, 50%, 12%, 1) 0%, transparent 50%),
          radial-gradient(ellipse at 50% 90%, hsla(${hue + 15}, 40%, 8%, 1) 0%, transparent 40%),
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
  </>
);
