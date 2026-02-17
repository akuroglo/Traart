import React from "react";

export const CheckboxItem: React.FC<{
  label: string;
  checked: boolean;
  scale?: number;
}> = ({ label, checked, scale = 1 }) => (
  <div
    style={{
      padding: `${4 * scale}px ${12 * scale}px`,
      margin: `0 ${4 * scale}px`,
      borderRadius: 4 * scale,
      display: "flex",
      alignItems: "center",
      gap: 8 * scale,
      fontSize: 13 * scale,
    }}
  >
    <span style={{ fontSize: 12 * scale, width: 14 * scale }}>
      {checked ? "\u2713" : ""}
    </span>
    {label}
  </div>
);
