// Edge Function: review-hallucinations
//
// Agente de QA que avalia as conversas do Rafa (n8n_history) e registra
// inconsistências em hallucination_alerts. Substitui os fluxos n8n
// "agente_alertas_alucinacao" + "inserir_alertas_supabase".
//
// Disparo: pg_cron diário (não é user-facing). Autenticação por header
// `x-cron-secret` validado contra public.app_secrets (verify_cron_secret).
// Deploy com verify_jwt = false.
//
// Secrets: OPENAI_API_KEY + as injetadas (SUPABASE_URL/SERVICE_ROLE_KEY).
// Body opcional: { "sinceHours": 24 } — janela de conversas a avaliar.

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"
import { buildSystemPrompt } from "./system-prompt.ts"

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? ""
const CHAT_MODEL = Deno.env.get("CHAT_MODEL") ?? "gpt-5-mini"
const EMBEDDING_MODEL = Deno.env.get("EMBEDDING_MODEL") ?? "text-embedding-3-small"

const RAFA_PROMPT_ID = "e633e778-04f7-4d61-9c80-900aaadfc5ee"
const MIN_MESSAGES = 4
const MAX_SESSIONS = 40
const MAX_STEPS = 4
const MATCH_COUNT = 7
const ALLOWED_SEVERITY = new Set(["Alto", "Médio", "Baixo"])

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

interface Inconsistency {
  title: string
  description: string
  severity: string
  incorrect_messages_count: number
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
        "Busca dados oficiais dos empreendimentos Galwan em base vetorizada para validar informações mencionadas na conversa (características, localização, disponibilidade, nome, link).",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string", description: "O dado do empreendimento a validar, com contexto." },
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
    console.error("[review-hallucinations] tool error", String(err))
    return JSON.stringify({ error: "erro ao executar a ferramenta" })
  }
}

// ---------------------------------------------------------------------------
// Conversa e avaliação
// ---------------------------------------------------------------------------

interface HistoryRow {
  session_id: string
  created_at: string
  message: { type?: string; content?: unknown } | null
}

const buildConversation = (rows: HistoryRow[]): string => {
  const sorted = [...rows].sort(
    (a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime(),
  )
  let count = 1
  const lines: string[] = []
  for (const row of sorted) {
    const msg = row.message
    if (!msg) continue
    const type = msg.type
    const content = typeof msg.content === "string" ? msg.content : ""
    if (!content) continue
    if (type !== "ai" && type !== "human") continue
    if (content.startsWith("Calling")) continue
    if (type === "ai") lines.push(`${count}. 🤖 Agente:\n${content}`)
    else {
      lines.push(`💬 Usuário:\n${content}\n`)
      count++
    }
  }
  return lines.join("\n")
}

const parseInconsistencies = (raw: string): Inconsistency[] => {
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
  if (parsed === false || parsed === null) return []
  const arr = Array.isArray(parsed)
    ? parsed
    : Array.isArray((parsed as { inconsistencies?: unknown }).inconsistencies)
      ? (parsed as { inconsistencies: unknown[] }).inconsistencies
      : []
  return (arr as Array<Record<string, unknown>>)
    .map((item) => ({
      title: String(item.title ?? "").slice(0, 300),
      description: String(item.description ?? ""),
      severity: String(item.severity ?? ""),
      incorrect_messages_count: Number(item.incorrect_messages_count ?? 0) || 0,
    }))
    .filter((i) => i.title && ALLOWED_SEVERITY.has(i.severity))
}

const evalConversation = async (
  admin: SupabaseClient,
  conversation: string,
  systemPrompt: string,
): Promise<Inconsistency[]> => {
  const messages: ChatMessage[] = [
    { role: "system", content: systemPrompt },
    { role: "user", content: conversation },
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
    if (typeof reply.content === "string") return parseInconsistencies(reply.content)
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

  // Carrega prompt do Rafa (referência) uma vez
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

  // Busca conversas na janela e agrupa por sessão
  const { data: rows, error: rowsError } = await admin
    .from("n8n_history")
    .select("session_id, message, created_at")
    .gte("created_at", sinceIso)
  if (rowsError) return json(500, { error: "Falha ao ler histórico" })

  const bySession = new Map<string, HistoryRow[]>()
  for (const row of (rows ?? []) as HistoryRow[]) {
    if (!row.session_id) continue
    const list = bySession.get(row.session_id) ?? []
    list.push(row)
    bySession.set(row.session_id, list)
  }

  // Dedup: sessões já avaliadas cuja última mensagem não mudou
  const sessionIds = [...bySession.keys()]
  const { data: reviewed } = await admin
    .from("hallucination_reviewed_sessions")
    .select("session_id, last_message_at")
    .in("session_id", sessionIds.length ? sessionIds : ["__none__"])
  const reviewedMap = new Map<string, number>(
    ((reviewed ?? []) as Array<{ session_id: string; last_message_at: string }>).map((r) => [
      r.session_id,
      new Date(r.last_message_at).getTime(),
    ]),
  )

  let sessionsReviewed = 0
  let alertsCreated = 0
  let skipped = 0

  for (const [sessionId, sessionRows] of bySession) {
    if (sessionsReviewed >= MAX_SESSIONS) break
    if (sessionRows.length < MIN_MESSAGES) {
      skipped++
      continue
    }
    const lastMessageAt = Math.max(...sessionRows.map((r) => new Date(r.created_at).getTime()))
    const prevReviewed = reviewedMap.get(sessionId)
    if (prevReviewed !== undefined && prevReviewed >= lastMessageAt) {
      skipped++
      continue
    }

    try {
      const conversation = buildConversation(sessionRows)
      if (!conversation.trim()) {
        skipped++
        continue
      }
      const inconsistencies = await evalConversation(admin, conversation, systemPrompt)

      if (inconsistencies.length > 0) {
        const { error: insertError } = await admin.from("hallucination_alerts").insert(
          inconsistencies.map((i) => ({
            title: i.title,
            description: i.description,
            severity: i.severity,
            number_incorrect_messages: i.incorrect_messages_count,
          })),
        )
        if (!insertError) alertsCreated += inconsistencies.length
      }

      await admin.from("hallucination_reviewed_sessions").upsert({
        session_id: sessionId,
        last_message_at: new Date(lastMessageAt).toISOString(),
        last_reviewed_at: new Date().toISOString(),
        alerts_created: inconsistencies.length,
      })
      sessionsReviewed++
    } catch (err) {
      console.error("[review-hallucinations] session error", { sessionId, message: String(err) })
    }
  }

  const summary = {
    sinceHours,
    sessionsConsidered: bySession.size,
    sessionsReviewed,
    skipped,
    alertsCreated,
  }
  console.log("[review-hallucinations] done", summary)
  return json(200, summary)
})
