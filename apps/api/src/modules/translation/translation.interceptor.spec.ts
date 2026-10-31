import { CallHandler, ExecutionContext, NotFoundException } from '@nestjs/common';
import { firstValueFrom, of, throwError } from 'rxjs';
import { TranslationInterceptor } from './translation.interceptor';
import { TranslationService } from './translation.service';

function setup(known: Record<string, string> = {}) {
  const lookup = jest.fn(async (texts: Set<string>) => {
    const out = new Map<string, string>();
    texts.forEach((t) => known[t] && out.set(t, known[t]));
    return out;
  });
  const interceptor = new TranslationInterceptor({ lookup } as unknown as TranslationService);
  const context = (url: string, lang = 'en', method = 'GET') =>
    ({
      getType: () => 'http',
      switchToHttp: () => ({
        getRequest: () => ({ method, originalUrl: url, headers: { 'accept-language': lang } }),
      }),
    }) as unknown as ExecutionContext;
  const run = (ctx: ExecutionContext, data: unknown) =>
    firstValueFrom(interceptor.intercept(ctx, { handle: () => of(data) } as CallHandler));
  return { interceptor, context, run, lookup };
}

describe('TranslationInterceptor', () => {
  it('translates content and falls back to Arabic for unknown text', async () => {
    const { context, run } = setup({ 'مزرعة الورد': 'Al-Ward Farm' });
    await expect(
      run(context('/api/properties'), [{ name: 'مزرعة الورد', summary: 'نص جديد' }]),
    ).resolves.toEqual([{ name: 'Al-Ward Farm', summary: 'نص جديد' }]);
  });

  it('prefers the manual English field', async () => {
    const { context, run, lookup } = setup();
    await expect(
      run(context('/api/cities'), { nameAr: 'بغداد', nameEn: 'Baghdad' }),
    ).resolves.toEqual({ nameAr: 'Baghdad', nameEn: 'Baghdad' });
    expect(lookup).not.toHaveBeenCalled();
  });

  it('keeps people names, slugs and keywords as written', async () => {
    const { context, run } = setup({ سارة: 'Sara', ورد: 'Rose' });
    const data = { author: { name: 'سارة' }, slug: 'ورد', keywords: ['ورد'] };
    await expect(run(context('/api/reviews'), data)).resolves.toEqual(data);
  });

  it('leaves browsers and editing routes alone', async () => {
    const { context, run, lookup } = setup({ مزرعة: 'Farm' });
    const data = { name: 'مزرعة' };
    await expect(run(context('/api/properties', 'en-US,en;q=0.9'), data)).resolves.toEqual(data);
    await expect(run(context('/api/provider/properties'), data)).resolves.toEqual(data);
    await expect(run(context('/api/properties', 'en', 'POST'), data)).resolves.toEqual(data);
    expect(lookup).not.toHaveBeenCalled();
  });

  it('translates error messages on any route', async () => {
    const { interceptor, context } = setup({ 'غير موجود': 'Not found' });
    const result = firstValueFrom(
      interceptor.intercept(context('/api/provider/x', 'en', 'POST'), {
        handle: () => throwError(() => new NotFoundException('غير موجود')),
      } as CallHandler),
    );
    await expect(result).rejects.toMatchObject({
      response: expect.objectContaining({ message: 'Not found' }),
      status: 404,
    });
  });
});
