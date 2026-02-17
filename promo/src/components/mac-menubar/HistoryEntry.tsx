import React from "react";
import { C } from "../../shared/colors";

export const HistoryEntry: React.FC<{
  name: string;
  duration: string;
  status: "done" | "error";
  highlighted?: boolean;
  scale?: number;
}> = ({ name, duration, status, highlighted = false, scale = 1 }) => (
  <div
    style={{
      padding: `${4 * scale}px ${12 * scale}px`,
      margin: `0 ${4 * scale}px`,
      borderRadius: 4 * scale,
      display: "flex",
      alignItems: "center",
      gap: 6 * scale,
      background: highlighted ? C.menuHover : "transparent",
      color: highlighted ? "white" : C.menuText,
      fontSize: 13 * scale,
    }}
  >
    <span style={{ fontSize: 12 * scale }}>
      {status === "done" ? "\u2705" : "\u274C"}
    </span>
    <span style={{ flex: 1 }}>{name}</span>
    <span
      style={{
        fontSize: 11 * scale,
        color: highlighted ? "rgba(255,255,255,0.6)" : C.menuTextDim,
      }}
    >
      ({duration})
    </span>
    <span style={{ fontSize: 10 * scale, opacity: 0.5, marginLeft: 2 }}>
      &#9654;
    </span>
  </div>
);
