import {
  CallHandler,
  ExecutionContext,
  HttpException,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, catchError, from, mergeMap, throwError } from 'rxjs';
import { TranslationService } from './translation.service';

const ARABIC = /[؀-ۿ]/;

/** مسارات لا تُترجم ردودها: نماذج تحرير (الحفظ يجب أن يبقى بالعربية) ومحادثات. */
const UNTRANSLATED_ROUTES =
  /^\/api\/(admin|staff|provider|auth|conversations|calls|payments|media|users|devices|dashboard|reports)(\/|$|\?)/;

/** قيم ليست نصاً للعرض، أو أسماء أشخاص تبقى كما كتبها أصحابها. */
const SKIP_KEYS =
  /^(id|.*Id|slug|phone.*|email|.*[uU]rl|.*[tT]oken|code|fullName|firstName|lastName|displayName|userName|username|customerName|guestName|keywords|aliases|synonyms)$/;

/** كائنات تحمل اسم شخص في الحقل name. */
const PERSON_PARENTS = /^(user|customer|author|sender|guest|owner|staff|createdBy|reviewer)$/;

/** حقول يكتب لها الفريق ترجمة يدوية: تتقدم على الترجمة الآلية. */
const MANUAL_FIELDS: Record<string, string> = {
  name: 'nameEn',
  nameAr: 'nameEn',
  description: 'descriptionEn',
};

type Json = Record<string, unknown>;

function collect(value: unknown, key: string, parent: string, out: Set<string>) {
  if (typeof value === 'string') {
    if (ARABIC.test(value) && !isSkipped(key, parent)) out.add(value);
  } else if (Array.isArray(value)) {
    value.forEach((item) => collect(item, key, parent, out));
  } else if (value && typeof value === 'object') {
    for (const [k, v] of Object.entries(value as Json)) {
      if (!hasManual(value as Json, k)) collect(v, k, key, out);
    }
  }
}

function apply(value: unknown, key: string, parent: string, map: Map<string, string>): unknown {
  if (typeof value === 'string') {
    return isSkipped(key, parent) ? value : (map.get(value) ?? value);
  }
  if (Array.isArray(value)) return value.map((item) => apply(item, key, parent, map));
  if (value && typeof value === 'object') {
    const obj = value as Json;
    return Object.fromEntries(
      Object.entries(obj).map(([k, v]) => [
        k,
        hasManual(obj, k) ? obj[MANUAL_FIELDS[k]] : apply(v, k, key, map),
      ]),
    );
  }
  return value;
}

const isSkipped = (key: string, parent: string) =>
  SKIP_KEYS.test(key) || (key === 'name' && PERSON_PARENTS.test(parent));

const hasManual = (obj: Json, key: string) => {
  const manual = MANUAL_FIELDS[key];
  return Boolean(manual && typeof obj[manual] === 'string' && obj[manual]);
};

/**
 * يترجم ردود القراءة ورسائل الخطأ لتطبيق الإنجليزية.
 * يعمل فقط مع `Accept-Language: en` الحرفية التي يرسلها التطبيق: المتصفحات
 * ترسل صيغة أطول (en-US,en;q=0.9) فيبقى الموقع ولوحة التحكم بالعربية.
 */
@Injectable()
export class TranslationInterceptor implements NestInterceptor {
  constructor(private readonly translations: TranslationService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();
    const req = context.switchToHttp().getRequest<{
      method: string;
      originalUrl: string;
      headers: Record<string, unknown>;
    }>();
    if (req.headers['accept-language'] !== 'en') return next.handle();

    const translatable = req.method === 'GET' && !UNTRANSLATED_ROUTES.test(req.originalUrl);
    return next.handle().pipe(
      mergeMap((data) => (translatable ? from(this.translate(data)) : from([data]))),
      catchError((err: unknown) =>
        err instanceof HttpException
          ? from(this.translateError(err)).pipe(mergeMap((e) => throwError(() => e)))
          : throwError(() => err),
      ),
    );
  }

  private async translate(data: unknown): Promise<unknown> {
    const texts = new Set<string>();
    collect(data, '', '', texts);
    try {
      const found = texts.size ? await this.translations.lookup(texts) : new Map<string, string>();
      return apply(data, '', '', found);
    } catch {
      return data;
    }
  }

  private async translateError(err: HttpException): Promise<HttpException> {
    const body = err.getResponse();
    return new HttpException((await this.translate(body)) as string | Json, err.getStatus());
  }
}
