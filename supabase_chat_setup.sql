create extension if not exists pgcrypto;

create table if not exists public.chat_threads (
    id uuid primary key default gen_random_uuid(),
    requester_user_id text not null,
    requester_name text not null,
    requester_role text,
    admin_user_id text not null,
    admin_name text not null,
    admin_role text,
    title text not null default 'Atendimento administrativo',
    last_message_preview text,
    updated_at timestamptz not null default timezone('utc', now()),
    created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists chat_threads_unique_pair
    on public.chat_threads (requester_user_id, admin_user_id);

create table if not exists public.chat_messages (
    id uuid primary key default gen_random_uuid(),
    thread_id uuid not null references public.chat_threads(id) on delete cascade,
    sender_user_id text not null,
    sender_name text not null,
    sender_role text,
    recipient_user_id text not null,
    body text,
    attachment_name text,
    attachment_url text,
    attachment_mime_type text,
    attachment_storage_path text,
    seen_at timestamptz,
    deleted_at timestamptz,
    created_at timestamptz not null default timezone('utc', now())
);

create index if not exists chat_messages_thread_idx
    on public.chat_messages (thread_id, created_at);

create table if not exists public.user_notifications (
    id uuid primary key default gen_random_uuid(),
    user_id text not null,
    title text not null,
    body text not null,
    target_thread_id uuid references public.chat_threads(id) on delete set null,
    is_read boolean not null default false,
    created_at timestamptz not null default timezone('utc', now())
);

create index if not exists user_notifications_user_idx
    on public.user_notifications (user_id, created_at desc);

alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.user_notifications enable row level security;

drop policy if exists "chat_threads_select" on public.chat_threads;
create policy "chat_threads_select"
on public.chat_threads
for select
to authenticated
using (
    requester_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
    or admin_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
);

drop policy if exists "chat_threads_insert" on public.chat_threads;
create policy "chat_threads_insert"
on public.chat_threads
for insert
to authenticated
with check (
    requester_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
    or admin_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text and role ilike '%admin%'
    )
);

drop policy if exists "chat_threads_update" on public.chat_threads;
create policy "chat_threads_update"
on public.chat_threads
for update
to authenticated
using (
    requester_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
    or admin_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
)
with check (
    requester_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
    or admin_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
);

drop policy if exists "chat_messages_select" on public.chat_messages;
create policy "chat_messages_select"
on public.chat_messages
for select
to authenticated
using (
    sender_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
    or recipient_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
);

drop policy if exists "chat_messages_insert" on public.chat_messages;
create policy "chat_messages_insert"
on public.chat_messages
for insert
to authenticated
with check (
    sender_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
);

drop policy if exists "chat_messages_update" on public.chat_messages;
create policy "chat_messages_update"
on public.chat_messages
for update
to authenticated
using (
    sender_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
    or recipient_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
)
with check (
    sender_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
    or recipient_user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
);

drop policy if exists "user_notifications_select" on public.user_notifications;
create policy "user_notifications_select"
on public.user_notifications
for select
to authenticated
using (
    user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
);

drop policy if exists "user_notifications_insert" on public.user_notifications;
create policy "user_notifications_insert"
on public.user_notifications
for insert
to authenticated
with check (true);

drop policy if exists "user_notifications_update" on public.user_notifications;
create policy "user_notifications_update"
on public.user_notifications
for update
to authenticated
using (
    user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
)
with check (
    user_id in (
        select id from public.usuarios where auth_user_id = auth.uid()::text
    )
);

insert into storage.buckets (id, name, public)
values ('chat-uploads', 'chat-uploads', true)
on conflict (id) do nothing;

drop policy if exists "chat_uploads_read" on storage.objects;
create policy "chat_uploads_read"
on storage.objects
for select
to authenticated
using (bucket_id = 'chat-uploads');

drop policy if exists "chat_uploads_insert" on storage.objects;
create policy "chat_uploads_insert"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'chat-uploads');
