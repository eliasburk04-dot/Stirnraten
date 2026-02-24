// Supabase Edge Function: generate-wordlist
// Calls Groq Chat Completions and returns strict JSON to the app:
// {"title":"...","language":"de|en","items":["..."]}
//
// Security:
// - Requires an authenticated Supabase JWT (anonymous sessions count as authenticated).
// - GROQ_API_KEY is read from function secrets (never from client).

type Difficulty = "easy" | "medium" | "hard";
type Language = "de" | "en";

type ClientRequest = {
  input: {
    topic: string;
    language: Language;
    difficulty: Difficulty;
    count: number;
    styleTags?: string[];
    includeHints?: boolean;
    title?: string;
  };
  instructions?: string;
  responseSchema?: unknown;
};

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
  const m = raw.match(/^Bearer\s+(.+)$/i);
  return m ? m[1].trim() : null;
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

function assertAuth(token: string) {
  // Minimal JWT shape check: 3 dot-separated segments.
  // Supabase will validate it when we call auth.getUser.
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("invalid_jwt");
  }
}

function clamp(n: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, n));
}

function berlinDateKey(now: Date = new Date()): string {
  // Build YYYY-MM-DD from parts to avoid locale formatting differences.
  const parts = new Intl.DateTimeFormat("en", {
    timeZone: "Europe/Berlin",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const map: Record<string, string> = {};
  for (const p of parts) {
    if (p.type === "year" || p.type === "month" || p.type === "day") {
      map[p.type] = p.value;
    }
  }
  const y = map.year ?? "";
  const m = map.month ?? "";
  const d = map.day ?? "";
  return `${y}-${m}-${d}`.trim();
}

const blockedMetaTerms = new Set<string>([
  "thing",
  "things",
  "object",
  "objects",
  "element",
  "elements",
  "category",
  "categories",
  "stuff",
  "freedom",
  "system",
  "process",
  "concept",
  "development",
  "ding",
  "dinge",
  "objekt",
  "objekte",
  "element",
  "elemente",
  "kategorie",
  "kategorien",
  "sache",
  "sachen",
  "freiheit",
  "prozess",
  "konzept",
  "entwicklung",
]);

function extractWordFromModelItem(entry: unknown): string | null {
  if (typeof entry === "string") return entry;
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) return null;
  const raw = (entry as Record<string, unknown>).word;
  if (typeof raw !== "string") return null;
  return raw;
}

function normalizeItems(items: unknown, requestedCount: number): string[] {
  if (!Array.isArray(items)) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const entry of items) {
    const candidate = extractWordFromModelItem(entry);
    if (!candidate) continue;
    let s = candidate.trim();
    if (!s) continue;

    // Strip obvious bullet/number prefixes.
    s = s.replace(/^\s*[-*•]\s+/, "");
    s = s.replace(/^\s*\d+[\).\-\:]\s+/, "");
    s = s.replace(/\s+/g, " ");
    s = s.trim();
    if (!s) continue;

    // No emojis (roughly): remove surrogate pairs / extended pictographs.
    // (Client also filters; this is a second line of defense.)
    s = s.replace(/\p{Extended_Pictographic}/gu, "").trim();
    if (!s) continue;

    // Prefer one word, allow up to 2 for common compound terms.
    const words = s.split(/\s+/).filter(Boolean);
    if (words.length < 1 || words.length > 2) continue;

    // No super long terms.
    if (s.length > 64) continue;

    const key = s.toLocaleLowerCase();
    if (blockedMetaTerms.has(key)) continue;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(s);
    if (out.length >= requestedCount) break;
  }
  return out;
}

function safeParseJsonObject(input: string): Record<string, unknown> | null {
  const trimmed = input.trim();
  try {
    const parsed = JSON.parse(trimmed);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      return parsed as Record<string, unknown>;
    }
  } catch (_) {
    // Try to extract first JSON object from within text.
    const start = trimmed.indexOf("{");
    if (start < 0) return null;
    let depth = 0;
    for (let i = start; i < trimmed.length; i++) {
      const ch = trimmed[i];
      if (ch === "{") depth++;
      if (ch === "}") {
        depth--;
        if (depth === 0) {
          const slice = trimmed.slice(start, i + 1);
          try {
            const parsed = JSON.parse(slice);
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
              return parsed as Record<string, unknown>;
            }
          } catch (_) {
            return null;
          }
          return null;
        }
      }
    }
  }
  return null;
}

function extractAIResponsePayload(raw: unknown): Record<string, unknown> | null {
  if (!raw) return null;

  if (typeof raw === "string") {
    return safeParseJsonObject(raw);
  }

  if (typeof raw === "object" && !Array.isArray(raw)) {
    const obj = raw as Record<string, unknown>;

    // If already in desired schema.
    if (typeof obj.title === "string" && Array.isArray(obj.items)) {
      return obj;
    }

    // Common wrappers.
    for (const key of ["result", "data", "output"]) {
      const nested = obj[key];
      if (nested && typeof nested === "object" && !Array.isArray(nested)) {
        const n = nested as Record<string, unknown>;
        if (typeof n.title === "string" && Array.isArray(n.items)) return n;
      }
    }

    // OpenAI-like: { choices: [{ message: { content: "..." } }] }
    const choices = obj.choices;
    if (Array.isArray(choices) && choices.length > 0) {
      const first = choices[0];
      if (first && typeof first === "object" && !Array.isArray(first)) {
        const message = (first as Record<string, unknown>).message;
        if (message && typeof message === "object" && !Array.isArray(message)) {
          const content = (message as Record<string, unknown>).content;
          if (typeof content === "string") {
            return safeParseJsonObject(content);
          }
        }
      }
    }

    // Some providers: { content: "{...}" }
    if (typeof obj.content === "string") {
      return safeParseJsonObject(obj.content);
    }
  }
  return null;
}

function buildSystemPrompt(): string {
  return `
You generate premium word lists for a fast guessing game.
Return strict JSON only.
Goal: deliver EXACTLY Count playable words.

Quality rules:
- Prefer concrete nouns (visual, actable).
- No abstract/meta terms (e.g. thing, object, category, stuff).
- Words must be common, guessable, and not niche.
- Keep diversity; avoid near-duplicates and repetitive micro-categories.
- Difficulty: easy=very common, medium=common but more specific, hard=specific yet still widely known.

Format rules:
- Prefer 1 word; max 2 words if very common.
- No emojis, numbering, bullet points, or explanations.
- No duplicates (case-insensitive).
- Max 64 characters per word.
- Language must match the request exactly.

Output exactly:
{
  "title": "string",
  "language": "de or en",
  "items": [
    { "word": "string" }
  ]
}
- No markdown, comments, or extra keys.
  `.trim();
}

function buildUserPrompt(input: ClientRequest["input"]): string {
  const tags = (input.styleTags ?? []).filter((t) => (t ?? "").trim().length > 0);
  const requestedTitle = typeof input.title === "string" ? input.title.trim() : "";
  return [
    `INPUT`,
    `Topic: ${input.topic}`,
    `Language: ${input.language}`,
    `Difficulty: ${input.difficulty}`,
    `Count: ${input.count}`,
    `Optional title: ${requestedTitle || "(empty)"}`,
    `Style tags: ${tags.length ? tags.join(", ") : "none"}`,
    `Include hints: ${input.includeHints ? "true" : "false"}`,
    `TITLE RULES`,
    `- If Optional title is non-empty, use it exactly (trim whitespace).`,
    `- Otherwise create a short, appealing title based on Topic + Difficulty in the requested language.`,
  ].join("\n");
}

function buildUserPromptWithExcludes(args: {
  input: ClientRequest["input"];
  excludeTerms?: string[];
  attempt: number;
}): string {
  const base = buildUserPrompt(args.input);
  if (args.attempt < 1) return base;
  const excludes = (args.excludeTerms ?? [])
    .map((t) => (t ?? "").trim())
    .filter(Boolean)
    .slice(0, 20);
  if (!excludes.length) return base;
  return `${base}\nexclude_terms: ${excludes.join(", ")}`.trim();
}

function computeAskCount(args: {
  targetCount: number;
  currentValidCount: number;
  attempt: number;
  maxItems: number;
}): number {
  const remaining = clamp(args.targetCount - args.currentValidCount, 0, args.targetCount);
  if (args.attempt === 0) {
    const buffer = clamp(Math.floor(args.targetCount / 2), 10, 35);
    return clamp(args.targetCount + buffer, 5, args.maxItems);
  }
  const followUp = remaining + 12;
  return clamp(followUp, 5, args.maxItems);
}

function defaultGeneratedTitle(args: {
  topic: string;
  language: Language;
  difficulty: Difficulty;
}): string {
  if (args.language === "de") {
    const label = args.difficulty === "easy"
      ? "Leicht"
      : args.difficulty === "medium"
      ? "Mittel"
      : "Schwer";
    return `${args.topic} (${label})`;
  }
  const label = args.difficulty === "easy"
    ? "Easy"
    : args.difficulty === "medium"
    ? "Medium"
    : "Hard";
  return `${args.topic} (${label})`;
}

async function callGroqWithRateLimitRetry(args: {
  apiKey: string;
  model: string;
  system: string;
  user: string;
  temperature: number;
}): Promise<unknown> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const raw = await callGroqChatCompletion(args);
    if ((raw as any)?.__rate_limited) {
      if (attempt === 0) {
        await sleep(900);
        continue;
      }
    }
    return raw;
  }
  return { __error: true, status: 429, body: "rate_limited" };
}

async function callGroqChatCompletion(args: {
  apiKey: string;
  model: string;
  system: string;
  user: string;
  temperature: number;
}): Promise<unknown> {
  let resp: Response;
  try {
    resp = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${args.apiKey}`,
      },
      body: JSON.stringify({
        model: args.model,
        temperature: args.temperature,
        messages: [
          { role: "system", content: args.system },
          { role: "user", content: args.user },
        ],
      }),
    });
  } catch (e) {
    return { __error: true, status: 0, body: String(e) };
  }

  const text = await resp.text();
  if (resp.status === 429) {
    const retryAfter = resp.headers.get("retry-after");
    return { __rate_limited: true, retryAfter, body: text };
  }
  if (!resp.ok) {
    return { __error: true, status: resp.status, body: text };
  }
  try {
    return JSON.parse(text);
  } catch (_) {
    return { __error: true, status: resp.status, body: text };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const bearer = getBearer(req);
  if (!bearer) {
    return json(401, { error: "missing_authorization" });
  }
  try {
    assertAuth(bearer);
  } catch (_) {
    return json(401, { error: "invalid_authorization" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  // Use the client-provided publishable key when present. After API key migration,
  // Edge Function env vars can lag behind and still contain legacy keys.
  // See: https://github.com/supabase/supabase/issues/37648
  const clientApiKey = (req.headers.get("apikey") ?? req.headers.get("x-supabase-anon-key") ?? "").trim();
  const supabaseAnon = clientApiKey || (Deno.env.get("SUPABASE_ANON_KEY") ?? "");
  if (!supabaseUrl || !supabaseAnon) {
    // Should be present by default in Edge Functions runtime, but keep a clear error.
    return json(500, { error: "supabase_env_missing" });
  }

  // Verify the JWT (anonymous sessions are authenticated as well).
  let sb: any;
  try {
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2.49.1");
    sb = createClient(supabaseUrl, supabaseAnon, {
      global: { headers: { Authorization: `Bearer ${bearer}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await sb.auth.getUser();
    if (error || !data?.user?.id) {
      return json(401, { error: "unauthorized" });
    }
  } catch (e) {
    return json(500, { error: "auth_verify_failed", detail: String(e) });
  }

  let body: ClientRequest;
  try {
    body = (await req.json()) as ClientRequest;
  } catch (_) {
    return json(400, { error: "invalid_json" });
  }

  const input = body?.input;
  if (!input || typeof input !== "object") {
    return json(400, { error: "missing_input" });
  }
  const topic = String((input as any).topic ?? "").trim();
  const language = String((input as any).language ?? "").trim() as Language;
  const difficulty = String((input as any).difficulty ?? "").trim() as Difficulty;
  const count = Number((input as any).count ?? 0);
  const requestedTitle = String((input as any).title ?? "").trim();
  if (topic.length < 2) return json(400, { error: "topic_too_short" });
  if (language !== "de" && language !== "en") return json(400, { error: "invalid_language" });
  if (difficulty !== "easy" && difficulty !== "medium" && difficulty !== "hard") {
    return json(400, { error: "invalid_difficulty" });
  }
  const dateKey = berlinDateKey();

  // Server-side guardrails:
  // - Free quota: 3 generations/day (Europe/Berlin date key), atomic via RPC.
  // - Premium: unlimited quota, max 100 items/list.
  let isPremium = false;
  let quotaAllowed = true;
  let used = 0;
  let limit = 3;
  try {
    const { data, error } = await sb.rpc("consume_ai_generation", { p_date_key: dateKey });
    if (error) {
      return json(500, { error: "quota_check_failed", detail: String(error.message ?? error) });
    }
    const row = Array.isArray(data) ? data[0] : data;
    isPremium = Boolean(row?.is_premium);
    quotaAllowed = Boolean(row?.allowed);
    used = Number(row?.used ?? 0);
    limit = Number(row?.quota_limit ?? 3);
  } catch (e) {
    return json(500, { error: "quota_check_failed", detail: String(e) });
  }

  if (!quotaAllowed && !isPremium) {
    return json(402, {
      error: "quota_exceeded",
      usage: { date_key: dateKey, used, limit, premium: isPremium },
    });
  }

  const maxItems = isPremium ? 100 : 20;
  const requestedCount = clamp(Number.isFinite(count) ? count : 0, 5, maxItems);

  const groqApiKey = Deno.env.get("GROQ_API_KEY") ?? "";
  if (!groqApiKey) {
    return json(500, { error: "groq_api_key_missing" });
  }

  // Keep a sensible default (models can be deprecated; allow overriding via secret).
  const model = (Deno.env.get("GROQ_MODEL") ?? "llama-3.3-70b-versatile").trim();
  const temperature = Number(Deno.env.get("GROQ_TEMPERATURE") ?? "0.4");

  const system = buildSystemPrompt();

  // Ensure we return exactly the requested count (within maxItems) whenever possible.
  // We may call Groq multiple times within the *same* quota-consumed invocation to fill gaps.
  const targetCount = requestedCount;
  const rawPool: unknown[] = [];
  let normalized: string[] = [];
  let title: string | null = null;

  for (let attempt = 0; attempt < 3; attempt++) {
    const askCount = computeAskCount({
      targetCount,
      currentValidCount: normalized.length,
      attempt,
      maxItems,
    });

    const user = buildUserPromptWithExcludes({
      input: {
        ...input,
        topic,
        language,
        difficulty,
        count: askCount,
        title: requestedTitle || undefined,
      } as any,
      attempt,
      excludeTerms: normalized,
    });

    const raw = await callGroqWithRateLimitRetry({
      apiKey: groqApiKey,
      model,
      system,
      user,
      temperature: Number.isFinite(temperature) ? temperature : 0.4,
    });

    if ((raw as any)?.__rate_limited) {
      return json(429, {
        error: "rate_limited",
        usage: { date_key: dateKey, used, limit, premium: isPremium },
      });
    }
    if ((raw as any)?.__error) {
      const status = Number((raw as any)?.status ?? 0);
      const body = String((raw as any)?.body ?? "");
      const detail = body.trim().slice(0, 240);
      return json(502, {
        error: "upstream_error",
        upstream_status: Number.isFinite(status) ? status : 0,
        detail,
        usage: { date_key: dateKey, used, limit, premium: isPremium },
      });
    }

    const payload = extractAIResponsePayload(raw);
    if (!payload) {
      return json(502, {
        error: "invalid_ai_response",
        usage: { date_key: dateKey, used, limit, premium: isPremium },
      });
    }

    if (!title) {
      title = String(payload.title ?? "").trim() ||
        defaultGeneratedTitle({ topic, language, difficulty });
    }

    rawPool.push(...(Array.isArray(payload.items) ? payload.items : []));
    normalized = normalizeItems(rawPool, targetCount);

    if (normalized.length >= targetCount) {
      break;
    }
  }

  const finalTitle = requestedTitle || title ||
    defaultGeneratedTitle({ topic, language, difficulty });
  if (normalized.length < 5) {
    return json(502, {
      error: "too_few_items",
      count: normalized.length,
      usage: { date_key: dateKey, used, limit, premium: isPremium },
    });
  }

  if (normalized.length < targetCount) {
    return json(502, {
      error: "too_few_items",
      count: normalized.length,
      target: targetCount,
      usage: { date_key: dateKey, used, limit, premium: isPremium },
    });
  }

  return json(200, {
    title: finalTitle,
    language,
    items: normalized.slice(0, targetCount),
    usage: { date_key: dateKey, used, limit, premium: isPremium },
    max_items: maxItems,
  });
});
