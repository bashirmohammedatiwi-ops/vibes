export type NadeemWorld = "FARM" | "HALL" | "DECORATION";

export type NadeemOccasion = {
  key: string;
  enabled: boolean;
  label: string;
  sub: string;
  icon: string;
  world: NadeemWorld;
  impliedType: NadeemWorld | null;
  suggestDecor: boolean;
  reaction: string;
};

type Slot = { enabled: boolean; title: string; sub: string };

export type NadeemConfig = {
  enabled: boolean;
  showInNav: boolean;
  showOnHome: boolean;
  name: string;
  subtitle: string;
  typingLabel: string;
  disabledTitle: string;
  disabledMessage: string;
  greeting: string[];
  typingDelayMs: number;
  occasionStep: { question: string };
  typeStep: {
    enabled: boolean;
    question: string;
    reaction: string;
    reactionAuto: string;
    allowAuto: boolean;
    autoLabel: string;
    autoAnswer: string;
    showCounts: boolean;
    types: { key: NadeemWorld; enabled: boolean; label: string }[];
  };
  provinceStep: {
    enabled: boolean;
    question: string;
    reactionAll: string;
    reactionOne: string;
    anyLabel: string;
    showCounts: boolean;
    hideEmpty: boolean;
  };
  guestsStep: {
    enabled: boolean;
    question: string;
    reaction: string;
    min: number;
    max: number;
    initial: number;
    answer: string;
    confirmLabel: string;
    scales: { upTo: number; label: string }[];
  };
  shiftStep: {
    enabled: boolean;
    question: string;
    reaction: string;
    morning: Slot;
    evening: Slot;
    full: Slot;
    flex: { enabled: boolean; label: string; answer: string };
  };
  budgetStep: {
    enabled: boolean;
    question: string;
    openLabel: string;
    openAnswer: string;
    submitLabel: string;
    answer: string;
    initialPercent: number;
  };
  finish: { intro: string; thinking: string; error: string; retryLabel: string };
  results: {
    title: string;
    editHint: string;
    precise: string;
    approximate: string;
    empty: string;
    decorIntro: string;
    restartLabel: string;
    allResultsLabel: string;
    autoTypeChip: string;
    showMatchPercent: boolean;
    showReasons: boolean;
  };
  occasions: NadeemOccasion[];
  matching: Record<
    | "type"
    | "typeMiss"
    | "province"
    | "provinceMiss"
    | "capacity"
    | "capacityMiss"
    | "budget"
    | "budgetMiss"
    | "shiftPrice"
    | "shiftSupport"
    | "fullDay"
    | "flex"
    | "ratingMultiplier"
    | "featured"
    | "winter"
    | "minScore"
    | "maxResults"
    | "decorCount"
    | "minPercent"
    | "maxPercent",
    number
  >;
  pinned: { propertyId: string; bonus: number }[];
  excluded: string[];
};

export type NadeemAdminPayload = {
  config: NadeemConfig;
  defaults: NadeemConfig;
  icons: string[];
  customized: boolean;
  updatedAt: string | null;
};

export type NadeemStats = {
  days: number;
  total: number;
  allTime: number;
  clicked: number;
  clickRate: number;
  emptyResults: number;
  preciseRate: number;
  avgGuests: number | null;
  avgBudget: number | null;
  byOccasion: { key: string; count: number }[];
  byType: { key: string; count: number }[];
  byProvince: { key: string; count: number }[];
  byShift: { key: string; count: number }[];
  daily: { date: string; sessions: number; clicks: number }[];
  topRecommended: { id: string; name: string; type: string | null; count: number }[];
  topClicked: { id: string; name: string; type: string | null; count: number }[];
};

export type NadeemSessionRow = {
  id: string;
  occasion: string | null;
  propertyType: string | null;
  autoType: boolean;
  province: string | null;
  guests: number | null;
  shift: string | null;
  maxBudget: number | null;
  budgetOpen: boolean;
  resultCount: number;
  precise: boolean;
  platform: string | null;
  createdAt: string;
  clickedAt: string | null;
  user: { id: string; name: string | null; phone: string } | null;
  topResults: { id: string; name: string }[];
  clickedName: string | null;
};

export const ICON_EMOJI: Record<string, string> = {
  diamond: "💍",
  heart: "💞",
  cake: "🎂",
  family: "👨‍👩‍👧",
  work: "💼",
  sparkle: "✨",
  party: "🎉",
  graduation: "🎓",
  baby: "👶",
  music: "🎵",
  star: "⭐",
  gift: "🎁",
  moon: "🌙",
  sun: "☀️",
  pool: "🏊",
  food: "🍽️",
};

export const ICON_LABEL: Record<string, string> = {
  diamond: "خاتم",
  heart: "قلب",
  cake: "كيكة",
  family: "عائلة",
  work: "عمل",
  sparkle: "لمعة",
  party: "حفلة",
  graduation: "تخرج",
  baby: "مولود",
  music: "موسيقى",
  star: "نجمة",
  gift: "هدية",
  moon: "هلال",
  sun: "شمس",
  pool: "مسبح",
  food: "طعام",
};

export const WORLD_LABEL: Record<string, string> = {
  FARM: "مزرعة",
  HALL: "قاعة",
  DECORATION: "تزيين",
  AUTO: "نديم يختار",
};

export const WORLD_COLOR: Record<NadeemWorld, { bg: string; fg: string }> = {
  FARM: { bg: "#ECFDF5", fg: "#047857" },
  HALL: { bg: "#F5F3FF", fg: "#6D28D9" },
  DECORATION: { bg: "#FFF1F2", fg: "#BE123C" },
};

export const SHIFT_LABEL: Record<string, string> = {
  morning: "صباحاً",
  evening: "مساءً",
  full: "يوم كامل",
  flex: "مرن",
};
