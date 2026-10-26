# OdinJobsha

A red-and-white, responsive React + TypeScript job marketplace foundation for genuine jobs and SIWES placements. This is a fresh project scaffold; it does not connect to or modify any previous website.

## Current implementation

- Responsive home, category links, job search/filter, SIWES listing, opportunity details, employer information, pricing, contact, about, draft privacy/terms, authentication, and dashboard pages.
- Supabase client integration using public URL + anon/publishable key only.
- Supabase SQL schema for profiles, employers, jobs, SIWES placements, applications, private CV metadata, payments, subscriptions, featured listings, notifications, audit logs and support messages.
- Initial RLS policies and a private `private-cvs` storage bucket.
- Starter Paystack initialization/webhook Edge Functions. Payment integration is **not production-ready until the TODOs below are completed and tested**.
- Netlify SPA routing configuration.

## Important honesty / launch status

This package is a deployable MVP foundation, not a fully production-ready recruitment business. No real vacancies are bundled because none have been independently verified for this build. The site deliberately shows empty states until a fresh Supabase project is connected and approved listings exist. No Netlify site or Supabase project has been created from this environment, and no external account was accessed.

## Requirements

- Node.js 20+ and npm
- A new Supabase project
- Your existing Netlify account, to create a **new** site
- Paystack business account and eligibility/verification checks before taking payments

## Run locally

1. Extract the ZIP.
2. In the project folder run `npm install`.
3. Copy `.env.example` to `.env.local`.
4. Add your new Supabase project's Project URL and publishable anon key.
5. Run `npm run dev`.
6. Run `npm run build` to type-check and create `dist/`.

Never put the Supabase service-role key, Paystack secret key, webhook secret, or other privileged secret in `.env.local`, a `VITE_` variable, Git, or frontend source.

## Supabase setup

1. Create a completely new Supabase project. Do not select an old project.
2. In SQL Editor, run `supabase/migrations/001_initial_schema.sql`.
3. Copy the project URL and publishable/anon key into `.env.local` and later into Netlify environment variables.
4. In Authentication settings, configure the production Site URL and allowed redirect URLs after Netlify gives you the new URL.
5. Email confirmation and SMTP settings should be configured before public launch.
6. Verify the schema/RLS with two test accounts (a job seeker and employer). Test direct API access, not just the UI.
7. To make an administrator, register your own account, find its UUID in Supabase Auth, then manually promote only that UUID from the SQL editor:
   `update public.profiles set role='admin' where id='YOUR-VERIFIED-USER-UUID';`
   Never expose an admin service key in the browser. Do not let a public signup choose its own admin role.
8. Configure admin review workflows before publishing any listing. Employer-created records default to `pending_review`.

### Security hardening required before production

- Review the SQL with a Supabase security expert. In particular, employer updates must not allow an owner to change a listing from `pending_review` to `published`; enforce approval through an admin-only server-side function/RPC with audit logs. The initial policy allows owner updates and is a scaffold, not a final production policy.
- Add private CV signed-download Edge Function: authorize the requesting user as CV owner or employer attached to that application's listing, then issue a short-lived signed URL. The current UI does not yet implement CV upload/download or internal application submission.
- Add server-side application-status transition validation, notification creation, employer dashboard listing management, admin dashboard/approval UI, and audit-log writes.
- Add rate limits, anti-abuse controls, spam protection, file scanning, account deletion/export, consent and retention rules.
- Support form currently needs a logged-in user id to associate messages, or should use a server-side function to rate-limit anonymous submissions.
- Configure a real company verification process and keep employer verification separate from listing approval.
- The `handle_new_user` trigger intentionally assigns all new accounts `job_seeker`. A secure server-side onboarding flow must grant employer role only after appropriate checks; never trust user-editable metadata for privileges.

## Payments

Paystack must be enabled only after confirming current Nigerian merchant/business requirements in the official Paystack dashboard and documentation. PayPal receiving eligibility also requires separate confirmation.

The Edge Function samples are incomplete. Before launch:
- Use server-side price configuration only.
- Insert pending payment rows with a service-role client before redirecting to Paystack.
- Bind every payment to an authenticated employer and exact purpose; validate callback and webhook idempotently.
- Compare provider currency, reference, amount and transaction status; store raw event IDs to prevent replay.
- Add refunds/cancellations and subscription lifecycle handling.
- Never mark payment successful from frontend callback alone.
- Set secrets using `supabase secrets set ...`; do not paste secrets into chat.
- Test only in provider test mode first.

## Deploy to a new Netlify site

1. Create a **new** Git repository named `odinjobsha` or upload the extracted project to a new repository.
2. In Netlify choose Add new site / Import an existing project and select this new repository. Do not open or change the settings of an old site.
3. Build command: `npm run build`; publish directory: `dist`.
4. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in the new site's environment variables.
5. Deploy, then set the new Netlify URL as Supabase Auth Site URL and add it to allowed redirect URLs.
6. Redeploy after environment variable changes.

## Tests performed

Source structure and configuration are included. A real `npm install` / `npm run build`, Supabase RLS integration test, provider webhook test, and live deployment were not run in this environment because external accounts/credentials and a Node build runtime were not available to this file-generation step. Run `npm run build` locally and resolve any errors before deploying.

## Verified opportunity policy

Only add listings when evidence exists. Store source URL, checked date, deadline, application method, and reviewer notes as part of the operational workflow. Do not claim a listing or employer is verified unless the relevant checks were actually completed. Mark expired roles closed/expired and keep job-seeker applications free for ordinary opportunities.
