# PNU Halloween Event — GitHub Pages + Supabase Analytics

## Local setup

1. In Supabase, create a project and open **SQL Editor**.
2. Run [`supabase.sql`](./supabase.sql).
3. Copy `config.example.js` to `config.js` and enter the Project URL and **anon/public** key (never the `service_role` key).
4. Open `index.html` with a local static server, for example `npx serve .`.

`config.js` is excluded from Git. For GitHub Pages, create it in the repository only with the public anon key, or use a deployment workflow that writes it from GitHub Actions secrets. The SQL policies permit browser inserts but never browser reads.

## GitHub Pages

Push these files to a GitHub repository, then in **Settings → Pages** select **Deploy from a branch**, choose `main` and `/ (root)`. GitHub Pages will serve `index.html` without a build step.

For a production event, configure a small Supabase Edge Function or CAPTCHA before exposing the registration endpoint to reduce automated submissions.

## Metrics

- `event_events`: every landing view, CTA/button click, FAQ expansion, and funnel step, identified by a random browser UUID (no advertising cookie).
- `event_registrations`: completed participant applications.
- `event_funnel`: visitor → CTA → application start → completion counts and each stage's drop-off rate.

Run `select * from public.event_funnel;` in Supabase SQL Editor. The button-click query is at the end of [`supabase.sql`](./supabase.sql).

The current form uses `purchase_completed` as the successful free-registration conversion. If payment is added, emit that event only after the payment provider's verified success callback.

## Growth analytics additions

- `event_button_clicks` reports total and unique clicks for each CTA and program interaction.
- First-page events store UTM campaign parameters, referrer host, and viewport size; registration PII is never copied into analytics events.
- GitHub Pages can be deployed through `.github/workflows/deploy-pages.yml`: select **GitHub Actions** in repository **Settings → Pages**, then push `main`.

For GitHub Pages deployments, add `SUPABASE_URL` and `EVENT_SLUG` as repository **Variables**, and add the anon/public key as the `SUPABASE_ANON_KEY` repository **Secret**. The workflow generates the ignored `config.js` only in the deployment artifact.

Before public operation, add a privacy notice and protect the public registration endpoint with CAPTCHA or an Edge Function validation layer.
