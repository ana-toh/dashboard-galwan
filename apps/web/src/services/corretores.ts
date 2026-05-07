import { supabase } from "@/integrations/supabase/client"
import { getChangedUpdateKeys } from "@/lib/changed-update-keys"
import { AppError } from "@/lib/errors"
import { logger } from "@/lib/logger"
import { formatLogDateTime, logEvent } from "@/services/logs"

const CORRETOR_FIELD_LABEL: Record<string, string> = {
  first_name: "nome",
  last_name: "sobrenome",
  email: "e-mail",
  whatsapp: "WhatsApp",
  calendar_color: "cor do calendário",
}

export interface BrokerAvailability {
  id: string
  broker_id: string | null
  available_date: string | null
  is_available: boolean | null
  start_time: string | null
  end_time: string | null
}

export interface Corretor {
  id: string
  first_name: string
  last_name: string
  email: string
  whatsapp: string
  calendar_color: string
  is_active: boolean
  disponibilidades: BrokerAvailability[]
}

interface BrokerRow {
  id: string
  first_name: string | null
  last_name: string | null
  email: string | null
  whatsapp: string | null
  calendar_color: string | null
  is_active: boolean | null
}

interface AvailabilityRow {
  id: string
  broker_id: string | null
  available_date: string | null
  is_available: boolean | null
  start_time: string | null
  end_time: string | null
}

export interface CreateCorretorInput {
  first_name: string
  last_name: string
  email: string
  whatsapp: string
  calendar_color: string
}

export interface UpdateCorretorInput {
  id: string
  first_name?: string
  last_name?: string
  email?: string
  whatsapp?: string
  calendar_color?: string
}

export interface AvailabilityPeriod {
  start_time: string | null
  end_time: string | null
}

export interface SaveAvailabilitiesForDayInput {
  broker_id: string
  available_date: string
  periodos: AvailabilityPeriod[]
}

function fail(prefix: string, err: { message?: string; code?: string }) {
  const tail = err.message ?? err.code
  throw new AppError(tail ? `${prefix}: ${tail}` : prefix, { cause: err })
}

export async function fetchCorretores(): Promise<Corretor[]> {
  const { data: brokersRaw, error: cErr } = await supabase
    .from("brokers")
    .select("id, first_name, last_name, email, whatsapp, calendar_color, is_active")
    .order("first_name")
  if (cErr) fail("Falha ao buscar corretores", cErr)

  const { data: disps, error: dErr } = await supabase
    .from("broker_availability")
    .select("id, broker_id, available_date, is_available, start_time, end_time")
  if (dErr) fail("Falha ao buscar disponibilidades", dErr)

  const rows = (brokersRaw ?? []) as BrokerRow[]
  const availabilities = (disps ?? []) as AvailabilityRow[]

  return rows.map((c) => ({
    id: c.id,
    first_name: c.first_name ?? "",
    last_name: c.last_name ?? "",
    email: c.email ?? "",
    whatsapp: c.whatsapp ?? "",
    calendar_color: c.calendar_color ?? "#3b82f6",
    is_active: c.is_active ?? true,
    disponibilidades: availabilities.filter((d) => d.broker_id === c.id),
  }))
}

export async function createCorretor(input: CreateCorretorInput): Promise<void> {
  const { error } = await supabase.from("brokers").insert(input)
  if (error) {
    logger.error("[createCorretor] Supabase error:", error)
    throw new AppError(`Falha ao cadastrar corretor: ${error.message}`, { cause: error })
  }
  const {
    data: { user },
  } = await supabase.auth.getUser()
  const email = user?.email ?? "—"
  const when = formatLogDateTime()
  void logEvent({
    action: "CREATE",
    feature: "corretores",
    description: `O usuário ${email} adicionou o corretor ${input.email} em ${when}.`,
  })
}

export async function updateCorretor(input: UpdateCorretorInput): Promise<void> {
  const { id, ...updates } = input
  const { data: before } = await supabase
    .from("brokers")
    .select("first_name, last_name, email, whatsapp, calendar_color")
    .eq("id", id)
    .maybeSingle()

  const { error } = await supabase.from("brokers").update(updates).eq("id", id)
  if (error) throw new AppError("Falha ao atualizar corretor", { cause: error })

  const changed = getChangedUpdateKeys(
    updates as Record<string, unknown>,
    (before ?? {}) as Record<string, unknown>,
  )
  if (changed.length === 0) return

  const { data: row } = await supabase.from("brokers").select("email").eq("id", id).maybeSingle()
  const emailCorretor = row?.email ?? "—"
  const {
    data: { user },
  } = await supabase.auth.getUser()
  const email = user?.email ?? "—"
  const when = formatLogDateTime()
  for (const key of changed) {
    const label = CORRETOR_FIELD_LABEL[key] ?? key
    void logEvent({
      action: "UPDATE",
      feature: "corretores",
      description: `O usuário ${email} alterou o campo "${label}" do corretor ${emailCorretor} em ${when}.`,
    })
  }
}

export async function deleteCorretor(input: { id: string }): Promise<void> {
  const { data: broker } = await supabase.from("brokers").select("email").eq("id", input.id).maybeSingle()
  const emailCorretor = broker?.email ?? "—"

  const { error: dErr } = await supabase
    .from("broker_availability")
    .delete()
    .eq("broker_id", input.id)
  if (dErr) throw new AppError("Falha ao remover disponibilidades do corretor", { cause: dErr })

  const { error } = await supabase.from("brokers").delete().eq("id", input.id)
  if (error) throw new AppError("Falha ao remover corretor", { cause: error })

  const {
    data: { user },
  } = await supabase.auth.getUser()
  const email = user?.email ?? "—"
  const when = formatLogDateTime()
  void logEvent({
    action: "DELETE",
    feature: "corretores",
    description: `O usuário ${email} excluiu o corretor ${emailCorretor} em ${when}.`,
  })
}

/** Chamar após importação bem-sucedida da planilha de disponibilidades (useSpreadsheetImport). */
export async function logPlanilhaCorretoresUpload(): Promise<void> {
  const {
    data: { user },
  } = await supabase.auth.getUser()
  const email = user?.email ?? "—"
  const when = formatLogDateTime()
  void logEvent({
    action: "CREATE",
    feature: "corretores",
    description: `O usuário ${email} fez upload da planilha de corretores em ${when}.`,
  })
}

export async function saveAvailabilitiesForDay(
  input: SaveAvailabilitiesForDayInput,
): Promise<void> {
  const { error: dErr } = await supabase
    .from("broker_availability")
    .delete()
    .eq("broker_id", input.broker_id)
    .eq("available_date", input.available_date)
  if (dErr) throw new AppError("Falha ao limpar disponibilidade anterior", { cause: dErr })

  if (input.periodos.length === 0) return

  const rows = input.periodos.map((p) => ({
    broker_id: input.broker_id,
    available_date: input.available_date,
    is_available: true,
    start_time: p.start_time || null,
    end_time: p.end_time || null,
  }))

  const { error } = await supabase.from("broker_availability").insert(rows)
  if (error) {
    logger.error("Falha ao salvar disponibilidades:", { rows, supabaseError: error })
    throw new AppError(
      `Falha ao salvar disponibilidades: ${error.message}${error.hint ? ` (${error.hint})` : ""}`,
      { cause: error },
    )
  }
}
