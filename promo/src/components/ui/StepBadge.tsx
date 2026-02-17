import React from "react";
import { spring, useVideoConfig } from "remotion";
import { C } from "../../shared/colors";
import { ease } from "../../shared/animation";

export const StepBadge: React.FC<{
  step: number;
  frame: number;
  enterFrame: number;
  exitFrame: number;
}> = ({ step, frame, enterFrame, exitFrame }) => {
  const { fps } = useVideoConfig();
  const opacity = Math.min(
    ease(frame, 0, 1, enterFrame, enterFrame + 10),
    ease(frame, 1, 0, exitFrame - 10, exitFrame)
  );

  const s = spring({
    frame: Math.max(0, frame - enterFrame),
    fps,
    config: { damping: 10, stiffness: 150 },
  });

  if (opacity <= 0) return null;

  return (
    <div
      style={{
        position: "absolute",
        top: 50,
        left: 70,
        opacity,
        transform: `scale(${s})`,
        zIndex: 50,
      }}
    >
      <div
        style={{
          width: 52,
          height: 52,
          borderRadius: 16,
          background: `linear-gradient(135deg, ${C.accent}, ${C.accentGlow})`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 24,
          fontWeight: 800,
          color: "white",
          boxShadow: "0 4px 20px rgba(108,92,231,0.4)",
        }}
      >
        {step}
      </div>
    </div>
  );
};
