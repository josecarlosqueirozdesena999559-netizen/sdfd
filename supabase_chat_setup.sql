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

alter table public.chat_threads
    add column if not exists requester_user_id text,
    add column if not exists requester_name text,
    add column if not exists requester_role text,
    add column if not exists admin_user_id text,
    add column if not exists admin_name text,
    add column if not exists admin_role text,
    add column if not exists title text default 'Atendimento administrativo',
    add column if not exists last_message_preview text,
    add column if not exists updated_at timestamptz default timezone('utc', now()),
    add column if not exists created_at timestamptz default timezone('utc', now());

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

alter table public.chat_messages
    add column if not exists thread_id uuid references public.chat_threads(id) on delete cascade,
    add column if not exists sender_user_id text,
    add column if not exists sender_name text,
    add column if not exists sender_role text,
    add column if not exists recipient_user_id text,
    add column if not exists body text,
    add column if not exists attachment_name text,
    add column if not exists attachment_url text,
    add column if not exists attachment_mime_type text,
    add column if not exists attachment_storage_path text,
    add column if not exists seen_at timestamptz,
    add column if not exists deleted_at timestamptz,
    add column if not exists created_at timestamptz default timezone('utc', now());

create table if not exists public.user_notifications (
    id uuid primary key default gen_random_uuid(),
    user_id text not null,
    title text not null,
    body text not null,
    target_thread_id uuid references public.chat_threads(id) on delete set null,
    is_read boolean not null default false,
    created_at timestamptz not null default timezone('utc', now())
);

alter table public.user_notifications
    add column if not exists user_id text,
    add column if not exists title text,
    add column if not exists body text,
    add column if not exists target_thread_id uuid references public.chat_threads(id) on delete set null,
    add column if not exists is_read boolean default false,
    add column if not exists created_at timestamptz default timezone('utc', now());

create unique index if not exists chat_threads_unique_pair
    on public.chat_threads (requester_user_id, admin_user_id);

create index if not exists chat_threads_updated_idx
    on public.chat_threads (updated_at desc);

create index if not exists chat_messages_thread_idx
    on public.chat_messages (thread_id, created_at);

create index if not exists chat_messages_unread_idx
    on public.chat_messages (recipient_user_id, seen_at, thread_id);

create index if not exists user_notifications_user_idx
    on public.user_notifications (user_id, created_at desc);

create or replace function public.current_app_user_id()
returns text
language sql
stable
as $$
    select u.id
    from public.usuarios u
    where u.auth_user_id::text = auth.uid()::text
    limit 1
$$;

create or replace function public.current_app_user_role()
returns text
language sql
stable
as $$
    select coalesce(u.role, '')
    from public.usuarios u
    where u.auth_user_id::text = auth.uid()::text
    limit 1
$$;

create or replace function public.current_app_user_is_admin()
returns boolean
language sql
stable
as $$
    select public.current_app_user_role() ilike '%admin%'
$$;

create or replace function public.chat_message_preview(body_text text, attachment_name text, attachment_mime_type text)
returns text
language plpgsql
stable
as $$
begin
    if coalesce(trim(body_text), '') <> '' then
        return left(trim(body_text), 120);
    end if;

    if coalesce(attachment_name, '') <> '' then
        return attachment_name;
    end if;

    if coalesce(attachment_mime_type, '') like 'audio/%' then
        return 'Audio enviado';
    end if;

    return 'Nova mensagem';
end;
$$;

create or replace function public.refresh_chat_thread_metadata(p_thread_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    latest_message record;
begin
    select
        m.created_at,
        public.chat_message_preview(m.body, m.attachment_name, m.attachment_mime_type) as preview
    into latest_message
    from public.chat_messages m
    where m.thread_id = p_thread_id
    order by m.created_at desc
    limit 1;

    update public.chat_threads t
    set
        updated_at = coalesce(latest_message.created_at, timezone('utc', now())),
        last_message_preview = coalesce(latest_message.preview, 'Conversa iniciada')
    where t.id = p_thread_id;
end;
$$;

create or replace function public.handle_chat_message_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    effective_thread_id uuid;
begin
    effective_thread_id := coalesce(new.thread_id, old.thread_id);

    perform public.refresh_chat_thread_metadata(effective_thread_id);

    if tg_op = 'INSERT' and new.recipient_user_id <> new.sender_user_id then
        insert into public.user_notifications (user_id, title, body, target_thread_id)
        values (
            new.recipient_user_id,
            'Nova mensagem',
            new.sender_name || ' enviou uma nova mensagem.',
            new.thread_id
        );
    end if;

    return coalesce(new, old);
end;
$$;

drop trigger if exists chat_message_write_trigger on public.chat_messages;
create trigger chat_message_write_trigger
after insert or update or delete on public.chat_messages
for each row
execute function public.handle_chat_message_write();

alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.user_notifications enable row level security;

drop policy if exists "chat_threads_select" on public.chat_threads;
create policy "chat_threads_select"
on public.chat_threads
for select
to authenticated
using (
    requester_user_id = public.current_app_user_id()
    or admin_user_id = public.current_app_user_id()
);

drop policy if exists "chat_threads_insert" on public.chat_threads;
create policy "chat_threads_insert"
on public.chat_threads
for insert
to authenticated
with check (
    (
        requester_user_id = public.current_app_user_id()
        and admin_user_id <> requester_user_id
        and exists (
            select 1
            from public.usuarios admin_user
            where admin_user.id::text = chat_threads.admin_user_id
              and admin_user.role ilike '%admin%'
        )
    )
    or (
        public.current_app_user_is_admin()
        and admin_user_id = public.current_app_user_id()
        and requester_user_id <> admin_user_id
    )
);

drop policy if exists "chat_threads_update" on public.chat_threads;
create policy "chat_threads_update"
on public.chat_threads
for update
to authenticated
using (
    requester_user_id = public.current_app_user_id()
    or admin_user_id = public.current_app_user_id()
)
with check (
    requester_user_id = public.current_app_user_id()
    or admin_user_id = public.current_app_user_id()
);

drop policy if exists "chat_messages_select" on public.chat_messages;
create policy "chat_messages_select"
on public.chat_messages
for select
to authenticated
using (
    exists (
        select 1
        from public.chat_threads t
        where t.id = chat_messages.thread_id
          and (
              t.requester_user_id = public.current_app_user_id()
              or t.admin_user_id = public.current_app_user_id()
          )
    )
);

drop policy if exists "chat_messages_insert" on public.chat_messages;
create policy "chat_messages_insert"
on public.chat_messages
for insert
to authenticated
with check (
    sender_user_id = public.current_app_user_id()
    and exists (
        select 1
        from public.chat_threads t
        where t.id = chat_messages.thread_id
          and (
              (
                  public.current_app_user_is_admin() = false
                  and t.requester_user_id = public.current_app_user_id()
                  and recipient_user_id = t.admin_user_id
              )
              or (
                  public.current_app_user_is_admin()
                  and t.admin_user_id = public.current_app_user_id()
                  and recipient_user_id = t.requester_user_id
              )
          )
    )
);

drop policy if exists "chat_messages_update" on public.chat_messages;
create policy "chat_messages_update"
on public.chat_messages
for update
to authenticated
using (
    sender_user_id = public.current_app_user_id()
    or recipient_user_id = public.current_app_user_id()
)
with check (
    sender_user_id = public.current_app_user_id()
    or recipient_user_id = public.current_app_user_id()
);

drop policy if exists "user_notifications_select" on public.user_notifications;
create policy "user_notifications_select"
on public.user_notifications
for select
to authenticated
using (
    user_id = public.current_app_user_id()
);

drop policy if exists "user_notifications_update" on public.user_notifications;
create policy "user_notifications_update"
on public.user_notifications
for update
to authenticated
using (
    user_id = public.current_app_user_id()
)
with check (
    user_id = public.current_app_user_id()
);

drop policy if exists "user_notifications_insert" on public.user_notifications;

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

do $$
begin
    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'chat_threads'
    ) then
        alter publication supabase_realtime add table public.chat_threads;
    end if;

    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'chat_messages'
    ) then
        alter publication supabase_realtime add table public.chat_messages;
    end if;

    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'user_notifications'
    ) then
        alter publication supabase_realtime add table public.user_notifications;
    end if;
end
$$;
