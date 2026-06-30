// Edge Function: assistant-chat
//
// Agente nativo do Dashboard Galwan (substitui o webhook do n8n).
// Recebe { message, userEmail } do frontend, valida acesso, roda um agente
// OpenAI (gpt-5-mini) com tool-calling e memória em n8n_assistant_dash_history,
// e retorna { response: string }.
//
// Secrets (Project Settings → Edge Functions):
//   - OPENAI_API_KEY                (obrigatória — chat + embeddings)
//   - SUPABASE_URL                  (injetada automaticamente)
//   - SUPABASE_ANON_KEY             (injetada automaticamente)
//   - SUPABASE_SERVICE_ROLE_KEY     (injetada automaticamente)
// Opcionais:
//   - CHAT_MODEL                    (default gpt-5-mini)
//   - EMBEDDING_MODEL               (default text-embedding-3-small; troque para
//                                    text-embedding-ada-002 se o RAG vier ruim)

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"
import { handlePreflight, jsonResponse } from "../_shared/cors.ts"
import { SYSTEM_PROMPT } from "./system-prompt.ts"

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? ""
const CHAT_MODEL = Deno.env.get("CHAT_MODEL") ?? "gpt-5-mini"
const EMBEDDING_MODEL = Deno.env.get("EMBEDDING_MODEL") ?? "text-embedding-3-small"

const MAX_STEPS = 5
const HISTORY_WINDOW = 15
const PROJECTS_MATCH_COUNT = 8

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

// ---------------------------------------------------------------------------
// OpenAI
// ---------------------------------------------------------------------------

const openaiChat = async (messages: ChatMessage[]): Promise<ChatMessage> => {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: CHAT_MODEL,
      messages,
      tools: TOOL_DEFS,
      tool_choice: "auto",
      max_completion_tokens: 1500,
      reasoning_effort: "low",
    }),
  })

  if (!res.ok) {
    throw new Error(`OpenAI chat ${res.status}: ${(await res.text()).slice(0, 500)}`)
  }

  const data = await res.json()
  return data.choices?.[0]?.message as ChatMessage
}

const openaiEmbed = async (text: string): Promise<number[]> => {
  const res = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({ model: EMBEDDING_MODEL, input: text }),
  })

  if (!res.ok) {
    throw new Error(`OpenAI embeddings ${res.status}: ${(await res.text()).slice(0, 500)}`)
  }

  const data = await res.json()
  return data.data?.[0]?.embedding as number[]
}

// ---------------------------------------------------------------------------
// Tools (executadas com service role — o usuário já passou pela porta de acesso)
// ---------------------------------------------------------------------------

const TOOL_DEFS = [
  {
    type: "function",
    function: {
      name: "buscar_projetos",
      description:
        "Busca informações dos empreendimentos Galwan em base vetorizada. Use SEMPRE antes de responder sobre projetos: características, localização, quartos, disponibilidade, link ou nome.",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string", description: "A solicitação do usuário com o máximo de contexto." },
        },
        required: ["query"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_prompt_rafa",
      description:
        "Retorna o prompt atual do agente SDR Rafa salvo no banco. Ponto de partida obrigatório antes de sugerir qualquer mudança no comportamento dele.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function",
    function: {
      name: "get_alerts",
      description:
        "Retorna os alertas de alucinação detectados nas conversas do Rafa. Use para entender onde ele erra antes de propor ajustes.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function",
    function: {
      name: "get_suggestions",
      description:
        "Retorna sugestões de melhoria já mapeadas com base nas conversas do Rafa. Use junto com get_alerts e get_prompt_rafa.",
      parameters: { type: "object", properties: {} },
    },
  },
]

const runTool = async (
  name: string,
  argsJson: string,
  admin: SupabaseClient,
): Promise<string> => {
  try {
    if (name === "buscar_projetos") {
      const args = safeJson(argsJson) as { query?: string }
      const query = typeof args.query === "string" ? args.query : ""
      if (!query) return JSON.stringify({ error: "query vazia" })
      const embedding = await openaiEmbed(query)
      const { data, error } = await admin.rpc("match_documents", {
        query_embedding: JSON.stringify(embedding),
        match_count: PROJECTS_MATCH_COUNT,
      })
      if (error) return JSON.stringify({ error: "falha na busca de projetos" })
      const rows = (data ?? []) as Array<{ content?: string; similarity?: number }>
      return JSON.stringify(rows.map((r) => ({ content: r.content, similarity: r.similarity })))
    }

    if (name === "get_prompt_rafa") {
      const { data, error } = await admin
        .from("prompt")
        .select("identity, qualification_methodology, emojis, full_prompt, updated_at")
        .limit(1)
        .maybeSingle()
      if (error) return JSON.stringify({ error: "falha ao ler prompt" })
      return JSON.stringify(data ?? {})
    }

    if (name === "get_alerts") {
      const { data, error } = await admin
        .from("hallucination_alerts")
        .select("title, description, status, severity, number_incorrect_messages, created_at")
        .order("created_at", { ascending: false })
        .limit(30)
      if (error) return JSON.stringify({ error: "falha ao ler alertas" })
      return JSON.stringify(data ?? [])
    }

    if (name === "get_suggestions") {
      const { data, error } = await admin
        .from("improvement_suggestions")
        .select("category, problem_description, reason, solution, is_resolved, created_at")
        .order("created_at", { ascending: false })
        .limit(30)
      if (error) return JSON.stringify({ error: "falha ao ler sugestões" })
      return JSON.stringify(data ?? [])
    }

    return JSON.stringify({ error: `tool desconhecida: ${name}` })
  } catch (err) {
    console.error("[assistant-chat] tool error", { name, message: String(err) })
    return JSON.stringify({ error: "erro ao executar a ferramenta" })
  }
}

// ---------------------------------------------------------------------------
// Memória (n8n_assistant_dash_history — formato compatível com o frontend)
// ---------------------------------------------------------------------------

interface HistoryRow {
  message: { type?: string; content?: unknown; tool_calls?: unknown[] } | null
}

const loadHistory = async (admin: SupabaseClient, email: string): Promise<ChatMessage[]> => {
  const { data, error } = await admin
    .from("n8n_assistant_dash_history")
    .select("id, message")
    .eq("session_id", email)
    .order("id", { ascending: true })

  if (error) return []

  const mapped: ChatMessage[] = []
  for (const row of (data ?? []) as HistoryRow[]) {
    const m = row.message
    if (!m || typeof m !== "object") continue
    const content = typeof m.content === "string" ? m.content : ""
    if (!content) continue
    if (Array.isArray(m.tool_calls) && m.tool_calls.length > 0) continue
    if (m.type === "human") mapped.push({ role: "user", content })
    else if (m.type === "ai") mapped.push({ role: "assistant", content })
  }
  return mapped.slice(-HISTORY_WINDOW)
}

const saveTurn = async (
  admin: SupabaseClient,
  email: string,
  userMessage: string,
  aiMessage: string,
): Promise<void> => {
  await admin.from("n8n_assistant_dash_history").insert([
    {
      session_id: email,
      message: { type: "human", content: userMessage, additional_kwargs: {}, response_metadata: {} },
    },
    {
      session_id: email,
      message: { type: "ai", content: aiMessage, tool_calls: [], additional_kwargs: {}, response_metadata: {} },
    },
  ])
}

// ---------------------------------------------------------------------------
// Agente
// ---------------------------------------------------------------------------

const runAgent = async (
  admin: SupabaseClient,
  history: ChatMessage[],
  message: string,
): Promise<string> => {
  const messages: ChatMessage[] = [
    { role: "system", content: SYSTEM_PROMPT },
    ...history,
    { role: "user", content: message },
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

    if (typeof reply.content === "string" && reply.content.trim()) {
      return reply.content.trim()
    }
    break
  }

  return "Desculpe, não consegui processar sua mensagem agora. Tente novamente."
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

Deno.serve(async (req) => {
  const preflight = handlePreflight(req)
  if (preflight) return preflight
  const json = (status: number, body: Record<string, unknown>) => jsonResponse(req, status, body)
  if (req.method !== "POST") return json(405, { error: "Method not allowed" })

  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json(500, { error: "Missing Supabase env vars" })
  }
  if (!OPENAI_API_KEY) {
    return json(500, { error: "OPENAI_API_KEY não configurada" })
  }

  // Autenticação
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

  // Porta de acesso: is_active && (admin || permitted_areas contém 'chat')
  const { data: profile, error: profileError } = await callerClient
    .from("users")
    .select("role, is_active, permitted_areas")
    .eq("id", callerData.user.id)
    .maybeSingle()

  if (profileError || !profile) {
    return json(403, { error: "Acesso negado", code: "FORBIDDEN" })
  }

  const permittedAreas = Array.isArray(profile.permitted_areas) ? profile.permitted_areas : []
  const canUseChat =
    profile.is_active === true &&
    (profile.role === "admin" || permittedAreas.includes("chat"))

  if (!canUseChat) {
    return json(403, { error: "Você não pode acessar essa funcionalidade.", code: "FORBIDDEN" })
  }

  // Payload
  let message: string
  let userEmail: string
  try {
    const body = await req.json()
    message = typeof body.message === "string" ? body.message.trim() : ""
    userEmail =
      typeof body.userEmail === "string" && body.userEmail.trim()
        ? body.userEmail.trim()
        : (callerData.user.email ?? "")
    if (!message) return json(400, { error: "message obrigatório" })
    if (!userEmail) return json(400, { error: "userEmail obrigatório" })
  } catch {
    return json(400, { error: "Payload inválido" })
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  try {
    const history = await loadHistory(admin, userEmail)
    const response = await runAgent(admin, history, message)
    await saveTurn(admin, userEmail, message, response)
    return json(200, { response })
  } catch (err) {
    console.error("[assistant-chat] agent failure", { message: String(err) })
    return json(502, {
      error: "O assistente teve um problema. Tente novamente em instantes.",
      code: "AGENT_ERROR",
    })
  }
})
