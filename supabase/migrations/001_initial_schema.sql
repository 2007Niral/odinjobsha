-- OdinJobsha initial schema. Apply to a BRAND-NEW Supabase project.
create extension if not exists pgcrypto;

create type public.app_role as enum ('job_seeker','employer','admin');
create type public.listing_status as enum ('draft','pending_review','published','rejected','closed','expired');
create type public.application_status as enum ('submitted','reviewing','shortlisted','rejected','withdrawn','hired');
create type public.verification_status as enum ('unverified','pending','verified','rejected');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  location text,
  headline text,
  bio text,
  skills text[] not null default '{}',
  education jsonb not null default '[]'::jsonb,
  experience jsonb not null default '[]'::jsonb,
  role public.app_role not null default 'job_seeker',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.employers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  company_name text not null,
  slug text unique,
  website text,
  industry text,
  description text,
  headquarters text,
  logo_path text,
  verification_status public.verification_status not null default 'pending',
  created_at timestamptz not null default now()
);
create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.employers(id) on delete cascade,
  title text not null,
  category text not null,
  location text,
  employment_type text,
  work_mode text,
  experience_level text,
  salary_text text,
  description text not null,
  requirements text,
  application_method text not null default 'external' check(application_method in ('external','internal')),
  application_url text,
  deadline date,
  status public.listing_status not null default 'pending_review',
  verification_status public.verification_status not null default 'unverified',
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (application_method <> 'external' or application_url is not null)
);
create table public.siwes_placements (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.employers(id) on delete cascade,
  title text not null,
  category text not null default 'SIWES placements',
  eligible_courses text[] not null default '{}',
  industry text,
  location text,
  duration_text text,
  eligibility_requirements text,
  description text not null,
  application_method text not null default 'external' check(application_method in ('external','internal')),
  application_url text,
  deadline date,
  status public.listing_status not null default 'pending_review',
  verification_status public.verification_status not null default 'unverified',
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (application_method <> 'external' or application_url is not null)
);
create table public.cv_documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null unique,
  original_filename text not null,
  mime_type text not null,
  size_bytes bigint not null check(size_bytes > 0 and size_bytes <= 10485760),
  created_at timestamptz not null default now()
);
create table public.applications (
  id uuid primary key default gen_random_uuid(),
  applicant_id uuid not null references public.profiles(id) on delete cascade,
  job_id uuid references public.jobs(id) on delete cascade,
  siwes_placement_id uuid references public.siwes_placements(id) on delete cascade,
  listing_type text not null check(listing_type in ('job','siwes')),
  cv_document_id uuid references public.cv_documents(id) on delete set null,
  cover_letter text,
  status public.application_status not null default 'submitted',
  employer_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((listing_type='job' and job_id is not null and siwes_placement_id is null) or
         (listing_type='siwes' and siwes_placement_id is not null and job_id is null)),
  unique(applicant_id, job_id),
  unique(applicant_id, siwes_placement_id)
);
create table public.employer_subscriptions (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.employers(id) on delete cascade,
  plan_code text not null,
  status text not null default 'pending' check(status in ('pending','active','past_due','cancelled','expired')),
  starts_at timestamptz,
  ends_at timestamptz,
  provider text,
  provider_reference text unique,
  created_at timestamptz not null default now()
);
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid references public.employers(id) on delete set null,
  payer_id uuid not null references public.profiles(id),
  purpose text not null check(purpose in ('job_post','featured_listing','subscription','recruitment_service')),
  amount_kobo bigint not null check(amount_kobo > 0),
  currency text not null default 'NGN',
  provider text not null check(provider in ('paystack','paypal','bank_transfer')),
  provider_reference text unique,
  status text not null default 'pending' check(status in ('pending','success','failed','refunded','cancelled')),
  metadata jsonb not null default '{}'::jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.featured_listings (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  payment_id uuid references public.payments(id),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'pending' check(status in ('pending','active','ended','cancelled')),
  created_at timestamptz not null default now(),
  check(ends_at > starts_at)
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.admin_activity_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_table text not null,
  target_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.support_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  email text not null,
  message text not null check(char_length(message) between 10 and 5000),
  status text not null default 'open' check(status in ('open','in_progress','closed')),
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'); $$;
create or replace function public.owns_employer(target uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.employers e where e.id=target and e.owner_id=auth.uid()); $$;

-- Auto-create a least-privilege job-seeker profile. Requested role in user metadata is NOT trusted.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$ begin
 insert into public.profiles(id,full_name,role)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),'job_seeker')
 on conflict(id) do nothing;
 return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.employers enable row level security;
alter table public.jobs enable row level security;
alter table public.siwes_placements enable row level security;
alter table public.cv_documents enable row level security;
alter table public.applications enable row level security;
alter table public.employer_subscriptions enable row level security;
alter table public.payments enable row level security;
alter table public.featured_listings enable row level security;
alter table public.notifications enable row level security;
alter table public.admin_activity_logs enable row level security;
alter table public.support_messages enable row level security;

create policy "profiles read self or admin" on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
create policy "profiles update self or admin" on public.profiles for update to authenticated using(id=auth.uid() or public.is_admin()) with check(id=auth.uid() or public.is_admin());
create policy "employers public approved profiles" on public.employers for select using(verification_status='verified' or owner_id=auth.uid() or public.is_admin());
create policy "employers create self" on public.employers for insert to authenticated with check(owner_id=auth.uid() and not public.is_admin());
create policy "employers owner update" on public.employers for update to authenticated using(owner_id=auth.uid() or public.is_admin()) with check(owner_id=auth.uid() or public.is_admin());
create policy "jobs public published" on public.jobs for select using(status='published' and (deadline is null or deadline>=current_date) or public.owns_employer(employer_id) or public.is_admin());
create policy "jobs employer create" on public.jobs for insert to authenticated with check(public.owns_employer(employer_id) and status='pending_review');
create policy "jobs employer update own unapproved" on public.jobs for update to authenticated using(public.owns_employer(employer_id) or public.is_admin()) with check(public.owns_employer(employer_id) or public.is_admin());
create policy "siwes public published" on public.siwes_placements for select using(status='published' and (deadline is null or deadline>=current_date) or public.owns_employer(employer_id) or public.is_admin());
create policy "siwes employer create" on public.siwes_placements for insert to authenticated with check(public.owns_employer(employer_id) and status='pending_review');
create policy "siwes employer update own" on public.siwes_placements for update to authenticated using(public.owns_employer(employer_id) or public.is_admin()) with check(public.owns_employer(employer_id) or public.is_admin());
create policy "cv owner and admin" on public.cv_documents for select to authenticated using(owner_id=auth.uid() or public.is_admin());
create policy "cv owner insert" on public.cv_documents for insert to authenticated with check(owner_id=auth.uid());
create policy "cv owner delete" on public.cv_documents for delete to authenticated using(owner_id=auth.uid() or public.is_admin());
create policy "applications applicant or listing employer" on public.applications for select to authenticated using(applicant_id=auth.uid() or public.is_admin() or (job_id is not null and exists(select 1 from public.jobs j where j.id=job_id and public.owns_employer(j.employer_id))) or (siwes_placement_id is not null and exists(select 1 from public.siwes_placements s where s.id=siwes_placement_id and public.owns_employer(s.employer_id))));
create policy "applications applicant submit" on public.applications for insert to authenticated with check(applicant_id=auth.uid() and status='submitted' and ((job_id is not null and exists(select 1 from public.jobs j where j.id=job_id and j.status='published')) or (siwes_placement_id is not null and exists(select 1 from public.siwes_placements s where s.id=siwes_placement_id and s.status='published'))));
create policy "application status employer or admin" on public.applications for update to authenticated using(public.is_admin() or (job_id is not null and exists(select 1 from public.jobs j where j.id=job_id and public.owns_employer(j.employer_id))) or (siwes_placement_id is not null and exists(select 1 from public.siwes_placements s where s.id=siwes_placement_id and public.owns_employer(s.employer_id)))) with check(public.is_admin() or (job_id is not null and exists(select 1 from public.jobs j where j.id=job_id and public.owns_employer(j.employer_id))) or (siwes_placement_id is not null and exists(select 1 from public.siwes_placements s where s.id=siwes_placement_id and public.owns_employer(s.employer_id))));
create policy "subscription employer owner read" on public.employer_subscriptions for select to authenticated using(public.is_admin() or public.owns_employer(employer_id));
create policy "payments payer or admin read" on public.payments for select to authenticated using(payer_id=auth.uid() or public.is_admin() or (employer_id is not null and public.owns_employer(employer_id)));
create policy "featured public active or admin" on public.featured_listings for select using(status='active' or public.is_admin());
create policy "notifications owner read" on public.notifications for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy "notifications owner update" on public.notifications for update to authenticated using(user_id=auth.uid() or public.is_admin()) with check(user_id=auth.uid() or public.is_admin());
create policy "admin logs admin only" on public.admin_activity_logs for select to authenticated using(public.is_admin());
create policy "support insert public" on public.support_messages for insert with check(char_length(message) between 10 and 5000);
create policy "support owner read" on public.support_messages for select to authenticated using(user_id=auth.uid() or public.is_admin());

-- Private CV bucket. Never set this bucket to public.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('private-cvs','private-cvs',false,10485760,array['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict(id) do nothing;
create policy "CV files owner folder read" on storage.objects for select to authenticated using(bucket_id='private-cvs' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "CV files owner folder upload" on storage.objects for insert to authenticated with check(bucket_id='private-cvs' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "CV files owner folder delete" on storage.objects for delete to authenticated using(bucket_id='private-cvs' and (storage.foldername(name))[1]=auth.uid()::text);

-- Security notes:
-- 1) Never let users set profiles.role to admin. Promote the first admin manually in the SQL editor
--    after verifying the user's auth UUID: update public.profiles set role='admin' where id='...';
-- 2) Payment records and listing approvals must be written by trusted server-side functions/admin actions.
-- 3) Before production, add a dedicated admin-only approval RPC/Edge Function and audit all privileged paths.
