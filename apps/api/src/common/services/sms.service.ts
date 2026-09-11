import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  constructor(private readonly config: ConfigService) {}

  async sendOtp(phone: string, code: string): Promise<{ sent: boolean; provider: string }> {
    const provider = this.config.get<string>('OTP_PROVIDER', 'development');

    if (provider === 'development' || provider === 'console') {
      this.logger.log(`[OTP] ${phone} → ${code}`);
      return { sent: true, provider };
    }

    if (provider === 'whatsapp') {
      return this.sendWhatsapp(phone, code);
    }

    const webhook = this.config.get<string>('OTP_WEBHOOK_URL');
    if (provider === 'webhook' && webhook) {
      const res = await fetch(webhook, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, code, message: `رمز VIBES: ${code}` }),
      });
      if (!res.ok) {
        this.logger.error(`OTP webhook failed: ${res.status}`);
        return { sent: false, provider };
      }
      return { sent: true, provider: 'webhook' };
    }

    this.logger.warn(`OTP provider "${provider}" not configured — code generated but not sent`);
    return { sent: false, provider };
  }

  /**
   * Sends a free-text WhatsApp message. Works inside the 24h
   * customer-service window; outside it Meta requires an approved template —
   * callers should treat failures as best-effort notification only.
   */
  async sendWhatsappText(phone: string, text: string): Promise<{ sent: boolean; provider: string }> {
    const phoneNumberId = this.config.get<string>('WHATSAPP_PHONE_NUMBER_ID');
    const token = this.config.get<string>('WHATSAPP_ACCESS_TOKEN');
    if (!phoneNumberId || !token) {
      return { sent: false, provider: 'whatsapp' };
    }
    const apiVersion = this.config.get<string>('WHATSAPP_API_VERSION', 'v20.0');
    const to = phone.replace(/^\+/, '').replace(/\s+/g, '');
    try {
      const res = await fetch(`https://graph.facebook.com/${apiVersion}/${phoneNumberId}/messages`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ messaging_product: 'whatsapp', to, type: 'text', text: { body: text } }),
      });
      if (!res.ok) {
        const body = await res.text().catch(() => '');
        this.logger.error(`WhatsApp text failed (${res.status}): ${body}`);
        return { sent: false, provider: 'whatsapp' };
      }
      return { sent: true, provider: 'whatsapp' };
    } catch (err) {
      this.logger.error(`WhatsApp text error: ${(err as Error).message}`);
      return { sent: false, provider: 'whatsapp' };
    }
  }

  /**
   * Sends the OTP via the WhatsApp Cloud API (Meta Graph API). Requires an
   * approved message template since this is a business-initiated message —
   * plain text only works inside a 24h customer-initiated session window.
   */
  private async sendWhatsapp(phone: string, code: string): Promise<{ sent: boolean; provider: string }> {
    const phoneNumberId = this.config.get<string>('WHATSAPP_PHONE_NUMBER_ID');
    const token = this.config.get<string>('WHATSAPP_ACCESS_TOKEN');

    if (!phoneNumberId || !token) {
      this.logger.warn('WhatsApp OTP not configured (missing WHATSAPP_PHONE_NUMBER_ID / WHATSAPP_ACCESS_TOKEN)');
      return { sent: false, provider: 'whatsapp' };
    }

    const apiVersion = this.config.get<string>('WHATSAPP_API_VERSION', 'v20.0');
    const templateName = this.config.get<string>('WHATSAPP_TEMPLATE_NAME', 'otp_verification');
    const templateLang = this.config.get<string>('WHATSAPP_TEMPLATE_LANG', 'ar');
    const to = phone.replace(/^\+/, '').replace(/\s+/g, '');

    try {
      const res = await fetch(`https://graph.facebook.com/${apiVersion}/${phoneNumberId}/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to,
          type: 'template',
          template: {
            name: templateName,
            language: { code: templateLang },
            // Matches Meta's standard authentication template: a single body
            // placeholder for the code. Add more components here if your
            // approved template also has a "copy code" button, etc.
            components: [{ type: 'body', parameters: [{ type: 'text', text: code }] }],
          },
        }),
      });

      if (!res.ok) {
        const body = await res.text().catch(() => '');
        this.logger.error(`WhatsApp OTP failed (${res.status}): ${body}`);
        return { sent: false, provider: 'whatsapp' };
      }

      return { sent: true, provider: 'whatsapp' };
    } catch (err) {
      this.logger.error(`WhatsApp OTP request error: ${(err as Error).message}`);
      return { sent: false, provider: 'whatsapp' };
    }
  }
}
