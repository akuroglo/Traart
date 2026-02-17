import React from "react";
import { C } from "../../shared/colors";

export const MenuItem: React.FC<{
  label: string;
  shortcut?: string;
  icon?: React.ReactNode;
  disabled?: boolean;
  bold?: boolean;
  hasSubmenu?: boolean;
  highlighted?: boolean;
  scale?: number;
}> = ({
  label,
  shortcut,
  icon,
  disabled = false,
  bold = false,
  hasSubmenu = false,
  highlighted = false,
  scale = 1,
}) => {
  return (
    <div
      style={{
        padding: `${4 * scale}px ${12 * scale}px`,
        margin: `0 ${4 * scale}px`,
        borderRadius: 4 * scale,
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        background: highlighted ? C.menuHover : "transparent",
        color: highlighted ? "white" : disabled ? C.menuTextDim : C.menuText,
        fontWeight: bold ? 600 : 400,
        cursor: disabled ? "default" : "pointer",
        fontSize: 13 * scale,
        lineHeight: 1.4,
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 6 * scale }}>
        {icon && (
          <span
            style={{
              width: 18 * scale,
              textAlign: "center",
              fontSize: 12 * scale,
            }}
          >
            {icon}
          </span>
        )}
        {label}
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 4 * scale }}>
        {shortcut && (
          <span
            style={{
              color: highlighted ? "rgba(255,255,255,0.7)" : C.menuTextDim,
              fontSize: 12 * scale,
            }}
          >
            {shortcut}
          </span>
        )}
        {hasSubmenu && (
          <span
            style={{
              fontSize: 10 * scale,
              opacity: 0.5,
              marginLeft: 4 * scale,
            }}
          >
            &#9654;
          </span>
        )}
      </div>
    </div>
  );
};

export const MenuSeparator: React.FC<{ scale?: number }> = ({
  scale = 1,
}) => (
  <div
    style={{
      height: 1,
      background: C.menuSeparator,
      margin: `${4 * scale}px ${8 * scale}px`,
    }}
  />
);

export const MenuTitle: React.FC<{
  label: string;
  subtitle?: string;
  rightIcon?: React.ReactNode;
  scale?: number;
}> = ({ label, subtitle, rightIcon, scale = 1 }) => (
  <div
    style={{
      padding: `${6 * scale}px ${12 * scale}px`,
      margin: `0 ${4 * scale}px`,
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
    }}
  >
    <div>
      <div style={{ fontWeight: 700, fontSize: 13 * scale }}>{label}</div>
      {subtitle && (
        <div
          style={{
            fontSize: 11 * scale,
            color: C.menuTextDim,
            marginTop: 2,
          }}
        >
          {subtitle}
        </div>
      )}
    </div>
    {rightIcon && <span>{rightIcon}</span>}
  </div>
);
