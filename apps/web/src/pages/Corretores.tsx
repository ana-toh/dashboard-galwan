import { format } from "date-fns"
import { ptBR } from "date-fns/locale"
import {
  CalendarDays,
  Clock,
  Edit2,
  Save,
  X,
  Upload,
  FileSpreadsheet,
  FileCheck,
  Trash2,
  Info,
  Users,
  UserPlus,
} from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Separator } from "@/components/ui/separator"
import { Textarea } from "@/components/ui/textarea"
import { ConfirmDialog } from "@/components/shared/ConfirmDialog"
import { ErrorState } from "@/components/shared/ErrorState"
import { LoadingState } from "@/components/shared/LoadingState"
import { CorretoresCalendarCard } from "@/components/corretores/CorretoresCalendarCard"
import { CorretoresBrokerListCard } from "@/components/corretores/CorretoresBrokerListCard"
import { useCorretoresPage } from "@/hooks/useCorretoresPage"

export function Corretores() {
  const {
    corretores,
    isLoading,
    isError,
    error,
    refetch,
    calendar,
    dayDialog,
    brokerList,
    dialogs,
    handleWhatsAppChange,
    saveAvailabilitiesDay,
  } = useCorretoresPage()

  if (isLoading) {
    return <LoadingState message="Carregando corretores e disponibilidades..." />
  }

  if (isError) {
    return <ErrorState error={error} title="Erro ao carregar corretores" onRetry={refetch} />
  }

  const {
    viewMode,
    setViewMode,
    currentMonth,
    selectedDayView,
    setSelectedDayView,
    selectedPeriod,
    currentQuinzena,
    handlePrevPeriod,
    handleNextPeriod,
    handleQuinzenaSelect,
    isDateInSelectedPeriod,
    isDateInCurrentQuinzena,
    calendarDays,
    getCorretoresForDate,
    handleDayClick,
    isCorretorAvailableAtTime,
  } = calendar

  return (
    <>
      <div className="space-y-6 pb-6 lg:space-y-4 lg:pb-0">
        <div className="flex w-full flex-col items-start justify-between gap-4 sm:flex-row sm:items-center">
          <div className="flex w-fit gap-1 rounded-lg bg-muted/50 p-1">
            <Button
              variant={viewMode === "month" ? "default" : "ghost"}
              size="sm"
              onClick={() => setViewMode("month")}
            >
              Mês
            </Button>
            <Button
              variant={viewMode === "day" ? "default" : "ghost"}
              size="sm"
              onClick={() => setViewMode("day")}
            >
              Dia
            </Button>
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => dialogs.setUploadSpreadsheetDialogOpen(true)}
            className="gap-2 border-0 bg-gradient-to-r from-primary to-secondary text-primary-foreground shadow hover:opacity-90"
          >
            <Upload className="h-4 w-4" />
            Upload de Planilha
          </Button>
        </div>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2 lg:items-start">
          <CorretoresCalendarCard
            viewMode={viewMode}
            setViewMode={setViewMode}
            currentMonth={currentMonth}
            selectedDayView={selectedDayView}
            setSelectedDayView={setSelectedDayView}
            selectedPeriod={selectedPeriod}
            currentQuinzena={currentQuinzena}
            handlePrevPeriod={handlePrevPeriod}
            handleNextPeriod={handleNextPeriod}
            handleQuinzenaSelect={handleQuinzenaSelect}
            isDateInSelectedPeriod={isDateInSelectedPeriod}
            isDateInCurrentQuinzena={isDateInCurrentQuinzena}
            calendarDays={calendarDays}
            corretores={corretores}
            getCorretoresForDate={getCorretoresForDate}
            handleDayClick={handleDayClick}
            isCorretorAvailableAtTime={isCorretorAvailableAtTime}
            onBrokerInfoClick={(id) => dialogs.setSelectedBrokerInfo(id)}
          />
          <CorretoresBrokerListCard
            viewMode={viewMode}
            selectedDayView={selectedDayView}
            corretoresQuinzena={brokerList.corretoresQuinzena}
            getCorretoresForDate={getCorretoresForDate}
            expandedBrokers={brokerList.expandedBrokers}
            toggleBrokerExpanded={brokerList.toggleBrokerExpanded}
            onVerTodos={() => dialogs.setAllBrokersDialogOpen(true)}
            onCadastrarNovo={() => dialogs.setNewBrokerDialogOpen(true)}
          />
        </div>
      </div>

      {/* Day Schedule Dialog */}
      <Dialog
        open={dayDialog.dialogOpen}
        onOpenChange={(open) => {
          dayDialog.setDialogOpen(open)
          if (!open) dayDialog.setEditingDayBroker(null)
        }}
      >
        <DialogContent
          withGradientHeader
          className="mx-auto flex max-h-[calc(100vh-48px)] w-[calc(100%-32px)] max-w-2xl flex-col overflow-hidden p-0 sm:max-h-[80vh]"
        >
          <div className="shrink-0 rounded-t-xl bg-gradient-to-r from-primary to-secondary px-4 pb-4 pt-6 sm:px-6">
            <DialogHeader>
              <DialogTitle className="text-sm text-primary-foreground sm:text-base">
                Agendas do Dia -{" "}
                {dayDialog.selectedDate &&
                  format(dayDialog.selectedDate, "dd/MM/yyyy - EEEE", { locale: ptBR })}
              </DialogTitle>
            </DialogHeader>
          </div>
          <div className="flex-1 space-y-4 overflow-y-auto px-4 py-4 sm:px-6">
            {(() => {
              const dateStr = dayDialog.selectedDate
                ? format(dayDialog.selectedDate, "yyyy-MM-dd")
                : ""
              const corretoresNoDia = dayDialog.selectedDate
                ? getCorretoresForDate(dayDialog.selectedDate)
                : []
              const noDiaIds = new Set(corretoresNoDia.map((c) => c.id))
              const corretoresSemDisp = corretores.filter((c) => !noDiaIds.has(c.id))

              return (
                <>
                  {corretoresNoDia.length === 0 ? (
                    <div className="py-8 text-center text-sm text-muted-foreground">
                      Nenhum corretor com disponibilidade neste dia
                    </div>
                  ) : (
                    corretoresNoDia.map((corretor) => {
                      const isEditingThisBroker = dayDialog.editingDayBroker === corretor.id
                      const disps = corretor.disponibilidades.filter(
                        (d) => d.available_date === dateStr,
                      )

                      return (
                        <div key={corretor.id} className="rounded-xl p-4 shadow">
                          <div className="mb-3 flex items-center justify-between">
                            <div className="flex items-center gap-2">
                              <div
                                className="h-3 w-3 rounded-full"
                                style={{ backgroundColor: corretor.calendar_color }}
                              />
                              <h3 className="font-semibold">
                                {corretor.first_name} {corretor.last_name}
                              </h3>
                            </div>
                            {!isEditingThisBroker && (
                              <div className="flex gap-1">
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onClick={() => {
                                    const periodos = disps.length
                                      ? disps.map((d) => ({
                                          horarioInicio: (d.start_time ?? "").slice(0, 5),
                                          horarioFim: (d.end_time ?? "").slice(0, 5),
                                        }))
                                      : [{ horarioInicio: "", horarioFim: "" }]
                                    dayDialog.setEditingSchedules({
                                      ...dayDialog.editingSchedules,
                                      [corretor.id]: { periodos, observacoes: "" },
                                    })
                                    dayDialog.setEditingDayBroker(corretor.id)
                                  }}
                                  className="h-8 gap-2 text-primary hover:bg-primary/10"
                                >
                                  <Edit2 className="h-3 w-3" />
                                  Editar
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onClick={() =>
                                    dialogs.setDisponibilidadeToDelete({
                                      broker_id: corretor.id,
                                      date: dateStr,
                                    })
                                  }
                                  className="h-8 gap-2 text-destructive hover:bg-destructive/10"
                                >
                                  <Trash2 className="h-3 w-3" />
                                  Excluir
                                </Button>
                              </div>
                            )}
                            {isEditingThisBroker && (
                              <div className="flex gap-2">
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onClick={() => {
                                    if (dayDialog.selectedDate) {
                                      const periodos = (
                                        dayDialog.editingSchedules[corretor.id]?.periodos ?? []
                                      ).map((p) => ({
                                        start_time: p.horarioInicio || null,
                                        end_time: p.horarioFim || null,
                                      }))
                                      saveAvailabilitiesDay({
                                        broker_id: corretor.id,
                                        available_date: dateStr,
                                        periodos,
                                      })
                                    }
                                    dayDialog.setEditingDayBroker(null)
                                  }}
                                  className="h-8 gap-2 text-green-600 hover:bg-green-600/10"
                                >
                                  <Save className="h-3 w-3" />
                                  Salvar
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onClick={() => dayDialog.setEditingDayBroker(null)}
                                  className="h-8 gap-2 text-destructive hover:bg-destructive/10"
                                >
                                  <X className="h-3 w-3" />
                                  Cancelar
                                </Button>
                              </div>
                            )}
                          </div>

                          {!isEditingThisBroker ? (
                            <div className="space-y-2">
                              <div className="flex items-start gap-2">
                                <Clock className="mt-0.5 h-4 w-4 text-muted-foreground" />
                                <div>
                                  <p className="text-sm font-medium">Disponibilidade</p>
                                  {disps.length === 0 ? (
                                    <p className="text-sm text-muted-foreground">Indisponível</p>
                                  ) : (
                                    <ul className="space-y-0.5 text-sm text-muted-foreground">
                                      {disps.map((d) => (
                                        <li key={d.id}>
                                          {d.is_available
                                            ? d.start_time && d.end_time
                                              ? `${d.start_time.slice(0, 5)} - ${d.end_time.slice(0, 5)}`
                                              : "Disponível (sem horário definido)"
                                            : "Indisponível"}
                                        </li>
                                      ))}
                                    </ul>
                                  )}
                                </div>
                              </div>
                            </div>
                          ) : (
                            <DayBrokerEditForm
                              editingSchedules={dayDialog.editingSchedules}
                              setEditingSchedules={dayDialog.setEditingSchedules}
                              corretorId={corretor.id}
                            />
                          )}
                        </div>
                      )
                    })
                  )}

                  {corretoresSemDisp.length > 0 && (
                    <div className="border-t border-border/40 pt-4">
                      <Popover>
                        <PopoverTrigger asChild>
                          <Button variant="outline" className="w-full gap-2">
                            <UserPlus className="h-4 w-4" />
                            Adicionar Disponibilidade
                          </Button>
                        </PopoverTrigger>
                        <PopoverContent className="w-64 p-2">
                          <div className="space-y-1">
                            <p className="mb-2 text-sm font-medium">Selecione o corretor:</p>
                            {corretoresSemDisp.map((corretor) => (
                              <Button
                                key={corretor.id}
                                variant="ghost"
                                size="sm"
                                className="w-full justify-start gap-2"
                                onClick={() => {
                                  dayDialog.setEditingSchedules({
                                    ...dayDialog.editingSchedules,
                                    [corretor.id]: {
                                      periodos: [{ horarioInicio: "", horarioFim: "" }],
                                      observacoes: "",
                                    },
                                  })
                                  dayDialog.setEditingDayBroker(corretor.id)
                                }}
                              >
                                <div
                                  className="h-2 w-2 rounded-full"
                                  style={{ backgroundColor: corretor.calendar_color }}
                                />
                                {corretor.first_name} {corretor.last_name}
                              </Button>
                            ))}
                          </div>
                        </PopoverContent>
                      </Popover>
                    </div>
                  )}

                  {dayDialog.editingDayBroker &&
                    !corretoresNoDia.some((c) => c.id === dayDialog.editingDayBroker) &&
                    (() => {
                      const corretor = corretores.find(
                        (c) => c.id === dayDialog.editingDayBroker,
                      )
                      if (!corretor) return null
                      return (
                        <div className="rounded-xl border border-primary/50 bg-primary/5 p-4 shadow">
                          <div className="mb-3 flex items-center justify-between">
                            <div className="flex items-center gap-2">
                              <div
                                className="h-3 w-3 rounded-full"
                                style={{ backgroundColor: corretor.calendar_color }}
                              />
                              <h3 className="font-semibold">
                                {corretor.first_name} {corretor.last_name}
                              </h3>
                              <Badge variant="outline" className="text-xs">
                                Novo
                              </Badge>
                            </div>
                            <div className="flex gap-2">
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => {
                                  if (dayDialog.selectedDate) {
                                    const periodos = (
                                      dayDialog.editingSchedules[corretor.id]?.periodos ?? []
                                    ).map((p) => ({
                                      start_time: p.horarioInicio || null,
                                      end_time: p.horarioFim || null,
                                    }))
                                    saveAvailabilitiesDay({
                                      broker_id: corretor.id,
                                      available_date: dateStr,
                                      periodos,
                                    })
                                  }
                                  dayDialog.setEditingDayBroker(null)
                                }}
                                className="h-8 gap-2 text-green-600 hover:bg-green-600/10"
                              >
                                <Save className="h-3 w-3" />
                                Salvar
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => dayDialog.setEditingDayBroker(null)}
                                className="h-8 gap-2 text-destructive hover:bg-destructive/10"
                              >
                                <X className="h-3 w-3" />
                                Cancelar
                              </Button>
                            </div>
                          </div>
                          <DayBrokerEditForm
                            editingSchedules={dayDialog.editingSchedules}
                            setEditingSchedules={dayDialog.setEditingSchedules}
                            corretorId={corretor.id}
                          />
                        </div>
                      )
                    })()}
                </>
              )
            })()}
          </div>
          <DialogFooter className="shrink-0 border-t border-border px-4 py-4 sm:px-6">
            <Button
              variant="outline"
              onClick={() => {
                dayDialog.setDialogOpen(false)
                dayDialog.setEditingDayBroker(null)
              }}
            >
              Fechar
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* All Brokers */}
      <Dialog open={dialogs.allBrokersDialogOpen} onOpenChange={dialogs.setAllBrokersDialogOpen}>
        <DialogContent
          withGradientHeader
          className="mx-auto flex max-h-[calc(100vh-48px)] w-[calc(100%-32px)] max-w-3xl flex-col overflow-hidden p-0 sm:max-h-[80vh]"
        >
          <div className="shrink-0 rounded-t-xl bg-gradient-to-r from-primary to-secondary px-4 pb-4 pt-6 sm:px-6">
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2 text-primary-foreground">
                <Users className="h-5 w-5" />
                Todos os Corretores
              </DialogTitle>
              <DialogDescription className="text-primary-foreground/80">
                Edite ou remova corretores da lista
              </DialogDescription>
            </DialogHeader>
          </div>
          <div className="mt-4 flex-1 space-y-3 overflow-y-auto px-4 sm:px-6">
            {corretores.map((corretor) => {
              const isEditing = dialogs.editingBrokerInList === corretor.id
              return (
                <div
                  key={corretor.id}
                  className="rounded-xl border p-4 shadow transition-all hover:shadow-md"
                  style={{
                    backgroundColor: `${corretor.calendar_color}20`,
                    borderColor: `${corretor.calendar_color}40`,
                  }}
                >
                  {isEditing ? (
                    <div className="space-y-3">
                      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                        <div>
                          <Label>Nome</Label>
                          <Input
                            value={dialogs.editBrokerForm.first_name}
                            onChange={(e) =>
                              dialogs.setEditBrokerForm({ ...dialogs.editBrokerForm, first_name: e.target.value })
                            }
                          />
                        </div>
                        <div>
                          <Label>Sobrenome</Label>
                          <Input
                            value={dialogs.editBrokerForm.last_name}
                            onChange={(e) =>
                              dialogs.setEditBrokerForm({
                                ...dialogs.editBrokerForm,
                                last_name: e.target.value,
                              })
                            }
                          />
                        </div>
                      </div>
                      <div>
                        <Label>Email</Label>
                        <Input
                          type="email"
                          value={dialogs.editBrokerForm.email}
                          onChange={(e) =>
                            dialogs.setEditBrokerForm({ ...dialogs.editBrokerForm, email: e.target.value })
                          }
                        />
                      </div>
                      <div>
                        <Label>WhatsApp</Label>
                        <Input
                          value={dialogs.editBrokerForm.whatsapp}
                          onChange={(e) => handleWhatsAppChange(e.target.value, false)}
                          placeholder="+55 XX XXXXX-XXXX"
                          maxLength={19}
                        />
                      </div>
                      <div>
                        <Label>Cor</Label>
                        <div className="flex items-center gap-2">
                          <Input
                            type="color"
                            value={dialogs.editBrokerForm.calendar_color}
                            onChange={(e) =>
                              dialogs.setEditBrokerForm({ ...dialogs.editBrokerForm, calendar_color: e.target.value })
                            }
                            className="h-10 w-20 cursor-pointer"
                          />
                          <span className="text-sm text-muted-foreground">
                            {dialogs.editBrokerForm.calendar_color}
                          </span>
                        </div>
                      </div>
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => dialogs.setEditingBrokerInList(null)}
                        >
                          Cancelar
                        </Button>
                        <Button
                          size="sm"
                          onClick={() => dialogs.saveEditedBroker(corretor.id)}
                          className="border-0 bg-gradient-to-r from-primary to-secondary text-primary-foreground shadow hover:opacity-90"
                        >
                          Salvar
                        </Button>
                      </div>
                    </div>
                  ) : (
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex min-w-0 items-center gap-3">
                        <div
                          className="h-3 w-3 shrink-0 rounded-full"
                          style={{ backgroundColor: corretor.calendar_color }}
                        />
                        <div className="min-w-0">
                          <h3 className="truncate font-semibold">
                            {corretor.first_name} {corretor.last_name}
                          </h3>
                          <p className="truncate text-sm text-muted-foreground">{corretor.email}</p>
                          <p className="text-sm text-muted-foreground">{corretor.whatsapp}</p>
                        </div>
                      </div>
                      <div className="flex shrink-0 gap-2">
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => dialogs.startEditingBrokerInList(corretor.id)}
                        >
                          <Edit2 className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => dialogs.setBrokerToDelete(corretor.id)}
                          className="text-destructive hover:bg-destructive/10"
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
          <DialogFooter className="shrink-0 border-t border-border px-4 py-4 sm:px-6">
            <Button variant="outline" onClick={() => dialogs.setAllBrokersDialogOpen(false)}>
              Fechar
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* New Broker */}
      <Dialog open={dialogs.newBrokerDialogOpen} onOpenChange={dialogs.setNewBrokerDialogOpen}>
        <DialogContent withGradientHeader className="mx-auto flex w-[calc(100%-32px)] max-w-lg flex-col p-0">
          <div className="shrink-0 rounded-t-xl bg-gradient-to-r from-primary to-secondary px-4 pb-4 pt-6 sm:px-6">
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2 text-primary-foreground">
                <UserPlus className="h-5 w-5" />
                Cadastrar Novo Corretor
              </DialogTitle>
            </DialogHeader>
          </div>
          <div className="flex-1 space-y-4 overflow-y-auto px-4 py-4 sm:px-6">
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="nome">Nome *</Label>
                <Input
                  id="nome"
                  value={dialogs.newBrokerForm.first_name}
                  onChange={(e) =>
                    dialogs.setNewBrokerForm({ ...dialogs.newBrokerForm, first_name: e.target.value })
                  }
                  placeholder="Ex: João"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="sobrenome">Sobrenome *</Label>
                <Input
                  id="sobrenome"
                  value={dialogs.newBrokerForm.last_name}
                  onChange={(e) =>
                    dialogs.setNewBrokerForm({ ...dialogs.newBrokerForm, last_name: e.target.value })
                  }
                  placeholder="Ex: Silva"
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="email">Email *</Label>
              <Input
                id="email"
                type="email"
                value={dialogs.newBrokerForm.email}
                onChange={(e) =>
                  dialogs.setNewBrokerForm({ ...dialogs.newBrokerForm, email: e.target.value })
                }
                placeholder="Ex: joao.silva@example.com"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="whatsapp">WhatsApp *</Label>
              <Input
                id="whatsapp"
                value={dialogs.newBrokerForm.whatsapp}
                onChange={(e) => handleWhatsAppChange(e.target.value, true)}
                placeholder="+55 XX XXXXX-XXXX"
                maxLength={19}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="cor">Cor *</Label>
              <div className="flex items-center gap-2">
                <Input
                  id="cor"
                  type="color"
                  value={dialogs.newBrokerForm.calendar_color}
                  onChange={(e) =>
                    dialogs.setNewBrokerForm({ ...dialogs.newBrokerForm, calendar_color: e.target.value })
                  }
                  className="h-10 w-20 cursor-pointer"
                />
                <span className="text-sm text-muted-foreground">{dialogs.newBrokerForm.calendar_color}</span>
              </div>
            </div>
          </div>
          <DialogFooter className="shrink-0 flex-col gap-2 border-t border-border px-4 py-4 sm:flex-row sm:px-6">
            <Button
              variant="outline"
              onClick={() => {
                dialogs.setNewBrokerDialogOpen(false)
                dialogs.setNewBrokerForm({
                  first_name: "",
                  last_name: "",
                  email: "",
                  whatsapp: "",
                  calendar_color: "#3b82f6",
                })
              }}
            >
              Cancelar
            </Button>
            <Button
              onClick={dialogs.handleAddBroker}
              className="border-0 bg-gradient-to-r from-primary to-secondary text-primary-foreground shadow hover:opacity-90"
            >
              Cadastrar
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Spreadsheet Upload */}
      <Dialog
        open={dialogs.uploadSpreadsheetDialogOpen}
        onOpenChange={(open) => {
          dialogs.setUploadSpreadsheetDialogOpen(open)
          if (!open) dialogs.resetUploadState()
        }}
      >
        <DialogContent
          withGradientHeader
          className="mx-auto flex max-h-[calc(100vh-48px)] w-[calc(100%-32px)] max-w-3xl flex-col overflow-hidden p-0 sm:max-h-[85vh]"
        >
          <div className="shrink-0 rounded-t-xl bg-gradient-to-r from-primary to-secondary px-4 pb-4 pt-6 sm:px-6">
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2 text-primary-foreground">
                <Upload className="h-5 w-5" />
                Upload de Planilha Quinzenal
              </DialogTitle>
              <DialogDescription className="text-primary-foreground/80">
                Faça o upload da planilha de horários dos corretores ou baixe o modelo
              </DialogDescription>
            </DialogHeader>
          </div>
          <div className="flex-1 space-y-6 overflow-y-auto px-4 py-4 sm:px-6">
            {!dialogs.previewData ? (
              <>
                <div className="space-y-3">
                  <h3 className="flex items-center gap-2 font-semibold">
                    <FileSpreadsheet className="h-4 w-4" />
                    Modelo de Planilha
                  </h3>
                  <p className="text-sm text-muted-foreground">
                    Baixe o modelo, preencha com os dados e faça o upload
                  </p>
                  <Button variant="outline" className="gap-2" onClick={dialogs.downloadExcelModel}>
                    <FileSpreadsheet className="h-4 w-4" />
                    Baixar Modelo Excel
                  </Button>
                </div>
                <Separator />
                <div className="space-y-3">
                  <h3 className="font-semibold">Upload da Planilha</h3>
                  <div className="space-y-4 rounded-lg border-2 border-dashed p-8 text-center">
                    {!dialogs.selectedFile ? (
                      <>
                        <Upload className="mx-auto h-12 w-12 text-muted-foreground" />
                        <div>
                          <p className="text-sm font-medium">Arraste e solte ou clique para selecionar</p>
                          <p className="mt-1 text-xs text-muted-foreground">
                            Formatos aceitos: .xlsx, .xls, .csv
                          </p>
                        </div>
                        <input
                          type="file"
                          accept=".xlsx,.xls,.csv"
                          onChange={dialogs.handleFileSelect}
                          className="hidden"
                          id="spreadsheet-upload"
                        />
                        <Button
                          variant="outline"
                          onClick={() => document.getElementById("spreadsheet-upload")?.click()}
                        >
                          Selecionar Arquivo
                        </Button>
                      </>
                    ) : (
                      <>
                        <FileCheck className="mx-auto h-12 w-12 text-green-600" />
                        <div>
                          <p className="text-sm font-medium">{dialogs.selectedFile.name}</p>
                          <p className="mt-1 text-xs text-muted-foreground">
                            {(dialogs.selectedFile.size / 1024).toFixed(2)} KB
                          </p>
                        </div>
                        <div className="flex justify-center gap-2">
                          <Button
                            variant="outline"
                            onClick={dialogs.resetUploadState}
                            disabled={dialogs.isProcessing}
                          >
                            Remover
                          </Button>
                          <Button
                            onClick={dialogs.analyzeSpreadsheet}
                            disabled={dialogs.isProcessing}
                            className="border-0 bg-gradient-to-r from-primary to-secondary text-primary-foreground shadow hover:opacity-90"
                          >
                            {dialogs.isProcessing ? "Analisando..." : "Analisar Planilha"}
                          </Button>
                        </div>
                      </>
                    )}
                  </div>
                </div>
                <div className="space-y-2 rounded-lg bg-muted/50 p-4">
                  <h4 className="flex items-center gap-2 text-sm font-semibold">
                    <Info className="h-4 w-4" />
                    Como preencher corretamente
                  </h4>
                  <ul className="ml-6 list-disc space-y-1.5 text-xs text-muted-foreground">
                    <li>
                      <strong>Data:</strong> Prefira <strong>AAAA-MM-DD</strong> ou texto no formato
                      brasileiro <strong>dia/mês/ano</strong>. Planilhas do Excel em inglês (mês/dia)
                      ambíguos como 4/9 e 9/4 são interpretadas automaticamente.
                    </li>
                    <li>
                      <strong>Email do corretor:</strong> Use o mesmo email que foi cadastrado no
                      sistema
                    </li>
                    <li>
                      <strong>Importante:</strong> Cadastre o corretor antes de fazer o upload
                    </li>
                    <li>
                      <strong>Horários:</strong> Preencha com HH:MM (ex.: 09:00). Se o Excel
                      deslocar o fim para a coluna E, o sistema ainda lê início e fim nas colunas C a
                      E.
                    </li>
                    <li>
                      <strong>Pausas:</strong> Duplique a linha e adicione o segundo período
                    </li>
                    <li>
                      <strong>Vários corretores:</strong> Crie uma linha para cada um
                    </li>
                  </ul>
                </div>
              </>
            ) : (
              <>
                <div className="space-y-4">
                  {dialogs.previewData.valid.length > 0 && (
                    <div className="space-y-2">
                      <h3 className="flex items-center gap-2 font-semibold text-green-600">
                        <FileCheck className="h-4 w-4" />
                        {dialogs.previewData.valid.length} registro(s) válido(s)
                      </h3>
                      <div className="max-h-48 overflow-hidden overflow-y-auto rounded-lg border">
                        <table className="w-full text-sm">
                          <thead className="sticky top-0 bg-muted/50">
                            <tr>
                              <th className="p-2 text-left font-medium">Corretor</th>
                              <th className="p-2 text-left font-medium">Data</th>
                              <th className="p-2 text-left font-medium">Início</th>
                              <th className="p-2 text-left font-medium">Fim</th>
                            </tr>
                          </thead>
                          <tbody>
                            {dialogs.previewData.valid.slice(0, 100).map((item, idx) => (
                              <tr key={idx} className="border-t">
                                <td className="p-2">{item.corretorNome}</td>
                                <td className="p-2">{item.displayDate}</td>
                                <td className="p-2">{item.startTime}</td>
                                <td className="p-2">{item.endTime}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                      <p className="text-xs text-muted-foreground">
                        {dialogs.previewData.valid.length > 100
                          ? `Mostrando 100 de ${dialogs.previewData.valid.length} linha(s). Todas serão importadas.`
                          : `Lista completa: ${dialogs.previewData.valid.length} linha(s). Role a tabela se necessário.`}
                      </p>
                    </div>
                  )}
                  {dialogs.previewData.errors.length > 0 && (
                    <div className="space-y-2">
                      <h3 className="flex items-center gap-2 font-semibold text-destructive">
                        <X className="h-4 w-4" />
                        {dialogs.previewData.errors.length} erro(s) encontrado(s)
                      </h3>
                      <div className="max-h-32 overflow-hidden overflow-y-auto rounded-lg border border-destructive/30 bg-destructive/5">
                        <table className="w-full text-sm">
                          <thead className="sticky top-0 bg-destructive/10">
                            <tr>
                              <th className="p-2 text-left font-medium">Linha</th>
                              <th className="p-2 text-left font-medium">Motivo</th>
                            </tr>
                          </thead>
                          <tbody>
                            {dialogs.previewData.errors.slice(0, 100).map((error, idx) => (
                              <tr key={idx} className="border-t border-destructive/20">
                                <td className="p-2">{error.linha}</td>
                                <td className="p-2 text-destructive">{error.motivo}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                      <p className="text-xs text-muted-foreground">
                        {dialogs.previewData.errors.length > 100
                          ? `Mostrando 100 de ${dialogs.previewData.errors.length} erro(s).`
                          : `Lista completa: ${dialogs.previewData.errors.length} erro(s).`}
                      </p>
                    </div>
                  )}
                  <div className="rounded-lg bg-muted/50 p-4">
                    <p className="text-sm">
                      <strong>
                        {Object.values(dialogs.previewData.groupedData).reduce(
                          (sum, g) => sum + g.periodos.length,
                          0,
                        )}
                      </strong>{" "}
                      disponibilidade(s) serão registradas
                      {dialogs.previewData.errors.length > 0 && (
                        <span className="text-muted-foreground">
                          {" "}
                          (linhas com erro serão ignoradas)
                        </span>
                      )}
                    </p>
                  </div>
                </div>
                <DialogFooter className="shrink-0 gap-2 border-t border-border px-6 py-4">
                  <Button
                    variant="outline"
                    onClick={dialogs.resetUploadState}
                    disabled={dialogs.isProcessing}
                  >
                    Voltar
                  </Button>
                  <Button
                    onClick={dialogs.confirmImport}
                    disabled={
                      dialogs.isProcessing ||
                      Object.keys(dialogs.previewData.groupedData).length === 0
                    }
                    className="border-0 bg-gradient-to-r from-primary to-secondary text-primary-foreground shadow hover:opacity-90"
                  >
                    {dialogs.isProcessing ? "Importando..." : "Confirmar Importação"}
                  </Button>
                </DialogFooter>
              </>
            )}
          </div>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={!!dialogs.brokerToDelete}
        onOpenChange={() => dialogs.setBrokerToDelete(null)}
        onConfirm={() =>
          dialogs.brokerToDelete && dialogs.handleDeleteBroker(dialogs.brokerToDelete)
        }
        title="Deletar Corretor"
        description="Tem certeza que deseja deletar este corretor? Todas as suas disponibilidades também serão removidas. Esta ação não pode ser desfeita."
        confirmLabel="Deletar"
        variant="destructive"
      />

      <ConfirmDialog
        open={!!dialogs.disponibilidadeToDelete}
        onOpenChange={() => dialogs.setDisponibilidadeToDelete(null)}
        onConfirm={dialogs.handleDeleteDisponibilidade}
        title="Remover Disponibilidade"
        description="Tem certeza que deseja remover todos os horários deste corretor neste dia? Esta ação não pode ser desfeita."
        confirmLabel="Remover"
        variant="destructive"
      />


      {/* Broker Info */}
      <Dialog
        open={!!dialogs.selectedBrokerInfo}
        onOpenChange={() => dialogs.setSelectedBrokerInfo(null)}
      >
        <DialogContent withGradientHeader className="mx-auto flex w-[calc(100%-32px)] max-w-md flex-col p-0">
          <div className="shrink-0 rounded-t-xl bg-gradient-to-r from-primary to-secondary px-4 pb-4 pt-6 sm:px-6">
            <DialogHeader>
              <DialogTitle className="text-primary-foreground">Informações do Corretor</DialogTitle>
            </DialogHeader>
          </div>
          {dialogs.selectedBrokerInfo &&
            (() => {
              const corretor = corretores.find((c) => c.id === dialogs.selectedBrokerInfo)
              if (!corretor) return null
              return (
                <div className="space-y-4 px-4 py-4 sm:px-6">
                  <div className="flex items-center gap-3">
                    <div
                      className="h-3 w-3 rounded-full"
                      style={{ backgroundColor: corretor.calendar_color }}
                    />
                    <h3 className="text-lg font-semibold">
                      {corretor.first_name} {corretor.last_name}
                    </h3>
                  </div>
                  <Separator />
                  <div className="space-y-2">
                    <div>
                      <Label className="text-muted-foreground">Email</Label>
                      <p className="break-all font-medium">{corretor.email}</p>
                    </div>
                    <div>
                      <Label className="text-muted-foreground">WhatsApp</Label>
                      <p className="font-medium">{corretor.whatsapp}</p>
                    </div>
                  </div>
                </div>
              )
            })()}
          <DialogFooter className="shrink-0 border-t border-border px-4 py-4 sm:px-6">
            <Button
              onClick={() => dialogs.setSelectedBrokerInfo(null)}
              className="border-0 bg-gradient-to-r from-primary to-secondary text-primary-foreground shadow hover:opacity-90"
            >
              Fechar
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}

/* ── Extracted sub-component for period editing ── */

function DayBrokerEditForm({
  editingSchedules,
  setEditingSchedules,
  corretorId,
}: {
  editingSchedules: Record<string, { periodos: { horarioInicio: string; horarioFim: string }[]; observacoes: string }>
  setEditingSchedules: (s: typeof editingSchedules) => void
  corretorId: string
}) {
  const schedule = editingSchedules[corretorId]
  if (!schedule) return null

  return (
    <div className="space-y-3">
      {schedule.periodos.map((periodo, index) => (
        <div key={index} className="space-y-2 rounded-md border bg-background/50 p-3">
          <div className="mb-2 flex items-center justify-between">
            <Label className="text-sm font-medium">Período {index + 1}</Label>
            {schedule.periodos.length > 1 && (
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={() => {
                  const newPeriodos = [...schedule.periodos]
                  newPeriodos.splice(index, 1)
                  setEditingSchedules({
                    ...editingSchedules,
                    [corretorId]: { ...schedule, periodos: newPeriodos },
                  })
                }}
                className="h-7 text-destructive hover:bg-destructive/10"
              >
                <X className="mr-1 h-3 w-3" />
                Remover
              </Button>
            )}
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label className="text-xs">Horário Início</Label>
              <Input
                type="time"
                value={periodo.horarioInicio}
                onChange={(e) => {
                  const newPeriodos = [...schedule.periodos]
                  newPeriodos[index] = { ...newPeriodos[index], horarioInicio: e.target.value }
                  setEditingSchedules({
                    ...editingSchedules,
                    [corretorId]: { ...schedule, periodos: newPeriodos },
                  })
                }}
              />
            </div>
            <div>
              <Label className="text-xs">Horário Fim</Label>
              <Input
                type="time"
                value={periodo.horarioFim}
                onChange={(e) => {
                  const newPeriodos = [...schedule.periodos]
                  newPeriodos[index] = { ...newPeriodos[index], horarioFim: e.target.value }
                  setEditingSchedules({
                    ...editingSchedules,
                    [corretorId]: { ...schedule, periodos: newPeriodos },
                  })
                }}
              />
            </div>
          </div>
        </div>
      ))}
      <Button
        type="button"
        variant="outline"
        size="sm"
        onClick={() => {
          const newPeriodos = [...schedule.periodos, { horarioInicio: "", horarioFim: "" }]
          setEditingSchedules({
            ...editingSchedules,
            [corretorId]: { ...schedule, periodos: newPeriodos },
          })
        }}
        className="w-full gap-2"
      >
        <CalendarDays className="h-4 w-4" />
        Adicionar Período
      </Button>
      <div>
        <Label className="text-sm">Observações</Label>
        <Textarea
          placeholder="Observações adicionais..."
          value={schedule.observacoes}
          onChange={(e) =>
            setEditingSchedules({
              ...editingSchedules,
              [corretorId]: { ...schedule, observacoes: e.target.value },
            })
          }
          className="min-h-[80px]"
        />
      </div>
    </div>
  )
}

export default Corretores
