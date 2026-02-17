import React from "react";
import { C } from "../../shared/colors";

export const QualitySlider: React.FC<{
  /** 0..4 position (0=Быстро, 4=Макс) */
  value?: number;
  scale?: number;
}> = ({ value = 2, scale = 1 }) => {
  const position = `${(value / 4) * 100}%`;
  return (
    <div
      style={{
        padding: `${6 * scale}px ${16 * scale}px`,
        display: "flex",
        alignItems: "center",
        gap: 8 * scale,
      }}
    >
      <span style={{ fontSize: 10 * scale, color: C.menuTextDim }}>
        Быстро
      </span>
      <div
        style={{
          flex: 1,
          height: 4 * scale,
          background: "rgba(0,0,0,0.1)",
          borderRadius: 2 * scale,
          position: "relative",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: position,
            top: "50%",
            transform: "translate(-50%, -50%)",
            width: 14 * scale,
            height: 14 * scale,
            borderRadius: "50%",
            background: "white",
            border: "0.5px solid rgba(0,0,0,0.15)",
            boxShadow: "0 1px 3px rgba(0,0,0,0.2)",
          }}
        />
      </div>
      <span style={{ fontSize: 10 * scale, color: C.menuTextDim }}>Макс.</span>
    </div>
  );
};
