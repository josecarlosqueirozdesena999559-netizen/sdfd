create extension if not exists pgcrypto;

create or replace function public.current_app_user_id()
returns text
language sql
stable
as $$
    select u.id::text
    from public.usuarios u
    where u.auth_user_id::text = auth.uid()::text
    limit 1
$$;

create table if not exists public.user_push_tokens (
    id uuid primary key default gen_random_uuid(),
    user_id text not null,
    device_token text not null unique,
    platform text not null default 'ios',
    apns_environment text not null default 'development',
    bundle_identifier text not null,
    is_active boolean not null default true,
    last_registered_at timestamptz not null default timezone('utc', now()),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

alter table public.user_push_tokens
    add column if not exists user_id text,
    add column if not exists device_token text,
    add column if not exists platform text default 'ios',
    add column if not exists apns_environment text default 'development',
    add column if not exists bundle_identifier text,
    add column if not exists is_active boolean default true,
    add column if not exists last_registered_at timestamptz default timezone('utc', now()),
    add column if not exists created_at timestamptz default timezone('utc', now()),
    add column if not exists updated_at timestamptz default timezone('utc', now());

create index if not exists user_push_tokens_user_idx
    on public.user_push_tokens (user_id, platform, is_active);

create or replace function public.touch_user_push_tokens_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at := timezone('utc', now());
    return new;
end;
$$;

drop trigger if exists touch_user_push_tokens_updated_at on public.user_push_tokens;
create trigger touch_user_push_tokens_updated_at
before update on public.user_push_tokens
for each row
execute function public.touch_user_push_tokens_updated_at();

alter table public.user_push_tokens enable row level security;

drop policy if exists "user_push_tokens_select" on public.user_push_tokens;
create policy "user_push_tokens_select"
on public.user_push_tokens
for select
to authenticated
using (user_id = public.current_app_user_id());

drop policy if exists "user_push_tokens_insert" on public.user_push_tokens;
create policy "user_push_tokens_insert"
on public.user_push_tokens
for insert
to authenticated
with check (
    user_id = public.current_app_user_id()
    and platform = 'ios'
);

drop policy if exists "user_push_tokens_update" on public.user_push_tokens;
create policy "user_push_tokens_update"
on public.user_push_tokens
for update
to authenticated
using (user_id = public.current_app_user_id())
with check (user_id = public.current_app_user_id());
