import { interpolate, Easing } from "remotion";

/** Smooth ease interpolation with clamped extrapolation and cubic easing. */
export function ease(
  frame: number,
  from: number,
  to: number,
  startF: number,
  endF: number
): number {
  return interpolate(frame, [startF, endF], [from, to], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });
}
