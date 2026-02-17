import React from "react";
import { C } from "../../shared/colors";

export const MacMenu: React.FC<{
  children: React.ReactNode;
  width?: number;
  opacity?: number;
  scale?: number;
}> = ({ children, width = 320, opacity = 1, scale = 1 }) => {
  if (opacity <= 0) return null;
  return (
    <div
      style={{
        width: width * scale,
        background: C.menuBg,
        borderRadius: 10 * scale,
        border: `0.5px solid ${C.menuBorder}`,
        boxShadow: `0 12px 48px rgba(0,0,0,0.25), 0 2px 8px rgba(0,0,0,0.1)`,
        padding: `${4 * scale}px 0`,
        opacity,
        transform: `scale(${0.95 + opacity * 0.05})`,
        transformOrigin: "top right",
        fontSize: 13 * scale,
        color: C.menuText,
      }}
    >
      {children}
    </div>
  );
};
