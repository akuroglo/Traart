import React from "react";

export interface FinderFileItem {
  name: string;
  icon: string;
  size: string;
  dateModified: string;
  kind: string;
  /** 0-1, defaults to 1 */
  opacity?: number;
  /** defaults to 1 */
  scale?: number;
  /** Optional glow color for newly appearing files */
  glowColor?: string;
}

interface FinderWindowProps {
  title: string;
  files: FinderFileItem[];
  width?: number;
  selectedIndex?: number;
}

/**
 * macOS Finder window mockup (list view, light theme).
 * Props-driven — no internal animations. Animate files via opacity/scale/glowColor.
 */
export const FinderWindow: React.FC<FinderWindowProps> = ({
  title,
  files,
  width = 680,
  selectedIndex,
}) => {
  const ROW_H = 32;
  const TITLE_H = 38;
  const COL_H = 24;
  const STATUS_H = 22;
  const visibleCount = files.filter((f) => (f.opacity ?? 1) > 0.01).length;

  return (
    <div
      style={{
        width,
        borderRadius: 10,
        overflow: "hidden",
        boxShadow:
          "0 22px 70px rgba(0,0,0,0.56), 0 0 0 0.5px rgba(0,0,0,0.25)",
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
        background: "#fff",
      }}
    >
      {/* ===== Title bar ===== */}
      <div
        style={{
          height: TITLE_H,
          background: "linear-gradient(180deg, #ECECEC 0%, #DBDBDB 100%)",
          borderBottom: "1px solid #B8B8B8",
          display: "flex",
          alignItems: "center",
          padding: "0 12px",
          position: "relative",
        }}
      >
        {/* Traffic lights */}
        <div style={{ display: "flex", gap: 8, zIndex: 1 }}>
          {[
            { bg: "#FF5F57", s: "#E0443E" },
            { bg: "#FEBC2E", s: "#DEA123" },
            { bg: "#28C840", s: "#1DAD2B" },
          ].map((d, i) => (
            <div
              key={i}
              style={{
                width: 12,
                height: 12,
                borderRadius: "50%",
                background: d.bg,
                boxShadow: `inset 0 0 0 0.5px ${d.s}`,
              }}
            />
          ))}
        </div>

        {/* Centered title */}
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            textAlign: "center",
            fontSize: 13,
            fontWeight: 600,
            color: "#4D4D4D",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 5,
          }}
        >
          <span style={{ fontSize: 14 }}>&#128193;</span>
          {title}
        </div>
      </div>

      {/* ===== Column headers ===== */}
      <div
        style={{
          display: "flex",
          height: COL_H,
          borderBottom: "1px solid #E0E0E0",
          background: "#F6F6F6",
          fontSize: 11,
          fontWeight: 500,
          color: "#6e6e73",
          alignItems: "center",
          padding: "0 16px",
        }}
      >
        <div style={{ flex: 3 }}>Имя</div>
        <div style={{ flex: 2 }}>Дата изменения</div>
        <div style={{ flex: 1, textAlign: "right" }}>Размер</div>
        <div style={{ flex: 1.5, textAlign: "right", paddingRight: 4 }}>
          Тип
        </div>
      </div>

      {/* ===== File rows ===== */}
      <div style={{ background: "#fff", padding: "2px 0" }}>
        {files.map((file, i) => {
          const selected = i === selectedIndex;
          const op = file.opacity ?? 1;
          const sc = file.scale ?? 1;
          return (
            <div
              key={file.name}
              style={{
                position: "relative",
                display: "flex",
                height: ROW_H,
                alignItems: "center",
                padding: "0 16px",
                background: selected ? "#0058D0" : "transparent",
                fontSize: 13,
                opacity: op,
                transform: `scale(${sc})`,
                transformOrigin: "left center",
                overflow: "hidden",
              }}
            >
              {/* Name + icon */}
              <div
                style={{
                  flex: 3,
                  display: "flex",
                  alignItems: "center",
                  gap: 6,
                  color: selected ? "#fff" : "#1d1d1f",
                }}
              >
                <span style={{ fontSize: 18, lineHeight: 1 }}>{file.icon}</span>
                <span style={{ fontWeight: selected ? 500 : 400 }}>
                  {file.name}
                </span>
              </div>
              {/* Date */}
              <div
                style={{
                  flex: 2,
                  fontSize: 12,
                  color: selected ? "rgba(255,255,255,0.8)" : "#86868B",
                }}
              >
                {file.dateModified}
              </div>
              {/* Size */}
              <div
                style={{
                  flex: 1,
                  textAlign: "right",
                  fontSize: 12,
                  color: selected ? "rgba(255,255,255,0.8)" : "#86868B",
                }}
              >
                {file.size}
              </div>
              {/* Kind */}
              <div
                style={{
                  flex: 1.5,
                  textAlign: "right",
                  paddingRight: 4,
                  fontSize: 12,
                  color: selected ? "rgba(255,255,255,0.8)" : "#86868B",
                }}
              >
                {file.kind}
              </div>

              {/* Glow overlay for new files */}
              {file.glowColor && !selected && (
                <div
                  style={{
                    position: "absolute",
                    inset: 0,
                    background: `linear-gradient(90deg, ${file.glowColor}20 0%, ${file.glowColor}08 100%)`,
                    pointerEvents: "none",
                  }}
                />
              )}
            </div>
          );
        })}
      </div>

      {/* ===== Status bar ===== */}
      <div
        style={{
          height: STATUS_H,
          borderTop: "1px solid #E0E0E0",
          background: "#F6F6F6",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 11,
          color: "#86868B",
        }}
      >
        {visibleCount} объект{visibleCount === 1 ? "" : visibleCount < 5 ? "а" : "ов"}
      </div>
    </div>
  );
};
