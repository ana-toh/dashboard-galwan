import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"

import { logger } from "@/lib/logger"
import {
  fetchCorretores,
  createCorretor,
  updateCorretor,
  deleteCorretor,
  saveAvailabilitiesForDay,
} from "@/services/corretores"
import type { SaveAvailabilitiesForDayInput } from "@/services/corretores"

export type { Corretor, BrokerAvailability } from "@/services/corretores"

const CORRETORES_KEY = ["corretores"] as const

export function useCorretores() {
  const queryClient = useQueryClient()

  const { data: corretores = [], isLoading, error, isError, refetch } = useQuery({
    queryKey: CORRETORES_KEY,
    queryFn: fetchCorretores,
    staleTime: 1000 * 60 * 5,
  })

  const saveAvailabilitiesDayMutation = useMutation({
    mutationFn: (input: SaveAvailabilitiesForDayInput) => saveAvailabilitiesForDay(input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: CORRETORES_KEY })
      toast.success("Disponibilidade salva!")
    },
    onError: (err) => toast.error(err.message || "Erro ao salvar disponibilidade."),
  })

  const createCorretorMutation = useMutation({
    mutationFn: (input: {
      first_name: string
      last_name: string
      email: string
      whatsapp: string
      calendar_color: string
    }) => createCorretor(input),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: CORRETORES_KEY })
      toast.success("Corretor cadastrado!")
    },
    onError: (err) => {
      logger.error("Erro ao cadastrar corretor:", err.cause ?? err)
      toast.error(err.message || "Erro ao cadastrar corretor.")
    },
  })

  const updateCorretorMutation = useMutation({
    mutationFn: ({ id, ...updates }: { id: string } & Partial<{ first_name: string; last_name: string; email: string; whatsapp: string; calendar_color: string }>) =>
      updateCorretor({ id, ...updates }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: CORRETORES_KEY })
      toast.success("Corretor atualizado!")
    },
    onError: (err) => toast.error(err.message || "Erro ao atualizar corretor."),
  })

  const deleteCorretorMutation = useMutation({
    mutationFn: (id: string) => deleteCorretor({ id }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: CORRETORES_KEY })
      toast.success("Corretor removido!")
    },
    onError: (err) => toast.error(err.message || "Erro ao remover corretor."),
  })

  return {
    corretores,
    isLoading,
    error,
    isError,
    refetch,
    saveAvailabilitiesDayMutation,
    createCorretorMutation,
    updateCorretorMutation,
    deleteCorretorMutation,
  }
}
