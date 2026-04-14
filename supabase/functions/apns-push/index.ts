import { createClient } from "npm:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5.9.6";

type PushRequest = {
  userId?: string;
  title?: string;
  body?: string;
  badge?: number;
  sound?: string;
  data?: Record<string, unknown>;
  record?: {
    user_id?: string;
    title?: string;
    body?: string;
    target_thread_id?: string | null;
  };
  new?: {
    user_id?: string;
    title?: string;
    body?: string;
    target_thread_id?: string | null;
  };
};

type PushTokenRow = {
  id: string;
  device_token: string;
  apns_environment: string;
  bundle_identifier: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const appleTeamId = Deno.env.get("APPLE_TEAM_ID") ?? "";
const appleKeyId = Deno.env.get("APPLE_KEY_ID") ?? "";
const applePrivateKey = (Deno.env.get("APPLE_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n");
const defaultBundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "";
const webhookSecret = Deno.env.get("APNS_WEBHOOK_SECRET") ?? "";

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  if (isAuthorized(request) === false) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  if (supabaseUrl === "" || serviceRoleKey === "") {
    return jsonResponse({ error: "Supabase env vars are missing." }, 500);
  }

  if (appleTeamId === "" || appleKeyId === "" || applePrivateKey === "") {
    return jsonResponse({ error: "Apple APNs credentials are missing." }, 500);
  }

  let payload: PushRequest;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const normalized = normalizePayload(payload);
  if (normalized.userId === "" || normalized.title === "" || normalized.body === "") {
    return jsonResponse({ error: "userId, title and body are required." }, 400);
  }

  const { data: tokens, error } = await supabase
    .from("user_push_tokens")
    .select("id,device_token,apns_environment,bundle_identifier")
    .eq("user_id", normalized.userId)
    .eq("platform", "ios")
    .eq("is_active", true);

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  if (!tokens || tokens.length === 0) {
    return jsonResponse({ sent: 0, failed: 0, inactiveTokens: 0 });
  }

  const providerToken = await createProviderToken();
  const results = await Promise.all(
    tokens.map((token) => sendPushToDevice(token as PushTokenRow, normalized, providerToken)),
  );

  const inactiveIds = results
    .filter((result) => result.deactivate)
    .map((result) => result.tokenId);

  if (inactiveIds.length > 0) {
    await supabase
      .from("user_push_tokens")
      .update({ is_active: false })
      .in("id", inactiveIds);
  }

  return jsonResponse({
    sent: results.filter((result) => result.success).length,
    failed: results.filter((result) => result.success === false).length,
    inactiveTokens: inactiveIds.length,
    results,
  });
});

function normalizePayload(payload: PushRequest) {
  const row = payload.record ?? payload.new;
  const data = payload.data ?? {};
  const threadId = row?.target_thread_id ?? (typeof data.target_thread_id === "string" ? data.target_thread_id : undefined);

  return {
    userId: payload.userId ?? row?.user_id ?? "",
    title: payload.title ?? row?.title ?? "",
    body: payload.body ?? row?.body ?? "",
    badge: payload.badge,
    sound: payload.sound ?? "default",
    data: {
      ...data,
      ...(threadId ? { target_thread_id: threadId } : {}),
    },
  };
}

function isAuthorized(request: Request) {
  if (webhookSecret === "") {
    return true;
  }

  return request.headers.get("x-webhook-secret") === webhookSecret;
}

async function createProviderToken() {
  const privateKey = await importPKCS8(applePrivateKey, "ES256");

  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: appleKeyId })
    .setIssuer(appleTeamId)
    .setIssuedAt()
    .setExpirationTime("50m")
    .sign(privateKey);
}

async function sendPushToDevice(
  token: PushTokenRow,
  payload: ReturnType<typeof normalizePayload>,
  providerToken: string,
) {
  const topic = token.bundle_identifier || defaultBundleId;
  const isSandbox = token.apns_environment !== "production";
  const endpoint = `https://${isSandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com"}/3/device/${token.device_token}`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      authorization: `bearer ${providerToken}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: {
          title: payload.title,
          body: payload.body,
        },
        sound: payload.sound,
        ...(typeof payload.badge === "number" ? { badge: payload.badge } : {}),
      },
      ...payload.data,
    }),
  });

  if (response.ok) {
    return { tokenId: token.id, success: true, status: response.status, deactivate: false };
  }

  const errorBody = await response.text();
  const shouldDeactivate = response.status === 410 || errorBody.includes("BadDeviceToken") || errorBody.includes("Unregistered");

  return {
    tokenId: token.id,
    success: false,
    status: response.status,
    deactivate: shouldDeactivate,
    error: errorBody,
  };
}

function jsonResponse(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders(),
      "content-type": "application/json",
    },
  });
}

function corsHeaders() {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "POST, OPTIONS",
    "access-control-allow-headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret",
  };
}
