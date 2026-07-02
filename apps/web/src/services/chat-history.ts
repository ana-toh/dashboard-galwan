import { supabase } from "@/integrations/supabase/client"

export type ChatRole = "user" | "assistant"

export interface ChatHistoryMessage {
  id: number
  role: ChatRole
  content: string
}

interface RawMessage {
  type?: string
  content?: unknown
  tool_calls?: unknown
  additional_kwargs?: { tool_calls?: unknown } | null
}

const ROLE_BY_TYPE: Record<string, ChatRole> = {
  human: "user",
  ai: "assistant",
}

export async function fetchChatHistory(
  email: string,
): Promise<ChatHistoryMessage[]> {
  const { data, error } = await supabase
    .from("assistant_dash_history")
    .select("id, message")
    .eq("session_id", email)
    .order("id", { ascending: true })

  if (error) throw error

  const rows = (data ?? []) as Array<{ id: number; message: RawMessage | string | null }>

  return rows.flatMap((row) => {
    const raw = typeof row.message === "string"
      ? safeParse(row.message)
      : row.message
    if (!raw || typeof raw !== "object") return []

    if (raw.type === "tool") return []

    const role = ROLE_BY_TYPE[raw.type ?? ""]
    if (!role) return []

    if (hasToolCalls(raw)) return []

    const content = typeof raw.content === "string" ? raw.content : ""
    if (!content) return []

    return [{ id: row.id, role, content }]
  })
}

const hasToolCalls = (raw: RawMessage): boolean => {
  if (Array.isArray(raw.tool_calls) && raw.tool_calls.length > 0) return true
  const nested = raw.additional_kwargs?.tool_calls
  return Array.isArray(nested) && nested.length > 0
}

const safeParse = (value: string): RawMessage | null => {
  try {
    return JSON.parse(value) as RawMessage
  } catch {
    return null
  }
}

export async function deleteChatHistory(email: string): Promise<void> {
  const { error } = await supabase
    .from("assistant_dash_history")
    .delete()
    .eq("session_id", email)

  if (error) throw error
}
