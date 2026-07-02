// Remove barra(s) final(is) para comparar origens de forma robusta
// (o browser envia "https://app.com", mas o secret pode ter "https://app.com/").
const stripTrailingSlash = (value: string): string => value.replace(/\/+$/, "")

const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((s) => stripTrailingSlash(s.trim()))
  .filter(Boolean)

const BASE_HEADERS = {
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
}

const resolveOrigin = (req: Request): string | null => {
  const origin = req.headers.get("Origin")
  if (!origin) return null
  return ALLOWED_ORIGINS.includes(stripTrailingSlash(origin)) ? origin : null
}

export const corsHeaders = (req: Request): Record<string, string> => {
  const allowed = resolveOrigin(req)
  if (!allowed) return BASE_HEADERS
  return { ...BASE_HEADERS, "Access-Control-Allow-Origin": allowed }
}

export const handlePreflight = (req: Request): Response | null => {
  if (req.method !== "OPTIONS") return null
  const allowed = resolveOrigin(req)
  if (!allowed) {
    return new Response("Origin not allowed", { status: 403, headers: BASE_HEADERS })
  }
  return new Response("ok", { headers: corsHeaders(req) })
}

export const jsonResponse = (
  req: Request,
  status: number,
  body: Record<string, unknown>,
) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  })
