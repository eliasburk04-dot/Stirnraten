// Supabase Edge Function: generate-wordlist
// Calls Groq Chat Completions and returns strict JSON:
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

function normalizeItems(items: unknown, requestedCount: number): string[] {
  if (!Array.isArray(items)) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const entry of items) {
    if (typeof entry !== "string") continue;
    let s = entry.trim();
    if (!s) continue;

    // Strip obvious bullet/number prefixes.
    s = s.replace(/^\s*[-*•]\s+/, "");
    s = s.replace(/^\s*\d+[\).\-\:]\s+/, "");
    s = s.trim();
    if (!s) continue;

    // No emojis (roughly): remove surrogate pairs / extended pictographs.
    // (Client also filters; this is a second line of defense.)
    s = s.replace(/\p{Extended_Pictographic}/gu, "").trim();
    if (!s) continue;

    // 1-3 "words" constraint.
    const words = s.split(/\s+/).filter(Boolean);
    if (words.length < 1 || words.length > 3) continue;

    // No super long terms.
    if (s.length > 64) continue;

    const key = s.toLocaleLowerCase();
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

function buildSystemPrompt(req: ClientRequest): string {
  // Prefer client-provided instructions (keeps parity with app prompt),
  // but force strict JSON and safety rules regardless.
  const base = (req.instructions ?? "").trim();
  const forced = `
Return STRICT JSON only in this schema:
{"title":"...","language":"de|en","items":["term1","term2"]}
Rules:
- Items: 1-3 words, no sentences
- No duplicates (case-insensitive)
- No emojis
- No numbering/bullets
- Avoid NSFW, hate, insults
`;
  if (base) return `${base}\n${forced}`.trim();
  return forced.trim();
}

function buildUserPrompt(input: ClientRequest["input"]): string {
  const tags = (input.styleTags ?? []).filter((t) => (t ?? "").trim().length > 0);
  return [
    `topic: ${input.topic}`,
    `language: ${input.language}`,
    `difficulty: ${input.difficulty}`,
    `target_count: ${input.count}`,
    `style_tags: ${tags.length ? tags.join(", ") : "none"}`,
    `include_hints: ${input.includeHints ? "true" : "false"}`,
  ].join("\n");
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
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!supabaseUrl || !supabaseAnon) {
    // Should be present by default in Edge Functions runtime, but keep a clear error.
    return json(500, { error: "supabase_env_missing" });
  }

  // Verify the JWT (anonymous sessions are authenticated as well).
  try {
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2.49.1");
    const sb = createClient(supabaseUrl, supabaseAnon, {
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
  if (topic.length < 2) return json(400, { error: "topic_too_short" });
  if (language !== "de" && language !== "en") return json(400, { error: "invalid_language" });
  if (difficulty !== "easy" && difficulty !== "medium" && difficulty !== "hard") {
    return json(400, { error: "invalid_difficulty" });
  }
  const requestedCount = clamp(Number.isFinite(count) ? count : 0, 5, 100);

  const groqApiKey = Deno.env.get("GROQ_API_KEY") ?? "";
  if (!groqApiKey) {
    return json(500, { error: "groq_api_key_missing" });
  }

  // Keep a sensible default (models can be deprecated; allow overriding via secret).
  const model = (Deno.env.get("GROQ_MODEL") ?? "llama-3.3-70b-versatile").trim();
  const temperature = Number(Deno.env.get("GROQ_TEMPERATURE") ?? "0.4");

  const system = buildSystemPrompt(body);
  const user = buildUserPrompt({
    ...input,
    topic,
    language,
    difficulty,
    count: requestedCount,
  } as any);

  // Retry once on 429 to smooth occasional spikes.
  for (let attempt = 0; attempt < 2; attempt++) {
    const raw = await callGroqChatCompletion({
      apiKey: groqApiKey,
      model,
      system,
      user,
      temperature: Number.isFinite(temperature) ? temperature : 0.4,
    });

    if ((raw as any)?.__rate_limited) {
      if (attempt === 0) {
        await sleep(900);
        continue;
      }
      return json(429, { error: "rate_limited" });
    }
    if ((raw as any)?.__error) {
      const status = Number((raw as any)?.status ?? 0);
      const body = String((raw as any)?.body ?? "");
      const detail = body.trim().slice(0, 240);
      return json(502, {
        error: "upstream_error",
        upstream_status: Number.isFinite(status) ? status : 0,
        detail,
      });
    }

    const payload = extractAIResponsePayload(raw);
    if (!payload) {
      return json(502, { error: "invalid_ai_response" });
    }

    const title = String(payload.title ?? "").trim() || `${topic} (${difficulty})`;
    const items = normalizeItems(payload.items, requestedCount);
    if (items.length < 5) {
      return json(502, { error: "too_few_items", count: items.length });
    }
    return json(200, { title, language, items });
  }

  return json(500, { error: "unexpected" });
});
