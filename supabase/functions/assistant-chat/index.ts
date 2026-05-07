// Edge Function: assistant-chat
//
// Recebe { message, userEmail } do frontend e proxia para o webhook do n8n
// configurado na secret WEBHOOK_CHAT_APP. Retorna { response: string } com o
// texto gerado pelo agente.
//
// Envs obrigatórias (Project Settings → Edge Functions → Secrets):
//   - SUPABASE_URL
//   - SUPABASE_ANON_KEY
//   - WEBHOOK_CHAT_APP   (URL do webhook n8n)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"
import { handlePreflight, jsonResponse } from "../_shared/cors.ts"

interface ChatPayload {
  message: string
  userEmail: string
}

const extractResponseText = (raw: string): string => {
  try {
    const parsed = JSON.parse(raw)
    if (typeof parsed === "string") return parsed
    if (parsed && typeof parsed === "object") {
      const candidate =
        (parsed as Record<string, unknown>).response ??
        (parsed as Record<string, unknown>).output ??
        (parsed as Record<string, unknown>).text ??
        (parsed as Record<string, unknown>).message
      if (typeof candidate === "string") return candidate
    }
    return raw
  } catch {
    return raw
  }
}

Deno.serve(async (req) => {
  const preflight = handlePreflight(req)
  if (preflight) return preflight
  const json = (status: number, body: Record<string, unknown>) => jsonResponse(req, status, body)
  if (req.method !== "POST") return json(405, { error: "Method not allowed" })

  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")
  const webhookUrl = Deno.env.get("WEBHOOK_CHAT_APP")

  if (!supabaseUrl || !anonKey) {
    return json(500, { error: "Missing Supabase env vars" })
  }
  if (!webhookUrl) {
    return json(500, { error: "WEBHOOK_CHAT_APP não configurado" })
  }

  const authHeader = req.headers.get("Authorization") ?? ""
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return json(401, { error: "Missing bearer token", code: "UNAUTHENTICATED" })
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: callerData, error: callerError } = await callerClient.auth.getUser()
  if (callerError || !callerData.user) {
    return json(401, { error: "Invalid session", code: "UNAUTHENTICATED" })
  }

  let payload: ChatPayload
  try {
    const body = await req.json()
    const message = typeof body.message === "string" ? body.message.trim() : ""
    const userEmail =
      typeof body.userEmail === "string" && body.userEmail.trim()
        ? body.userEmail.trim()
        : (callerData.user.email ?? "")

    if (!message) return json(400, { error: "message obrigatório" })
    if (!userEmail) return json(400, { error: "userEmail obrigatório" })

    payload = { message, userEmail }
  } catch {
    return json(400, { error: "Payload inválido" })
  }

  const WEBHOOK_TIMEOUT_MS = 25_000
  const startedAt = Date.now()
  let webhookRes: Response
  let raw: string

  try {
    webhookRes = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(WEBHOOK_TIMEOUT_MS),
    })
    raw = await webhookRes.text()
  } catch (err) {
    const durationMs = Date.now() - startedAt
    const isTimeout = err instanceof DOMException && err.name === "TimeoutError"
    const kind = isTimeout ? "timeout" : "network"
    console.error("[assistant-chat] webhook failure", {
      kind,
      durationMs,
      message: err instanceof Error ? err.message : String(err),
    })
    return json(isTimeout ? 504 : 502, {
      error: isTimeout
        ? "O assistente demorou demais para responder. Tente novamente."
        : "Não foi possível conectar ao assistente. Tente novamente.",
      code: isTimeout ? "WEBHOOK_TIMEOUT" : "WEBHOOK_NETWORK_ERROR",
    })
  }

  if (!webhookRes.ok) {
    console.error("[assistant-chat] webhook http error", {
      kind: "http",
      status: webhookRes.status,
      durationMs: Date.now() - startedAt,
      body: raw.slice(0, 500),
    })
    return json(502, {
      error: "O assistente retornou um erro. Tente novamente em instantes.",
      code: "WEBHOOK_HTTP_ERROR",
      status: webhookRes.status,
    })
  }

  return json(200, { response: extractResponseText(raw) })
})
