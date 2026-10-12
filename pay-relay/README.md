# EL-Saver Pay Relay

Tiny Android app for the MERCHANT's phone (yours). It turns DANA
money-in notifications into signed webhooks so the EL-Saver server can
auto-activate the matching pending premium order — no payment gateway
needed.

## How it works

```
DANA app notification ("Dana masuk Rp15.027")
  → NotificationListenerService (package id.dana)
  → parse unique whole-rupiah amount
  → POST {gross_amount, timestamp, signature} to
    https://api.ekalliptus.com/cookie-sync/premium/webhook
  → server matches a fresh (<48h) pending order by amount → license activated
```

Signature: HMAC-SHA256 over `"|<amount>|<unix-seconds>"` with the same
`WEBHOOK_SECRET` as the server (`/opt/anrsaver/.env` on the VPS).
Duplicate notifications of the same amount within 10 minutes are skipped.

## Setup (once, on the merchant phone)

1. Install the APK (built release, debug-signed).
2. Open "EL-Saver Pay Relay" → tap **1. Izinkan Akses Notifikasi** →
   enable it for this app.
3. Tap **2. Kirim Webhook Tes** — the log should show
   `404 {"detail":"Order tidak ditemukan"}` (that is SUCCESS: the
   signature was accepted, no order matches the test amount).
4. Keep the phone charged & connected; DANA notifications must be ON.

## Build (secret is NOT committed)

```
cd pay-relay
../android/gradlew.bat assembleRelease -PwebhookSecret=<value from /opt/anrsaver/.env>
```

Output: `app/build/outputs/apk/release/app-release.apk`.

## Notes

- The server side already supports this contract (amount-only matching,
  replay-protected timestamps); see `server/cookie_sync.py premium_webhook`.
- If amounts stop matching: webhook amount must equal a pending order's
  unique gross (whole rupiah, <48h old).
