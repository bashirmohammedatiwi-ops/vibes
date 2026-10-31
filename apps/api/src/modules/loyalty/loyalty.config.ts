import { PropertyType } from '@prisma/client';

export type LoyaltyProgramConfig = {
  enabled: boolean;
  /** عدد الحجوزات المكتملة المطلوبة قبل الخصم. */
  required: number;
  /** نسبة الخصم على الحجز التالي. */
  percent: number;
  /** أقصى خصم بالدينار (0 = بلا سقف). */
  maxDiscount: number;
};

export type LoyaltyConfig = {
  enabled: boolean;
  programs: Record<PropertyType, LoyaltyProgramConfig>;
};

export const LOYALTY_TYPES: PropertyType[] = [
  PropertyType.FARM,
  PropertyType.HALL,
  PropertyType.DECORATION,
];

const DEFAULT_PROGRAM: LoyaltyProgramConfig = {
  enabled: true,
  required: 5,
  percent: 25,
  maxDiscount: 0,
};

export const DEFAULT_LOYALTY_CONFIG: LoyaltyConfig = {
  enabled: true,
  programs: {
    [PropertyType.FARM]: DEFAULT_PROGRAM,
    [PropertyType.HALL]: DEFAULT_PROGRAM,
    [PropertyType.DECORATION]: DEFAULT_PROGRAM,
  },
};

const intIn = (value: unknown, min: number, max: number, fallback: number) => {
  const n = Number(value);
  return Number.isFinite(n) ? Math.min(max, Math.max(min, Math.round(n))) : fallback;
};

export function normalizeLoyaltyConfig(raw: unknown): LoyaltyConfig {
  const input = (raw ?? {}) as { enabled?: unknown; programs?: Record<string, Partial<LoyaltyProgramConfig>> };
  const programs = {} as LoyaltyConfig['programs'];
  for (const type of LOYALTY_TYPES) {
    const p = input.programs?.[type] ?? {};
    programs[type] = {
      enabled: p.enabled !== false,
      required: intIn(p.required, 1, 50, DEFAULT_PROGRAM.required),
      percent: intIn(p.percent, 1, 100, DEFAULT_PROGRAM.percent),
      maxDiscount: intIn(p.maxDiscount, 0, 1_000_000_000, DEFAULT_PROGRAM.maxDiscount),
    };
  }
  return { enabled: input.enabled !== false, programs };
}

/**
 * الدورة: كل [required] حجوزات مكتملة بسعرها الكامل تمنح خصماً على حجز واحد.
 * كل شيء يُحسب من الحجوزات نفسها، فإلغاء حجز استُخدم فيه الخصم يعيده تلقائياً.
 */
export function loyaltyProgress(paidCompleted: number, activeRewards: number, required: number) {
  const earned = Math.floor(paidCompleted / required);
  const rewardsAvailable = Math.max(0, earned - activeRewards);
  const stamps = rewardsAvailable > 0 ? required : paidCompleted % required;
  return { earned, rewardsAvailable, stamps, remaining: required - stamps };
}

export function loyaltyDiscount(total: number, program: Pick<LoyaltyProgramConfig, 'percent' | 'maxDiscount'>) {
  const discount = Math.round((total * program.percent) / 100);
  return program.maxDiscount > 0 ? Math.min(discount, program.maxDiscount) : discount;
}
