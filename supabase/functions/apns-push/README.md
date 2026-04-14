# APNs Push Function

Esta Edge Function envia push notifications para iOS via APNs usando chave `.p8`.

## Segredos esperados

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `APPLE_TEAM_ID`
- `APPLE_KEY_ID`
- `APPLE_PRIVATE_KEY`
- `APNS_BUNDLE_ID`
- `APNS_WEBHOOK_SECRET` opcional

## Deploy

```bash
supabase functions deploy apns-push --no-verify-jwt
```

## Exemplo de chamada

```bash
curl -X POST "https://<project-ref>.supabase.co/functions/v1/apns-push" \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: <secret>" \
  -d '{
    "userId": "<usuario-id>",
    "title": "Nova mensagem",
    "body": "Voce recebeu uma nova mensagem.",
    "data": {
      "target_thread_id": "<thread-id>"
    }
  }'
```

## Webhook de banco recomendado

Configure um Database Webhook para `INSERT` em `public.user_notifications` apontando para a function `apns-push`.
