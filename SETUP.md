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
| `HEROKU_API_TOKEN`, `HEROKU_APP_NAME` | production | Registers mosques' own domains with Heroku automatically |

`ADMIN_USERNAME` and `ADMIN_PASSWORD` are no longer used. Create a super admin with:

```bash
bin/rails admin:create EMAIL=you@example.com NAME="Your Name"   # prompts for the password
```

## Production checklist (Heroku)

Everything below is a one-time setup. After it, new mosques, their subdomains and their own domains all go live automatically, with no approval or manual step from us.

1. **Cloudflare in front of `hutba.app`** (this gives the mosque subdomains their certificate):
   - Add `hutba.app` to Cloudflare (free plan) and switch the nameservers at your registrar.
   - Run `heroku domains:add hutba.app` and `heroku domains:add "*.hutba.app"`.
   - In Cloudflare DNS, create proxied CNAME records: `@` and `*`, each pointing to the DNS target Heroku printed for it.
   - Set SSL/TLS mode to **Full**. Cloudflare's free certificate covers `hutba.app` and `*.hutba.app` and renews itself.
   - Heroku's own certificates (ACM) can't cover wildcards, and ACM can't be mixed with uploaded certificates, so this is the setup that keeps everything automatic.
2. **Automatic certificates for mosques' own domains:**
   - Run `heroku certs:auto:enable`.
   - Create an API token with `heroku authorizations:create -d "hutba custom domains"`.
   - Set `HEROKU_API_TOKEN` and `HEROKU_APP_NAME`.
3. **Config vars:** `heroku config:set APP_DOMAIN=hutba.app DEFAULT_ACCOUNT_SUBDOMAIN=igbd-nuernberg …` (see the table above).
4. **Heroku Scheduler** (add-on), two jobs:
   - `bin/rails custom_domains:check`, every 10 minutes
   - `bin/rails billing:reminders`, daily
5. **Monri:** in the merchant dashboard, set:
   - Success URL: any mosque's `/dashboard/billing/success`. The app overrides it per mosque over HTTPS.
   - Callback URL: `https://APP_DOMAIN/monri/callback`
   - Test with `MONRI_ENV` unset and Monri's test cards first.
6. **Legal pages:** fill in the placeholders in `app/views/marketing/imprint.html.erb`, `privacy.html.erb` and `terms.html.erb`.

### How own domains work (automatic)

1. The mosque books "own domain" (€5/month) on the billing page and enters e.g. `hutba.mosque-website.com`.
2. After payment, the app registers the domain with Heroku through the Platform API. It shows the mosque the CNAME record to add (in the dashboard and by email).
3. Every 10 minutes `custom_domains:check` asks Heroku whether the certificate has been issued. When it has, the domain goes live: QR codes, posters, emails and TV links switch to it, and the mosque gets an email.
4. If the mosque changes its domain later, the old one keeps working until the new one is live, and is then removed from Heroku.

The admin page shows the status and the CNAME target. "Live domain (manual override)" is only needed for special cases.

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
