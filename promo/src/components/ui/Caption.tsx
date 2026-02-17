import React from "react";
import { C } from "../../shared/colors";
import { ease } from "../../shared/animation";

export const Caption: React.FC<{
  text: string;
  subtitle?: string;
  frame: number;
  enterFrame: number;
  exitFrame: number;
  position?: "bottom" | "top";
}> = ({ text, subtitle, frame, enterFrame, exitFrame, position = "bottom" }) => {
  const opacity = Math.min(
    ease(frame, 0, 1, enterFrame, enterFrame + 15),
    ease(frame, 1, 0, exitFrame - 12, exitFrame)
  );

  const y = ease(frame, 15, 0, enterFrame, enterFrame + 20);

  if (opacity <= 0) return null;

  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        ...(position === "bottom" ? { bottom: 80 } : { top: 80 }),
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 8,
        opacity,
        transform: `translateY(${position === "bottom" ? y : -y}px)`,
        zIndex: 50,
      }}
    >
      <div
        style={{
          fontSize: 44,
          fontWeight: 700,
          color: C.text,
          letterSpacing: -1,
          textAlign: "center",
          textShadow: "0 2px 20px rgba(0,0,0,0.5)",
        }}
      >
        {text}
      </div>
      {subtitle && (
        <div
          style={{
            fontSize: 21,
            color: C.textMuted,
            textAlign: "center",
            maxWidth: 700,
            lineHeight: 1.4,
          }}
        >
          {subtitle}
        </div>
      )}
    </div>
  );
};
