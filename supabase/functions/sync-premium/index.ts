// Supabase Edge Function: sync-premium
//
// Server-authoritatively syncs Premium status into public.profiles.premium
// by validating the RevenueCat subscriber state for the current Supabase user.
//
// Required secrets (Supabase Edge Function Secrets):
// - REVENUECAT_SECRET_API_KEY (RevenueCat "Secret API Key")
// - SUPABASE_SERVICE_ROLE_KEY (available by default in Supabase Edge Functions)
//
// Optional secrets:
// - REVENUECAT_ENTITLEMENT_ID (default: "premium")
// - IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID
// - ANDROID_IAP_PREMIUM_LIFETIME_PRODUCT_ID

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
  if (parts.length !== 3) {
    throw new Error("invalid_jwt");
  }
}

function isTruthyDate(value: unknown): boolean {
  if (value == null) return false;
  const s = String(value).trim();
  return s.length > 0 && s.toLowerCase() !== "null";
}

function isActiveEntitlement(ent: any): boolean {
  if (!ent || typeof ent !== "object") return false;
  const purchaseOk = isTruthyDate(ent.purchase_date);
  const exp = ent.expires_date;
  if (exp == null) {
    // Lifetime entitlements typically have expires_date = null.
    return purchaseOk;
  }
  const ts = Date.parse(String(exp));
  if (!Number.isFinite(ts)) return false;
  return ts > Date.now();
}

function hasLifetimePurchase(subscriber: any, productIds: string[]): boolean {
  if (!subscriber || typeof subscriber !== "object") return false;

  // Preferred: entitlement active.
  const entitlementId = String(Deno.env.get("REVENUECAT_ENTITLEMENT_ID") ?? "premium").trim() || "premium";
  const ent = subscriber.entitlements?.[entitlementId];
  if (ent && typeof ent === "object") {
    if (isActiveEntitlement(ent)) return true;
  }

  // Fallback: non-subscription transactions.
  const nonSubs = subscriber.non_subscriptions ?? {};
  for (const pid of productIds) {
    if (!pid) continue;
    const txs = nonSubs[pid];
    if (Array.isArray(txs) && txs.length > 0) return true;
  }

  // As a last fallback, check all purchased product ids array if present.
  const allIds = subscriber.all_purchased_product_identifiers;
  if (Array.isArray(allIds) && productIds.some((pid) => allIds.includes(pid))) {
    return true;
  }

  return false;
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
  const supabaseServiceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !supabaseAnon) return json(500, { error: "supabase_env_missing" });
  if (!supabaseServiceRole) return json(500, { error: "service_role_missing" });

  const rcSecret = (Deno.env.get("REVENUECAT_SECRET_API_KEY") ?? "").trim();
  if (!rcSecret) return json(500, { error: "revenuecat_secret_missing" });

  const iosPid = (Deno.env.get("IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID") ?? "").trim();
  const androidPid = (Deno.env.get("ANDROID_IAP_PREMIUM_LIFETIME_PRODUCT_ID") ?? "").trim();
  const productIds = [iosPid, androidPid].filter(Boolean);

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

  const rcAuth = `Basic ${btoa(`${rcSecret}:`)}`;
  const rcUrl = `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`;
  let rcResp: Response;
  try {
    rcResp = await fetch(rcUrl, {
      method: "GET",
      headers: {
        Authorization: rcAuth,
        "Content-Type": "application/json",
      },
    });
  } catch (e) {
    return json(502, { error: "revenuecat_unreachable", detail: String(e) });
  }

  const rcText = await rcResp.text();
  if (!rcResp.ok) {
    return json(502, {
      error: "revenuecat_error",
      status: rcResp.status,
      detail: rcText.trim().slice(0, 240),
    });
  }

  let rcJson: any;
  try {
    rcJson = JSON.parse(rcText);
  } catch (_) {
    return json(502, { error: "revenuecat_invalid_json" });
  }

  const subscriber = rcJson?.subscriber;
  const premium = hasLifetimePurchase(subscriber, productIds);

  // Update profile via service role (bypasses RLS).
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
