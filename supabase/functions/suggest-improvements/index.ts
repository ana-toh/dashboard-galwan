// Edge Function: suggest-improvements
//
// Agente que lê os alertas de alucinação recentes (hallucination_alerts) e
// gera orientações acionáveis para a equipe técnica ajustar o agente Rafael,
// gravando em improvement_suggestions. Substitui o fluxo n8n
// "agente_orientações_alucinação".
//
// Disparo: pg_cron diário, 30 min após o review-hallucinations (não é
// user-facing). Autenticação por header `x-cron-secret` validado contra
// public.app_secrets (verify_cron_secret). Deploy com verify_jwt = false.
//
// Secrets: OPENAI_API_KEY + as injetadas (SUPABASE_URL/SERVICE_ROLE_KEY).
// Body opcional: { "sinceHours": 24 } — janela de alertas a considerar.

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"
import { buildSystemPrompt } from "./system-prompt.ts"

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? ""
const CHAT_MODEL = Deno.env.get("CHAT_MODEL") ?? "gpt-5-mini"
const EMBEDDING_MODEL = Deno.env.get("EMBEDDING_MODEL") ?? "text-embedding-3-small"

const RAFA_PROMPT_ID = "e633e778-04f7-4d61-9c80-900aaadfc5ee"
const MAX_ALERTS = 50
const MAX_SUGGESTIONS = 3
const MAX_STEPS = 4
const MATCH_COUNT = 5
const ALLOWED_CATEGORIES = new Set([
  "prompt",
  "dados_projetos",
  "metodologia_qualificacao",
  "identidade",
  "fluxo_operacional",
])

interface ChatMessage {
  role: "system" | "user" | "assistant" | "tool"
  content: string | null
  tool_calls?: ToolCall[]
  tool_call_id?: string
}

interface ToolCall {
  id: string
  type: "function"
  function: { name: string; arguments: string }
}

interface Suggestion {
  category: string
  description: string
  reason: string
  solution: string
}

// ---------------------------------------------------------------------------
// OpenAI
// ---------------------------------------------------------------------------

const TOOL_DEFS = [
  {
    type: "function",
    function: {
      name: "confirm_infos_projects",
      description:
        "Busca dados oficiais dos empreendimentos Galwan em base vetorizada para verificar se um alerta decorre de dado ausente/incorreto na base (características, localização, disponibilidade, nome, link).",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string", description: "O dado do empreendimento a verificar, com contexto." },
        },
        required: ["query"],
      },
    },
  },
]

const openaiChat = async (messages: ChatMessage[]): Promise<ChatMessage> => {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${OPENAI_API_KEY}` },
    body: JSON.stringify({
      model: CHAT_MODEL,
      messages,
      tools: TOOL_DEFS,
      tool_choice: "auto",
      max_completion_tokens: 3000,
      reasoning_effort: "low",
    }),
  })
  if (!res.ok) throw new Error(`OpenAI chat ${res.status}: ${(await res.text()).slice(0, 400)}`)
  const data = await res.json()
  return data.choices?.[0]?.message as ChatMessage
}

const openaiEmbed = async (text: string): Promise<number[]> => {
  const res = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${OPENAI_API_KEY}` },
    body: JSON.stringify({ model: EMBEDDING_MODEL, input: text }),
  })
  if (!res.ok) throw new Error(`OpenAI embeddings ${res.status}: ${(await res.text()).slice(0, 400)}`)
  const data = await res.json()
  return data.data?.[0]?.embedding as number[]
}

const runTool = async (name: string, argsJson: string, admin: SupabaseClient): Promise<string> => {
  if (name !== "confirm_infos_projects") return JSON.stringify({ error: `tool desconhecida: ${name}` })
  try {
    const args = safeJson(argsJson) as { query?: string }
    const query = typeof args.query === "string" ? args.query : ""
    if (!query) return JSON.stringify({ error: "query vazia" })
    const embedding = await openaiEmbed(query)
    const { data, error } = await admin.rpc("match_documents", {
      query_embedding: JSON.stringify(embedding),
      match_count: MATCH_COUNT,
    })
    if (error) return JSON.stringify({ error: "falha na busca de projetos" })
    const rows = (data ?? []) as Array<{ content?: string; similarity?: number }>
    return JSON.stringify(rows.map((r) => ({ content: r.content, similarity: r.similarity })))
  } catch (err) {
    console.error("[suggest-improvements] tool error", String(err))
    return JSON.stringify({ error: "erro ao executar a ferramenta" })
  }
}

// ---------------------------------------------------------------------------
// Alertas e geração de sugestões
// ---------------------------------------------------------------------------

interface AlertRow {
  title: string
  description: string
  severity: string
  number_incorrect_messages: number | null
  created_at: string
}

const buildAlertsMessage = (alerts: AlertRow[]): string => {
  const lines = alerts.map(
    (a, i) =>
      `${i + 1}. [${a.severity}] ${a.title}\n${a.description}\nMensagens incorretas: ${a.number_incorrect_messages ?? 0}`,
  )
  return `# Alertas de alucinação registrados na janela analisada\n\n${lines.join("\n\n")}`
}

const parseSuggestions = (raw: string): Suggestion[] => {
  const tryParse = (text: string): unknown => {
    try {
      return JSON.parse(text)
    } catch {
      return null
    }
  }
  let parsed = tryParse(raw.trim())
  if (parsed === null) {
    const match = raw.match(/[[{][\s\S]*[\]}]/)
    if (match) parsed = tryParse(match[0])
  }
  if (parsed === null) return []
  const arr = Array.isArray(parsed)
    ? parsed
    : Array.isArray((parsed as { suggestions?: unknown }).suggestions)
      ? (parsed as { suggestions: unknown[] }).suggestions
      : []
  return (arr as Array<Record<string, unknown>>)
    .map((item) => ({
      category: String(item.category ?? ""),
      description: String(item.description ?? ""),
      reason: String(item.reason ?? ""),
      solution: String(item.solution ?? ""),
    }))
    .filter((s) => ALLOWED_CATEGORIES.has(s.category) && s.description && s.solution)
    .slice(0, MAX_SUGGESTIONS)
}

const generateSuggestions = async (
  admin: SupabaseClient,
  alertsMessage: string,
  systemPrompt: string,
): Promise<Suggestion[]> => {
  const messages: ChatMessage[] = [
    { role: "system", content: systemPrompt },
    { role: "user", content: alertsMessage },
  ]
  for (let step = 0; step < MAX_STEPS; step++) {
    const reply = await openaiChat(messages)
    if (!reply) break
    if (reply.tool_calls && reply.tool_calls.length > 0) {
      messages.push(reply)
      for (const call of reply.tool_calls) {
        const result = await runTool(call.function.name, call.function.arguments, admin)
        messages.push({ role: "tool", tool_call_id: call.id, content: result })
      }
      continue
    }
    if (typeof reply.content === "string") return parseSuggestions(reply.content)
    break
  }
  return []
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

const safeJson = (value: string): Record<string, unknown> => {
  try {
    return JSON.parse(value) as Record<string, unknown>
  } catch {
    return {}
  }
}

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Method not allowed" })

  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  if (!supabaseUrl || !serviceKey) return json(500, { error: "Missing Supabase env vars" })
  if (!OPENAI_API_KEY) return json(500, { error: "OPENAI_API_KEY não configurada" })

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  // Autenticação por segredo do cron
  const cronSecret = req.headers.get("x-cron-secret") ?? ""
  const { data: authorized, error: authError } = await admin.rpc("verify_cron_secret", {
    candidate: cronSecret,
  })
  if (authError || authorized !== true) return json(401, { error: "Unauthorized", code: "BAD_CRON_SECRET" })

  // Janela
  let sinceHours = 24
  try {
    const body = await req.json()
    if (typeof body.sinceHours === "number" && body.sinceHours > 0) sinceHours = body.sinceHours
  } catch {
    // sem body — usa default
  }
  const sinceIso = new Date(Date.now() - sinceHours * 60 * 60 * 1000).toISOString()

  // Alertas na janela — sem alerta novo, não há o que orientar
  const { data: alerts, error: alertsError } = await admin
    .from("hallucination_alerts")
    .select("title, description, severity, number_incorrect_messages, created_at")
    .gte("created_at", sinceIso)
    .order("created_at", { ascending: false })
    .limit(MAX_ALERTS)
  if (alertsError) return json(500, { error: "Falha ao ler alertas" })
  if (!alerts || alerts.length === 0) {
    const summary = { sinceHours, alertsFound: 0, suggestionsCreated: 0 }
    console.log("[suggest-improvements] done", summary)
    return json(200, summary)
  }

  // Carrega prompt do Rafa (estado vigente das regras)
  const { data: promptRow } = await admin
    .from("prompt")
    .select("identity, qualification_methodology, emojis, full_prompt")
    .eq("id", RAFA_PROMPT_ID)
    .maybeSingle()
  const rafaPrompt = [
    promptRow?.full_prompt,
    promptRow?.identity && `Identidade: ${promptRow.identity}`,
    promptRow?.qualification_methodology && `Metodologia: ${promptRow.qualification_methodology}`,
    promptRow?.emojis && `Emojis: ${promptRow.emojis}`,
  ]
    .filter(Boolean)
    .join("\n\n")
  const systemPrompt = buildSystemPrompt(rafaPrompt || "(prompt do Rafael indisponível)")

  let suggestionsCreated = 0
  try {
    const suggestions = await generateSuggestions(
      admin,
      buildAlertsMessage(alerts as AlertRow[]),
      systemPrompt,
    )
    if (suggestions.length > 0) {
      const { error: insertError } = await admin.from("improvement_suggestions").insert(
        suggestions.map((s) => ({
          category: s.category,
          problem_description: s.description,
          reason: s.reason,
          solution: s.solution,
        })),
      )
      if (insertError) return json(500, { error: "Falha ao gravar sugestões" })
      suggestionsCreated = suggestions.length
    }
  } catch (err) {
    console.error("[suggest-improvements] error", String(err))
    return json(500, { error: "Falha ao gerar sugestões" })
  }

  const summary = { sinceHours, alertsFound: alerts.length, suggestionsCreated }
  console.log("[suggest-improvements] done", summary)
  return json(200, summary)
})
