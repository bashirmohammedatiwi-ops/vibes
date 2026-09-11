function required(config: Record<string, unknown>, key: string): string {
  const value = config[key];
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

export function validateEnv(config: Record<string, unknown>) {
  required(config, 'DATABASE_URL');
  required(config, 'JWT_ACCESS_SECRET');
  required(config, 'JWT_REFRESH_SECRET');

  return {
    NODE_ENV: String(config.NODE_ENV ?? 'development'),
    APP_PORT: Number(config.APP_PORT ?? 3000),
    APP_URL: String(config.APP_URL ?? 'http://localhost:3000'),
    DATABASE_URL: required(config, 'DATABASE_URL'),
    REDIS_URL: String(config.REDIS_URL ?? 'redis://localhost:6379'),
    JWT_ACCESS_SECRET: required(config, 'JWT_ACCESS_SECRET'),
    JWT_REFRESH_SECRET: required(config, 'JWT_REFRESH_SECRET'),
    JWT_ACCESS_EXPIRES_IN: String(config.JWT_ACCESS_EXPIRES_IN ?? '15m'),
    JWT_REFRESH_EXPIRES_IN: String(config.JWT_REFRESH_EXPIRES_IN ?? '30d'),
    OTP_EXPIRES_IN_SECONDS: Number(config.OTP_EXPIRES_IN_SECONDS ?? 300),
    OTP_LENGTH: Number(config.OTP_LENGTH ?? 6),
    OTP_PROVIDER: String(config.OTP_PROVIDER ?? 'development'),
    MEDIA_ROOT: String(config.MEDIA_ROOT ?? './uploads'),
    MEDIA_PUBLIC_URL: String(config.MEDIA_PUBLIC_URL ?? 'http://localhost:3000/media'),
    MAX_UPLOAD_MB: Number(config.MAX_UPLOAD_MB ?? 20),
    ADMIN_OTP: String(config.ADMIN_OTP ?? '123456'),
    OTP_WEBHOOK_URL: String(config.OTP_WEBHOOK_URL ?? ''),
    WHATSAPP_PHONE_NUMBER_ID: String(config.WHATSAPP_PHONE_NUMBER_ID ?? ''),
    WHATSAPP_ACCESS_TOKEN: String(config.WHATSAPP_ACCESS_TOKEN ?? ''),
    WHATSAPP_API_VERSION: String(config.WHATSAPP_API_VERSION ?? 'v20.0'),
    WHATSAPP_TEMPLATE_NAME: String(config.WHATSAPP_TEMPLATE_NAME ?? 'otp_verification'),
    WHATSAPP_TEMPLATE_LANG: String(config.WHATSAPP_TEMPLATE_LANG ?? 'ar'),
    API_PUBLIC_URL: String(config.API_PUBLIC_URL ?? config.APP_URL ?? 'http://localhost:3000'),
    PUBLIC_WEB_URL: String(config.PUBLIC_WEB_URL ?? 'https://vibes.iq'),
    SUPPORT_PHONE: String(config.SUPPORT_PHONE ?? ''),
    ZAIN_CASH_MERCHANT_ID: String(config.ZAIN_CASH_MERCHANT_ID ?? ''),
    ZAIN_CASH_SECRET: String(config.ZAIN_CASH_SECRET ?? ''),
    QI_CARD_TERMINAL_ID: String(config.QI_CARD_TERMINAL_ID ?? ''),
    QI_CARD_SECRET: String(config.QI_CARD_SECRET ?? ''),
  };
}
