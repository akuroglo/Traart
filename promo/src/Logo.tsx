import { AbsoluteFill } from "remotion";

export const Logo: React.FC = () => {
  const size = 1024;
  const padding = 120;
  const iconSize = size - padding * 2;

  return (
    <AbsoluteFill
      style={{
        background: "linear-gradient(135deg, #8B5CF6 0%, #6366F1 30%, #4F46E5 60%, #E879A8 100%)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      {/* White rounded square background */}
      <div
        style={{
          width: iconSize,
          height: iconSize,
          borderRadius: 160,
          background: "#FFFFFF",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: "0 20px 60px rgba(0,0,0,0.15)",
        }}
      >
        {/* Chat bubble with text lines */}
        <svg
          width={iconSize * 0.58}
          height={iconSize * 0.58}
          viewBox="0 0 100 100"
          fill="none"
        >
          {/* Main bubble */}
          <rect
            x="8"
            y="10"
            width="84"
            height="62"
            rx="16"
            fill="#4ECDC4"
          />
          {/* Tail */}
          <path
            d="M22 72 L22 90 L42 72"
            fill="#4ECDC4"
          />
          {/* Text lines */}
          <rect x="24" y="30" width="52" height="6" rx="3" fill="white" />
          <rect x="24" y="43" width="40" height="6" rx="3" fill="white" />
          <rect x="24" y="56" width="46" height="6" rx="3" fill="white" />
        </svg>
      </div>
    </AbsoluteFill>
  );
};
