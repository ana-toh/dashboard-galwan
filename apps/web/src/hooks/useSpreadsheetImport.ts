import { useState } from "react"
import { toast } from "sonner"
import type { Corretor } from "@/services/corretores"
import type { UseMutationResult } from "@tanstack/react-query"
import {
  logPlanilhaCorretoresUpload,
  type SaveAvailabilitiesForDayInput,
} from "@/services/corretores"
import { logger } from "@/lib/logger"
import {
  extractTimesFromRowSlice,
  parseAvailabilityDateCell,
} from "@/lib/spreadsheet-disponibilidade"

interface PreviewData {
  valid: { corretorNome: string; date: string; displayDate: string; startTime: string; endTime: string }[]
  errors: { linha: number; motivo: string }[]
  groupedData: Record<string, SaveAvailabilitiesForDayInput>
}

const MAX_SPREADSHEET_SIZE = 2 * 1024 * 1024 // 2 MB
const ALLOWED_SPREADSHEET_TYPES = new Set([
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "application/vnd.ms-excel",
  "text/csv",
])

export function useSpreadsheetImport(
  corretores: Corretor[],
  saveAvailabilitiesDayMutation: UseMutationResult<void, Error, SaveAvailabilitiesForDayInput>,
  onImportComplete: () => void,
) {
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [isProcessing, setIsProcessing] = useState(false)
  const [previewData, setPreviewData] = useState<PreviewData | null>(null)

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    e.target.value = ""
    if (!file) return

    if (!ALLOWED_SPREADSHEET_TYPES.has(file.type) && !file.name.match(/\.(xlsx?|csv)$/i)) {
      toast.error("Envie apenas arquivos .xlsx, .xls ou .csv")
      return
    }
    if (file.size > MAX_SPREADSHEET_SIZE) {
      toast.error("Arquivo muito grande. Máximo: 2 MB.")
      return
    }

    setSelectedFile(file)
  }

  const resetUploadState = () => {
    setSelectedFile(null)
    setPreviewData(null)
    setIsProcessing(false)
  }

  const downloadExcelModel = async () => {
    const XLSX = await import("xlsx")
    const ws = XLSX.utils.aoa_to_sheet([
      ["Email do Corretor", "Data (DD/MM/YYYY)", "Horário Início (HH:MM)", "Horário Fim (HH:MM)"],
      ["corretor@email.com", "01/04/2026", "09:00", "12:00"],
      ["corretor@email.com", "01/04/2026", "14:00", "18:00"],
      ["corretor@email.com", "02/04/2026", "08:00", "17:00"],
    ])
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, ws, "Disponibilidades")
    XLSX.writeFile(wb, "modelo_disponibilidades.xlsx")
  }

  const analyzeSpreadsheet = async () => {
    if (!selectedFile) return
    setIsProcessing(true)
    try {
      const XLSX = await import("xlsx")
      const buffer = await selectedFile.arrayBuffer()
      const wb = XLSX.read(buffer)
      const ws = wb.Sheets[wb.SheetNames[0]]
      const rows = XLSX.utils.sheet_to_json(ws, {
        header: 1,
        raw: false,
      }) as (string | null | undefined)[][]

      const valid: PreviewData["valid"] = []
      const errors: PreviewData["errors"] = []
      const groupedData: PreviewData["groupedData"] = {}

      rows.slice(1).forEach((row: (string | null | undefined)[], idx: number) => {
        const lineNum = idx + 2
        const email = String(row[0] ?? "").trim()
        const dateCell = row[1]
        const dateRawDisplay = String(dateCell ?? "").trim()

        const { start: startTime, end: endTime, error: timeError } = extractTimesFromRowSlice(row)

        if (!email && !dateRawDisplay && !startTime && !endTime) return

        if (!email || dateCell === null || dateCell === undefined || String(dateCell).trim() === "") {
          errors.push({ linha: lineNum, motivo: "Email e data são obrigatórios" })
          return
        }

        const corretor = corretores.find((c) => c.email.toLowerCase() === email.toLowerCase())
        if (!corretor) {
          errors.push({ linha: lineNum, motivo: `Corretor não encontrado: ${email}` })
          return
        }

        const dateFormatted = parseAvailabilityDateCell(dateCell)
        if (!dateFormatted) {
          errors.push({
            linha: lineNum,
            motivo: `Data inválida: ${dateRawDisplay || "(vazio)"}. Use DD/MM/AAAA ou AAAA-MM-DD.`,
          })
          return
        }

        if (timeError) {
          errors.push({ linha: lineNum, motivo: timeError })
          return
        }

        if (startTime && endTime && startTime >= endTime) {
          errors.push({ linha: lineNum, motivo: "Horário início deve ser antes do horário fim" })
          return
        }

        const key = `${corretor.id}_${dateFormatted}`
        const periodo = { start_time: startTime ?? null, end_time: endTime ?? null }

        if (!groupedData[key]) {
          groupedData[key] = {
            broker_id: corretor.id,
            available_date: dateFormatted,
            periodos: [periodo],
          }
        } else {
          const exists = groupedData[key].periodos.some(
            (p) => p.start_time === periodo.start_time && p.end_time === periodo.end_time,
          )
          if (!exists) groupedData[key].periodos.push(periodo)
        }

        const [yy, mm, dd] = dateFormatted.split("-")
        valid.push({
          corretorNome: `${corretor.first_name} ${corretor.last_name}`,
          date: dateFormatted,
          displayDate: `${dd}/${mm}/${yy}`,
          startTime: startTime ?? "-",
          endTime: endTime ?? "-",
        })
      })

      setPreviewData({ valid, errors, groupedData })
    } catch {
      toast.error("Erro ao analisar planilha.")
    } finally {
      setIsProcessing(false)
    }
  }

  const confirmImport = async () => {
    if (!previewData) return
    setIsProcessing(true)
    const failures: { entry: SaveAvailabilitiesForDayInput; error: unknown }[] = []
    try {
      for (const entry of Object.values(previewData.groupedData)) {
        try {
          await saveAvailabilitiesDayMutation.mutateAsync(entry)
        } catch (err) {
          failures.push({ entry, error: err })
        }
      }
      await logPlanilhaCorretoresUpload()

      if (failures.length === 0) {
        toast.success("Importação concluída!")
        resetUploadState()
        onImportComplete()
      } else {
        const total = Object.values(previewData.groupedData).length
        const ok = total - failures.length
        logger.error("Falhas na importação:", failures)
        const firstMsg =
          failures[0].error instanceof Error ? failures[0].error.message : "Erro desconhecido"
        toast.error(
          `${failures.length} de ${total} dia(s) falharam (${ok} salvos). Primeiro erro: ${firstMsg}`,
        )
      }
    } catch (err) {
      logger.error("Erro durante a importação:", err)
      toast.error("Erro durante a importação.")
    } finally {
      setIsProcessing(false)
    }
  }

  return {
    selectedFile,
    isProcessing,
    previewData,
    handleFileSelect,
    resetUploadState,
    downloadExcelModel,
    analyzeSpreadsheet,
    confirmImport,
  }
}
