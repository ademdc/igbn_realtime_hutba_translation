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
| `FLY_API_TOKEN` | Fly.io | Requests certificates for mosques' own domains. Fly sets `FLY_APP_NAME` itself. |
| `HEROKU_API_TOKEN`, `HEROKU_APP_NAME` | Heroku | Registers mosques' own domains with Heroku |

`ADMIN_USERNAME` and `ADMIN_PASSWORD` are no longer used. Create a super admin with:

```bash
bin/rails admin:create EMAIL=you@example.com NAME="Your Name"   # prompts for the password
```

## Production on Fly.io (recommended)

Fly issues and renews certificates for `hutba.app` and every `*.hutba.app` subdomain itself, so there is no Cloudflare. The setup below is done once. After it, new mosques, their subdomains and their own domains go live without any step from us.

1. **App:** The app is `hutba-app` (org `personal`), already set in `fly.toml`.
2. **Database:** `fly postgres create --name hutba-app-db --region fra`, then `fly postgres attach hutba-app-db`. That sets `DATABASE_URL`.
3. **Redis:** `fly redis create` (Upstash, region `fra`). Then run `fly secrets set REDIS_URL=…` with the URL it prints.
4. **Secrets:**
   ```bash
   fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)" SONIOX_API_KEY=… \
     APP_DOMAIN=hutba.app DEFAULT_ACCOUNT_SUBDOMAIN=igbd-nuernberg \
     CONTACT_EMAIL=… MAIL_FROM=… SMTP_ADDRESS=… SMTP_PORT=587 SMTP_USERNAME=… SMTP_PASSWORD=… \
     MONRI_AUTHENTICITY_TOKEN=… MONRI_MERCHANT_KEY=…
   fly secrets set FLY_API_TOKEN="$(fly tokens create deploy -x 87600h)"
   ```
5. **Deploy:** `fly deploy`, then `fly scale count app=1 scheduler=1`.
   - `app` must stay at exactly one machine: the live Soniox connections are kept in its memory.
   - `scheduler` runs `bin/scheduler`: own-domain checks every 10 minutes and billing reminders every hour. Fly has no Heroku Scheduler.
6. **Domain `hutba.app`:**
   - `fly ips allocate-v4 --shared` and `fly ips allocate-v6`
   - `fly certs add hutba.app` and `fly certs add "*.hutba.app"`
   - At the registrar, add the records `fly certs setup "*.hutba.app"` shows:
     - `A` and `AAAA` for `@` and for `*`, with the IPs from `fly ips list`
     - one `CNAME` for `_acme-challenge` (needed for the wildcard certificate)
   - `fly certs check "*.hutba.app"` shows when it's ready, usually within minutes. Renewals are automatic.
7. **Super admin:** `fly ssh console`, then `bin/rails admin:create EMAIL=you@example.com NAME="Your Name"`.
8. **Monri:** in the merchant dashboard, set:
   - Success URL: any mosque's `/dashboard/billing/success`. The app overrides it per mosque over HTTPS.
   - Callback URL: `https://APP_DOMAIN/monri/callback`
   - Test with `MONRI_ENV` unset and Monri's test cards first.
   - Monri has one callback URL, so take payments on one deployment only (the one serving `hutba.app`).
9. **Legal pages:** fill in the placeholders in `app/views/marketing/imprint.html.erb`, `privacy.html.erb` and `terms.html.erb`.

## Production on Heroku (the current Nürnberg app)

The Heroku app keeps running for Nürnberg. It uses the same code: `Procfile` runs migrations on release, and own domains go through the Heroku Platform API.

- **Config vars:** see the table above, plus `HEROKU_API_TOKEN` (`heroku authorizations:create -d "hutba custom domains"`) and `HEROKU_APP_NAME`. Then run `heroku certs:auto:enable`.
- **Heroku Scheduler** (add-on), two jobs:
  - `bin/rails custom_domains:check`, every 10 minutes
  - `bin/rails billing:reminders`, daily
- **Mosque subdomains:** Heroku's certificates (ACM) can't cover `*.hutba.app`. Serve `hutba.app` from Fly, or put Cloudflare in front of Heroku if it ever has to be Heroku.

Fly and Heroku have separate databases. To move Nürnberg to Fly later:
1. Run `fly certs add hutba.igbd-nuernberg.de`, and the same for `hutba.dzamija.net` and `dzuma.dzamija.net`.
2. Point their DNS to the Fly IPs.
3. Set the speaker PIN again in the Fly dashboard.

### How own domains work (automatic)

1. The mosque books "own domain" (€5/month) on the billing page and enters e.g. `hutba.mosque-website.com`.
2. After payment, the app registers the domain with Fly (Machines API certificates) or Heroku (Platform API), depending on where it runs. It shows the mosque the CNAME record to add (in the dashboard and by email).
3. Every 10 minutes the scheduler asks the host whether the certificate has been issued. When it has, the domain goes live: QR codes, posters, emails and TV links switch to it, and the mosque gets an email.
4. If the mosque changes its domain later, the old one keeps working until the new one is live, and is then removed from the host.

The admin page shows the status and the CNAME target. "Live domain (manual override)" is only needed for special cases.

### The original Nürnberg setup

- `hutba.igbd-nuernberg.de` is stored as the custom domain of the `igbd-nuernberg` account, with the domain add-on switched on and no charge. Its QR codes, emails and TV links use that domain.
- `hutba.dzamija.net`, `dzuma.dzamija.net` and the `herokuapp.com` host also reach that account, through `DEFAULT_ACCOUNT_SUBDOMAIN=igbd-nuernberg`. They stay in `config.hosts`.
- The old `/german` links redirect to `/de`.

## How streaming works

1. The speaker panel streams 16 kHz PCM audio over Action Cable (`TranslationChannel`).
2. `SonioxProxyService` opens one Soniox connection per language that has listeners. Connections, Redis keys and streams are scoped per account.
3. Translations are broadcast to `translation:<account_id>:<language>`, which the listener pages subscribe to.
4. Streaming is refused when a trial has expired, a paid year has run out, the account is suspended, or the weekly limit (180 minutes by default) is used up.

Transcripts and audio are never stored or logged.
