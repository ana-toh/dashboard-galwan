// deno-lint-ignore-file no-explicit-any
// Edge Function: invite-user
//
// Chamada pelo frontend (admin autenticado) para convidar um novo usuário.
// Usa a service_role key para:
//   1. Validar que o chamador é admin ativo (public.users).
//   2. Disparar auth.admin.inviteUserByEmail — envia o e-mail via SMTP configurado
//      (Resend no painel → Authentication → Email Templates → Invite user).
//   3. Atualizar public.users com role + permitted_areas definidos pelo admin.
//
// Envs obrigatórias (painel → Project Settings → Edge Functions → Secrets):
//   - SUPABASE_URL
//   - SUPABASE_ANON_KEY
//   - SUPABASE_SERVICE_ROLE_KEY
//   - INVITE_REDIRECT_TO   (ex.: https://galwan.theoutsiderhub.com/definir-senha)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"
import { handlePreflight, jsonResponse } from "../_shared/cors.ts"

const AREA_SLUGS = ["prompt", "brokers", "chat", "insights", "projects", "leads"] as const
type AreaSlug = typeof AREA_SLUGS[number]
type UserRole = "admin" | "colaborador"

interface InvitePayload {
  email: string
  role: UserRole
  permittedAreas: AreaSlug[]
}

const isAreaSlug = (value: unknown): value is AreaSlug =>
  typeof value === "string" && (AREA_SLUGS as readonly string[]).includes(value)

Deno.serve(async (req) => {
  const preflight = handlePreflight(req)
  if (preflight) return preflight
  const json = (status: number, body: Record<string, unknown>) => jsonResponse(req, status, body)
  if (req.method !== "POST") return json(405, { error: "Method not allowed" })

  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  const redirectTo = Deno.env.get("INVITE_REDIRECT_TO")

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json(500, { error: "Missing Supabase env vars" })
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

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data: callerProfile, error: callerProfileError } = await admin
    .from("users")
    .select("role, is_active")
    .eq("id", callerData.user.id)
    .maybeSingle()

  if (callerProfileError) {
    return json(500, { error: "Failed to load caller profile" })
  }
  if (!callerProfile || callerProfile.role !== "admin" || callerProfile.is_active !== true) {
    return json(403, { error: "Forbidden", code: "FORBIDDEN" })
  }

  let payload: InvitePayload
  try {
    const body = await req.json()
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : ""
    const role = body.role === "admin" || body.role === "colaborador" ? body.role : null
    const rawAreas = Array.isArray(body.permittedAreas) ? body.permittedAreas : []
    const permittedAreas = rawAreas.filter(isAreaSlug)

    if (!email || !email.includes("@")) return json(400, { error: "E-mail inválido" })
    if (!role) return json(400, { error: "Perfil inválido" })
    if (role === "colaborador" && permittedAreas.length === 0) {
      return json(400, { error: "Selecione ao menos uma área para o colaborador" })
    }

    payload = { email, role, permittedAreas }
  } catch {
    return json(400, { error: "Payload inválido" })
  }

  const { data: inviteData, error: inviteError } = await admin.auth.admin.inviteUserByEmail(
    payload.email,
    redirectTo ? { redirectTo } : undefined,
  )

  if (inviteError) {
    const message = inviteError.message?.toLowerCase() ?? ""
    if (message.includes("already") || message.includes("registered")) {
      return json(409, { error: "Já existe um usuário com esse e-mail", code: "USER_EXISTS" })
    }
    return json(500, { error: inviteError.message })
  }

  const newUserId = inviteData.user?.id
  if (!newUserId) return json(500, { error: "Supabase não retornou o ID do usuário convidado" })

  const effectiveAreas = payload.role === "admin" ? [] : payload.permittedAreas

  const { error: updateError } = await admin
    .from("users")
    .update({ role: payload.role, permitted_areas: effectiveAreas })
    .eq("id", newUserId)

  if (updateError) {
    return json(500, {
      error: "Convite enviado, mas falhou ao aplicar perfil/áreas",
      userId: newUserId,
    })
  }

  return json(200, { userId: newUserId })
})
