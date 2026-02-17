import React from "react";
import { C } from "../../shared/colors";

export const MacMenuBar: React.FC<{
  traartContent: React.ReactNode;
  scale?: number;
}> = ({ traartContent, scale = 1 }) => {
  return (
    <div
      style={{
        width: 900 * scale,
        height: 32 * scale,
        background: C.menuBarBg,
        borderRadius: 0,
        display: "flex",
        alignItems: "center",
        justifyContent: "flex-end",
        paddingRight: 14 * scale,
        gap: 10 * scale,
        fontSize: 13 * scale,
        fontWeight: 400,
        color: C.menuText,
        position: "relative",
        boxShadow: "0 1px 4px rgba(0,0,0,0.08)",
      }}
    >
      {traartContent}
      <span style={{ opacity: 0.5, fontSize: 14 * scale }}>&#128269;</span>
      <span style={{ opacity: 0.6, fontSize: 12 * scale }}>&#9889; 35%</span>
      <span style={{ opacity: 0.5, fontSize: 14 * scale }}>&#128267; 89%</span>
      <span style={{ opacity: 0.5 }}>&#128246;</span>
      <span style={{ fontSize: 12 * scale }}>&#1057;&#1088;, 11 &#1092;&#1077;&#1074;&#1088;. 18:24</span>
    </div>
  );
};
