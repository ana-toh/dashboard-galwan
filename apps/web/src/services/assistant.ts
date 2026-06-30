import { supabase, supabaseEnv } from "@/integrations/supabase/client"
import { AppError } from "@/lib/errors"

const CHAT_URL = supabaseEnv.VITE_SUPABASE_FUNCTIONS_URL
  ? `${supabaseEnv.VITE_SUPABASE_FUNCTIONS_URL}/assistant-chat`
  : `${supabaseEnv.VITE_SUPABASE_URL}/functions/v1/assistant-chat`

interface SendAssistantMessageInput {
  message: string
  /** E-mail de fallback caso o usuário autenticado não exponha um. */
  fallbackEmail?: string
}

interface SendAssistantMessageOutput {
  reply: string
  email: string
}

/**
 * Envia uma mensagem ao assistente (edge function `assistant-chat`) usando o
 * token da sessão atual. Lança `AppError` se não autenticado ou em falha de rede.
 */
export const sendAssistantMessage = async ({
  message,
  fallbackEmail,
}: SendAssistantMessageInput): Promise<SendAssistantMessageOutput> => {
  const {
    data: { session },
  } = await supabase.auth.getSession()

  if (!session) {
    throw new AppError("Você precisa estar autenticado para usar o assistente", {
      code: "UNAUTHENTICATED",
    })
  }

  const {
    data: { user },
  } = await supabase.auth.getUser()
  const email = user?.email ?? fallbackEmail ?? ""

  const response = await fetch(CHAT_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${session.access_token}`,
    },
    body: JSON.stringify({ message, userEmail: email }),
  })

  const data = (await response.json()) as { response?: string; error?: string }

  if (!response.ok) {
    throw new AppError("Falha ao conectar com o assistente", { cause: data.error })
  }

  return { reply: data.response || "Sem resposta", email }
}
