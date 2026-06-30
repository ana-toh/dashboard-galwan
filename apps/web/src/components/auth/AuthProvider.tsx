import { useEffect, useState } from "react"
import type { ReactNode } from "react"
import type { Session, User } from "@supabase/supabase-js"

import { AuthContext } from "@/lib/auth-context"
import { logger, reportError } from "@/lib/logger"
import * as authService from "@/services/auth"

const MAX_SESSION_MS = 3 * 60 * 60 * 1000

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    authService.getSession().then(({ session: s, error }) => {
      if (error) {
        logger.error("[AuthProvider] Falha ao recuperar sessão:", error.message)
      }
      setSession(s)
      setUser(s?.user ?? null)
      setIsLoading(false)
    })

    const subscription = authService.onAuthStateChange((s) => {
      setSession(s)
      setUser(s?.user ?? null)
    })

    return () => subscription.unsubscribe()
  }, [])

  useEffect(() => {
    if (!session) return

    const loginAt = session.user.last_sign_in_at
      ? new Date(session.user.last_sign_in_at).getTime()
      : Date.now()

    const forceLogout = () => {
      void authService.signOut()
      setSession(null)
      setUser(null)
    }

    const checkExpired = () => {
      if (Date.now() - loginAt >= MAX_SESSION_MS) {
        forceLogout()
        return true
      }
      return false
    }

    if (checkExpired()) return

    const remaining = MAX_SESSION_MS - (Date.now() - loginAt)
    const timeout = window.setTimeout(forceLogout, remaining + 100)

    const onVisibility = () => {
      if (!document.hidden) checkExpired()
    }
    document.addEventListener("visibilitychange", onVisibility)

    return () => {
      window.clearTimeout(timeout)
      document.removeEventListener("visibilitychange", onVisibility)
    }
  }, [session])

  const signIn = async (email: string, password: string) => {
    const { user: signedUser, error } = await authService.signInWithPassword({ email, password })

    if (error) {
      const msg = error.message.toLowerCase()
      if (msg.includes("invalid login") || msg.includes("invalid_credentials")) {
        return { error: "E-mail ou senha incorretos." }
      }
      if (msg.includes("email not confirmed")) {
        return { error: "E-mail ainda não confirmado. Verifique sua caixa de entrada." }
      }
      if (msg.includes("rate limit") || msg.includes("too many requests")) {
        return { error: "Muitas tentativas. Aguarde alguns minutos e tente novamente." }
      }
      return { error: "Não foi possível fazer login. Tente novamente." }
    }

    if (signedUser) {
      try {
        const { exists, isActive } = await authService.fetchUserActiveStatus(signedUser.id)
        if (!exists || !isActive) {
          await authService.signOut()
          setSession(null)
          setUser(null)
          return { error: "Sua conta está desativada. Entre em contato com o administrador." }
        }
      } catch (err) {
        reportError(err, { scope: "AuthProvider.validateProfile" })
        await authService.signOut()
        setSession(null)
        setUser(null)
        return { error: "Não foi possível validar sua conta. Tente novamente." }
      }
    }

    return { error: null }
  }

  const signOut = async () => {
    const { error } = await authService.signOut()
    if (error) {
      logger.error("[AuthProvider] Falha ao fazer logout:", error.message)
    }
    setSession(null)
    setUser(null)
  }

  return (
    <AuthContext.Provider value={{ user, session, isLoading, signIn, signOut }}>
      {children}
    </AuthContext.Provider>
  )
}
