// Supabase Edge Function: verify-premium
//
// Verifies a lifetime non-consumable purchase directly with Apple/Google
// and then updates public.profiles.premium for the current Supabase user.
//
// Request JSON:
// {
//   "platform": "ios" | "android",
//   "productId": "...",
//   "verificationData": "..."   // iOS: base64 receipt, Android: purchase token
// }
//
// Secrets:
// - SERVICE_ROLE_KEY (required to upsert profiles without opening RLS)
//
// iOS:
// - APPLE_VERIFY_RECEIPT_SHARED_SECRET (optional; required for subscriptions, ok empty for non-consumables)
//
// Android:
// - GOOGLE_PLAY_PACKAGE_NAME (e.g. com.your.app)
// - GOOGLE_PLAY_SERVICE_ACCOUNT_JSON (service account json, single-line or raw json)

type Platform = "ios" | "android";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function getBearer(req: Request): string | null {
  const raw = req.headers.get("authorization") ?? req.headers.get("Authorization");
  if (!raw) return null;
  const m = raw.match(/^Bearer\\s+(.+)$/i);
  return m ? m[1].trim() : null;
}

function assertAuth(token: string) {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("invalid_jwt");
}

async function verifyIosReceipt(args: {
  receiptData: string;
  expectedProductId: string;
  sharedSecret?: string;
}): Promise<boolean> {
  const payload: Record<string, unknown> = {
    "receipt-data": args.receiptData,
    "exclude-old-transactions": true,
  };
  const shared = (args.sharedSecret ?? "").trim();
  if (shared) payload.password = shared;

  async function call(url: string) {
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const text = await resp.text();
    let data: any;
    try {
      data = JSON.parse(text);
    } catch (_) {
      return { ok: false, status: -1, raw: text };
    }
    return { ok: resp.ok, status: data?.status, data };
  }

  // Try production first; switch to sandbox if needed (21007).
  let result = await call("https://buy.itunes.apple.com/verifyReceipt");
  if (result.status === 21007) {
    result = await call("https://sandbox.itunes.apple.com/verifyReceipt");
  }
  if (!result.data || result.status !== 0) {
    return false;
  }

  const receipt = result.data.receipt ?? {};
  const inApp = receipt.in_app ?? [];
  if (!Array.isArray(inApp)) return false;

  return inApp.some((entry: any) => {
    const pid = String(entry?.product_id ?? "").trim();
    return pid === args.expectedProductId;
  });
}

function base64UrlToBase64(input: string) {
  // Convert base64url to base64.
  const pad = "=".repeat((4 - (input.length % 4)) % 4);
  return (input + pad).replace(/-/g, "+").replace(/_/g, "/");
}

async function googleAccessTokenFromServiceAccount(serviceAccount: any) {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const enc = (obj: any) =>
    btoa(JSON.stringify(obj))
      .replace(/\\+/g, "-")
      .replace(/\\//g, "_")
      .replace(/=+$/g, "");

  const signingInput = `${enc(header)}.${enc(claimSet)}`;

  const keyPem = String(serviceAccount.private_key ?? "");
  if (!keyPem.includes("BEGIN PRIVATE KEY")) {
    throw new Error("invalid_service_account_key");
  }

  const keyData = keyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\\s+/g, "");

  const binary = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    binary.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );

  const sigB64Url = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\\+/g, "-")
    .replace(/\\//g, "_")
    .replace(/=+$/g, "");

  const jwt = `${signingInput}.${sigB64Url}`;

  const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const tokenText = await tokenResp.text();
  if (!tokenResp.ok) {
    throw new Error(`google_oauth_failed:${tokenResp.status}:${tokenText.slice(0, 120)}`);
  }
  const parsed = JSON.parse(tokenText);
  const token = String(parsed.access_token ?? "").trim();
  if (!token) throw new Error("google_oauth_no_token");
  return token;
}

async function verifyAndroidPurchase(args: {
  packageName: string;
  productId: string;
  purchaseToken: string;
  accessToken: string;
}): Promise<boolean> {
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(args.packageName)}` +
    `/purchases/products/${encodeURIComponent(args.productId)}` +
    `/tokens/${encodeURIComponent(args.purchaseToken)}`;
  const resp = await fetch(url, {
    method: "GET",
    headers: { Authorization: `Bearer ${args.accessToken}` },
  });
  const text = await resp.text();
  if (!resp.ok) {
    return false;
  }
  let data: any;
  try {
    data = JSON.parse(text);
  } catch (_) {
    return false;
  }

  // purchaseState: 0 purchased, 1 canceled, 2 pending
  const purchaseState = Number(data.purchaseState ?? 0);
  if (purchaseState !== 0) return false;
  return true;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const bearer = getBearer(req);
  if (!bearer) return json(401, { error: "missing_authorization" });
  try {
    assertAuth(bearer);
  } catch (_) {
    return json(401, { error: "invalid_authorization" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  // Supabase CLI blocks custom env names starting with SUPABASE_.
  // Use SERVICE_ROLE_KEY as the deploy-time secret name.
  const supabaseServiceRole =
    (Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim();
  if (!supabaseUrl || !supabaseAnon) return json(500, { error: "supabase_env_missing" });
  if (!supabaseServiceRole) return json(500, { error: "service_role_missing" });

  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2.49.1");
  const sb = createClient(supabaseUrl, supabaseAnon, {
    global: { headers: { Authorization: `Bearer ${bearer}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: authData, error: authError } = await sb.auth.getUser();
  if (authError || !authData?.user?.id) {
    return json(401, { error: "unauthorized" });
  }
  const userId = String(authData.user.id).trim();

  let body: any = null;
  try {
    body = await req.json();
  } catch (_) {
    return json(400, { error: "invalid_json" });
  }

  const platform = String(body?.platform ?? "").trim().toLowerCase() as Platform;
  const productId = String(body?.productId ?? "").trim();
  const verificationData = String(body?.verificationData ?? "").trim();
  if ((platform !== "ios" && platform !== "android") || !productId || !verificationData) {
    return json(400, { error: "invalid_payload" });
  }

  let premium = false;
  try {
    if (platform === "ios") {
      const sharedSecret = (Deno.env.get("APPLE_VERIFY_RECEIPT_SHARED_SECRET") ?? "").trim();
      premium = await verifyIosReceipt({
        receiptData: verificationData,
        expectedProductId: productId,
        sharedSecret,
      });
    } else {
      const packageName = (Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME") ?? "").trim();
      const svcJsonRaw = (Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON") ?? "").trim();
      if (!packageName || !svcJsonRaw) {
        return json(500, { error: "google_env_missing" });
      }
      const svc = JSON.parse(svcJsonRaw);
      const accessToken = await googleAccessTokenFromServiceAccount(svc);
      premium = await verifyAndroidPurchase({
        packageName,
        productId,
        purchaseToken: verificationData,
        accessToken,
      });
    }
  } catch (e) {
    return json(502, { error: "verify_failed", detail: String(e).slice(0, 240) });
  }

  const admin = createClient(supabaseUrl, supabaseServiceRole, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error: upsertError } = await admin.from("profiles").upsert({
    user_id: userId,
    premium,
    updated_at: new Date().toISOString(),
  });
  if (upsertError) {
    return json(500, { error: "profile_upsert_failed", detail: String(upsertError.message ?? upsertError) });
  }

  return json(200, { premium });
});
