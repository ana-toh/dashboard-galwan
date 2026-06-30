import type { AuthError, EmailOtpType, Session, User } from "@supabase/supabase-js"

import { supabase } from "@/integrations/supabase/client"
import { AppError, ForbiddenError, isForbiddenSupabaseError } from "@/lib/errors"

const EMAIL_OTP_TYPES = new Set<EmailOtpType>([
  "signup",
  "invite",
  "magiclink",
  "recovery",
  "email_change",
  "email",
])

const isEmailOtpType = (value: string): value is EmailOtpType =>
  EMAIL_OTP_TYPES.has(value as EmailOtpType)

/** Indica se a URL ainda carrega parâmetros típicos de convite / recovery (PKCE ou fragmento). */
export const hasIncomingAuthSignal = (): boolean => {
  if (typeof window === "undefined") return false
  const { search, hash } = window.location
  if (search.includes("code=") || search.includes("token_hash=")) return true
  return /access_token|type=invite|type=recovery/i.test(hash)
}

const passwordResetQuotaKey = (email: string) =>
  `galwan.password_reset_quota:${email.trim().toLowerCase()}`

const todayLocalIsoDate = (): string => {
  const d = new Date()
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, "0")
  const day = String(d.getDate()).padStart(2, "0")
  return `${y}-${m}-${day}`
}

/** Limite de produto: 2 solicitações por dia por e-mail (cliente; reforçar no backend se necessário). */
export const getPasswordResetQuotaError = (email: string): string | null => {
  if (typeof window === "undefined") return null
  const key = passwordResetQuotaKey(email)
  const raw = window.localStorage.getItem(key)
  if (!raw) return null
  try {
    const parsed = JSON.parse(raw) as { day?: string; count?: number }
    const day = typeof parsed.day === "string" ? parsed.day : ""
    const count = typeof parsed.count === "number" ? parsed.count : 0
    if (day !== todayLocalIsoDate()) return null
    if (count >= 2) return "Limite de 2 solicitações por dia para este e-mail. Tente novamente amanhã."
  } catch {
    window.localStorage.removeItem(key)
  }
  return null
}

export const recordPasswordResetRequest = (email: string): void => {
  if (typeof window === "undefined") return
  const key = passwordResetQuotaKey(email)
  const today = todayLocalIsoDate()
  const raw = window.localStorage.getItem(key)
  let count = 0
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as { day?: string; count?: number }
      if (parsed.day === today && typeof parsed.count === "number") count = parsed.count
    } catch {
      /* ignore */
    }
  }
  window.localStorage.setItem(key, JSON.stringify({ day: today, count: count + 1 }))
}

/** Troca código PKCE / verifica token_hash do e-mail e atualiza a sessão no storage. */
export const completeAuthFromUrl = async (): Promise<{ error: AuthError | null }> => {
  const url = new URL(window.location.href)

  const code = url.searchParams.get("code")
  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    url.searchParams.delete("code")
    window.history.replaceState({}, "", `${url.pathname}${url.search}${url.hash}`)
    if (error) return { error }
  }

  const token_hash = url.searchParams.get("token_hash")
  const typeParam = url.searchParams.get("type")
  if (token_hash && typeParam && isEmailOtpType(typeParam)) {
    const { error } = await supabase.auth.verifyOtp({ type: typeParam, token_hash })
    ;["token_hash", "type"].forEach((k) => url.searchParams.delete(k))
    window.history.replaceState({}, "", `${url.pathname}${url.search}${url.hash}`)
    if (error) return { error }
  }

  await supabase.auth.getSession()
  return { error: null }
}

interface SignInInput {
  email: string
  password: string
}

interface AuthResult {
  user: User | null
  session: Session | null
  error: AuthError | null
}

export const signInWithPassword = async ({ email, password }: SignInInput): Promise<AuthResult> => {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  return { user: data.user, session: data.session, error }
}

export interface UserActiveStatus {
  exists: boolean
  isActive: boolean
}

/**
 * Valida o perfil do usuário pós-login: existência e flag `is_active`.
 * Lança `ForbiddenError`/`AppError` em falha de acesso/consulta (RLS, rede).
 */
export const fetchUserActiveStatus = async (userId: string): Promise<UserActiveStatus> => {
  const { data, error } = await supabase
    .from("users")
    .select("is_active")
    .eq("id", userId)
    .maybeSingle()

  if (error) {
    if (isForbiddenSupabaseError(error)) throw new ForbiddenError(undefined, { cause: error })
    throw new AppError("Falha ao validar perfil do usuário", { cause: error })
  }

  return { exists: Boolean(data), isActive: data?.is_active === true }
}

export const signOut = async (): Promise<{ error: AuthError | null }> => {
  const { error } = await supabase.auth.signOut()
  return { error }
}

export const getSession = async (): Promise<{ session: Session | null; error: AuthError | null }> => {
  const { data, error } = await supabase.auth.getSession()
  return { session: data.session, error }
}

export const resetPasswordForEmail = async (email: string, redirectTo: string): Promise<{ error: AuthError | null }> => {
  const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo })
  return { error }
}

export const updateUserPassword = async (password: string): Promise<{ error: AuthError | null }> => {
  const { error } = await supabase.auth.updateUser({ password })
  return { error }
}

export const onAuthStateChange = (callback: (session: Session | null) => void) => {
  const { data } = supabase.auth.onAuthStateChange((_event, session) => {
    callback(session)
  })
  return data.subscription
}
