import type { ShiftTimes, ShiftType } from "./types";

export const DEFAULT_SHIFT_TIMES: ShiftTimes = {
  morningShiftStart: "08:00",
  morningShiftEnd: "14:00",
  eveningShiftStart: "16:00",
  eveningShiftEnd: "22:00",
  fullShiftStart: "08:00",
  fullShiftEnd: "22:00",
};

export function formatShiftRange(shift: ShiftType, times: ShiftTimes = DEFAULT_SHIFT_TIMES) {
  switch (shift) {
    case "MORNING":
      return `${times.morningShiftStart} – ${times.morningShiftEnd}`;
    case "EVENING":
      return `${times.eveningShiftStart} – ${times.eveningShiftEnd}`;
    default:
      return `${times.fullShiftStart} – ${times.fullShiftEnd}`;
  }
}

export function propertyUsesShifts(type?: string) {
  return type === "FARM";
}
