create extension if not exists pg_net;

create or replace function public.enqueue_apns_push_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    function_url text := 'https://nwticagjzhomwgnzjbbs.supabase.co/functions/v1/apns-push';
    payload jsonb;
    headers jsonb;
begin
    payload := jsonb_build_object(
        'userId', new.user_id,
        'title', new.title,
        'body', new.body,
        'data', jsonb_build_object(
            'target_thread_id', new.target_thread_id
        )
    );

    headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', 'requisiplus-apns-2026-04-14'
    );

    perform net.http_post(
        url := function_url,
        headers := headers,
        body := payload
    );

    return new;
end;
$$;

drop trigger if exists user_notifications_apns_push on public.user_notifications;
create trigger user_notifications_apns_push
after insert on public.user_notifications
for each row
execute function public.enqueue_apns_push_notification();
