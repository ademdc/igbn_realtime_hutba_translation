# Hutba – Setup Guide

Live khutbah translation for mosques, as a multi-tenant B2B app.

- `APP_DOMAIN` (e.g. `hutba.app`) serves the marketing site in `/de`, `/en`, `/fr`, `/nl`, `/bs`, `/tr`, with self-signup.
- Each mosque gets a subdomain (e.g. `dzemat-nurnberg.hutba.app`):
  - `/` is the speaker panel.
  - `/de`, `/en`, … are the listener pages.
  - `/dashboard` is the owner area: languages, QR codes, poster, team, billing.
- `/admin` is the super-admin panel.

## Prerequisites

- Ruby 3.4.9
- PostgreSQL
- Redis (production)
- Node.js 20

## Local development

```bash
bundle install
npm install
bin/rails db:prepare db:seed
PORT=3020 bin/rails server -p 3020   # plus `npm run build -- --watch` for JS
```

`*.localhost` resolves to your machine in Chrome and Firefox, so no hosts file changes are needed. The seed creates these logins (password `password1234`):

| Who | URL |
|---|---|
| Marketing site | http://localhost:3020/de |
| Mosque owner `owner@demo.test` | http://demo.localhost:3020/login |
| Imam `imam@demo.test` (speaker only) | http://demo.localhost:3020/login |
| Owner of the original tenant `owner@igbd.test` | http://igbd-nuernberg.localhost:3020/login |
| Super admin `admin@hutba.test` | http://localhost:3020/admin/login |

Emails are not sent in development. Open http://localhost:3020/letter_opener to read them.

Run the tests with `bin/rails test`.

## Environment variables

| Variable | Required | Purpose |
|---|---|---|
| `SONIOX_API_KEY` | yes | Speech recognition and translation |
| `SONIOX_MODEL` | optional | Real-time model, default `stt-rt-v5` (see soniox.com/docs/stt/models) |
| `APP_DOMAIN` | production | Apex domain, e.g. `hutba.app` (default `localhost`) |
| `DEFAULT_ACCOUNT_SUBDOMAIN` | optional | Hosts that are neither `APP_DOMAIN` nor a custom domain go to this account. Set it to `igbd-nuernberg` so `hutba.dzamija.net`, `dzuma.dzamija.net` and `hutba.igbd-nuernberg.de` keep working. |
| `SPEAKER_PIN` | migration only | Copied (hashed) into the `igbd-nuernberg` account by the multi-tenancy migration. After that, PINs are set per mosque in the dashboard. |
| `CONTACT_EMAIL`, `MAIL_FROM` | production | Sender and contact address |
| `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | production | Any SMTP provider (Postmark, Resend, Brevo, …) |
| `MONRI_AUTHENTICITY_TOKEN`, `MONRI_MERCHANT_KEY` | for payments | From the Monri merchant dashboard |
| `MONRI_ENV` | for payments | `production` for live payments. Anything else uses `ipgtest.monri.com`. |
| `REDIS_URL` | production | Action Cable, Soniox language state, rate limiting |

`ADMIN_USERNAME` and `ADMIN_PASSWORD` are no longer used. Create a super admin with:

```bash
bin/rails admin:create EMAIL=you@example.com NAME="Your Name"   # prompts for the password
```

## Production checklist (Heroku)

1. **Domain and DNS:**
   - Run `heroku domains:add hutba.app` and `heroku domains:add "*.hutba.app"`.
   - Point both at the DNS targets Heroku prints (CNAME/ALIAS).
   - Heroku's automatic certificates (ACM) don't cover wildcard domains. Use one of these for `*.hutba.app`:
     - **Cloudflare in front (easiest):** proxy the apex and the wildcard through Cloudflare, set SSL mode to "Full (strict)", and upload a Cloudflare Origin certificate for `hutba.app` and `*.hutba.app` with `heroku certs:add`.
     - **Let's Encrypt:** get a wildcard certificate (certbot with a DNS challenge) and upload it with `heroku certs:add`. It has to be renewed every 90 days.
2. **Config vars:** `heroku config:set APP_DOMAIN=hutba.app DEFAULT_ACCOUNT_SUBDOMAIN=igbd-nuernberg …` (see the table above).
3. **Monri:** in the merchant dashboard, set:
   - Success URL: any mosque's `/dashboard/billing/success`. The app overrides it per mosque over HTTPS.
   - Callback URL: `https://APP_DOMAIN/monri/callback`
   - Test with `MONRI_ENV` unset and Monri's test cards first.
4. **Daily reminders:** add the Heroku Scheduler add-on and schedule `bin/rails billing:reminders` daily. It sends trial-ending emails at 14, 3 and 0 days, and renewal emails at 30, 7 and 0 days.
5. **Custom domains** (paid add-on, €5/month): when a mosque pays, `CONTACT_EMAIL` gets an email with the requested domain.
   1. Run `heroku domains:add hutba.mosque-website.com`.
   2. Send the mosque the DNS target Heroku shows, for their CNAME record.
   3. Once DNS resolves, enter the domain as "Custom domain (live)" on the account page in `/admin`. ACM issues the certificate automatically for single domains.
   Requests to a domain only pass the host check once an account uses it.
6. **Legal pages:** fill in the placeholders in `app/views/marketing/imprint.html.erb`, `privacy.html.erb` and `terms.html.erb`.

### The original Nürnberg setup

- `hutba.igbd-nuernberg.de` is stored as the custom domain of the `igbd-nuernberg` account, with the domain add-on switched on and no charge. Its QR codes, emails and TV links use that domain.
- `hutba.dzamija.net`, `dzuma.dzamija.net` and the `herokuapp.com` host also reach that account, through `DEFAULT_ACCOUNT_SUBDOMAIN=igbd-nuernberg`. They stay in `config.hosts`.
- The old `/german` links redirect to `/de`.

`fly.toml` and the `Dockerfile` are from an earlier Fly.io setup and aren't used by Heroku.

## How streaming works

1. The speaker panel streams 16 kHz PCM audio over Action Cable (`TranslationChannel`).
2. `SonioxProxyService` opens one Soniox connection per language that has listeners. Connections, Redis keys and streams are scoped per account.
3. Translations are broadcast to `translation:<account_id>:<language>`, which the listener pages subscribe to.
4. Streaming is refused when a trial has expired, a paid year has run out, the account is suspended, or the weekly limit (180 minutes by default) is used up.

Transcripts and audio are never stored or logged.
