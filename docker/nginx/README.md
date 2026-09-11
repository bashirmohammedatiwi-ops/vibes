# Nginx — VIBES

## المسارات

| المسار | الوجهة |
|--------|--------|
| `/api` | NestJS `:3000` |
| `/api/docs` | Swagger |
| `/health` | Health check |
| `/admin` | Next.js admin `:3001` |
| `/media` | ملفات الصور المحلية |

## SSL (Certbot) على الـ VPS

بعد توجيه الدومين إلى الـ VPS:

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d api.your-domain.com
```

أو استخدم Cloudflare Flexible/Full SSL أمام Nginx بدون Certbot في البداية.

ضع شهاداتك في `docker/nginx/certs/` وحدّث `nginx.conf` بإضافة `listen 443 ssl` عند الجاهزية.
