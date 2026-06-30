import { useState, useRef, useEffect, useMemo } from "react";
import type { KeyboardEvent } from "react";
import { MessageCircle, X, Send, Loader2, Sparkles, Trash2 } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ScrollArea } from "@/components/ui/scroll-area";
import { ConfirmDialog } from "@/components/shared/ConfirmDialog";
import { logger } from "@/lib/logger";
import { cn } from "@/lib/utils";
import { sendAssistantMessage } from "@/services/assistant";
import { formatLogDateTime, logEvent } from "@/services/logs";
import { useChatHistory } from "@/hooks/useChatHistory";
import { deleteChatHistory } from "@/services/chat-history";
import type { ChatRole } from "@/services/chat-history";

type Message = {
  role: ChatRole;
  content: string;
};

interface AssistantChatProps {
  userEmail?: string;
}

export function AssistantChat({ userEmail }: AssistantChatProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [pending, setPending] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [confirmClear, setConfirmClear] = useState(false);
  const [isClearing, setIsClearing] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  const { data: history = [], isLoading: isHistoryLoading, refetchHistory } =
    useChatHistory(userEmail);

  const messages = useMemo<Message[]>(
    () => [...history.map((m) => ({ role: m.role, content: m.content })), ...pending],
    [history, pending],
  );

  useEffect(() => {
    if (!isOpen || isHistoryLoading) return;
    const id = requestAnimationFrame(() => {
      bottomRef.current?.scrollIntoView({ behavior: "auto", block: "end" });
    });
    return () => cancelAnimationFrame(id);
  }, [isOpen, isHistoryLoading]);

  useEffect(() => {
    if (!isOpen || isHistoryLoading) return;
    const id = requestAnimationFrame(() => {
      bottomRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
    });
    return () => cancelAnimationFrame(id);
  }, [messages, isLoading, isOpen, isHistoryLoading]);

  const sendMessage = async () => {
    const trimmed = input.trim();
    if (!trimmed || isLoading) return;

    setPending((prev) => [...prev, { role: "user", content: trimmed }]);
    setInput("");
    setIsLoading(true);

    try {
      const { reply, email } = await sendAssistantMessage({
        message: trimmed,
        fallbackEmail: userEmail,
      });

      const when = formatLogDateTime();
      void logEvent({
        action: "CREATE",
        feature: "chat",
        description: `O usuário ${email || "—"} enviou uma mensagem ao assistente em ${when}.`,
      });

      setPending((prev) => [...prev, { role: "assistant", content: reply }]);

      void refetchHistory().then(() => setPending([]));
    } catch (error) {
      logger.error("[AssistantChat]", error);
      setPending((prev) => [
        ...prev,
        {
          role: "assistant",
          content: "Desculpe, não consegui processar sua mensagem. Tente novamente.",
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyPress = (e: KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const handleClearHistory = async () => {
    if (!userEmail) return;
    setIsClearing(true);
    try {
      await deleteChatHistory(userEmail);
      setPending([]);
      await refetchHistory();
      toast.success("Histórico apagado.");
    } catch (error) {
      logger.error("[AssistantChat] clear", error);
      toast.error("Não foi possível apagar o histórico.");
    } finally {
      setIsClearing(false);
      setConfirmClear(false);
    }
  };

  const showEmpty = !isHistoryLoading && messages.length === 0 && !isLoading;
  const canClear = Boolean(userEmail) && messages.length > 0 && !isLoading && !isClearing;

  return (
    <>
      <Button
        onClick={() => setIsOpen(!isOpen)}
        className={cn(
          "fixed bottom-4 right-4 z-50 h-12 w-12 rounded-full shadow-lg transition-all duration-300 sm:bottom-6 sm:right-6 sm:h-14 sm:w-14",
          "bg-gradient-to-br from-primary to-secondary hover:scale-110",
          isOpen && "rotate-90",
        )}
        size="icon"
      >
        {isOpen ? <X className="h-5 w-5 sm:h-6 sm:w-6" /> : <MessageCircle className="h-5 w-5 sm:h-6 sm:w-6" />}
      </Button>

      {isOpen && (
        <div className="fixed bottom-20 right-4 z-50 w-[calc(100%-32px)] max-w-md animate-in slide-in-from-bottom-4 fade-in duration-300 sm:bottom-24 sm:right-6 sm:w-[calc(100%-48px)]">
          <div className="overflow-hidden rounded-lg border border-border bg-card shadow-2xl">
            <div className="flex items-center justify-between gap-3 bg-gradient-to-r from-primary to-secondary p-4">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-full bg-primary-foreground/20">
                  <Sparkles className="h-5 w-5 text-primary-foreground" />
                </div>
                <div>
                  <h3 className="font-semibold text-primary-foreground">Assistente</h3>
                  <p className="text-xs text-primary-foreground/70">Converse com o agente</p>
                </div>
              </div>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => setConfirmClear(true)}
                disabled={!canClear}
                aria-label="Apagar histórico"
                title="Apagar histórico"
                className="h-8 w-8 text-primary-foreground hover:bg-primary-foreground/20 disabled:opacity-40"
              >
                {isClearing ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
              </Button>
            </div>

            <ScrollArea className="h-80">
              <div className="p-4">
                {isHistoryLoading ? (
                  <div className="flex justify-center py-8">
                    <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
                  </div>
                ) : showEmpty ? (
                  <div className="py-8 text-center text-muted-foreground">
                    <Sparkles className="mx-auto mb-3 h-8 w-8 opacity-50" />
                    <p className="text-sm">Olá! Sou seu assistente.</p>
                    <p className="mt-1 text-xs">Envie uma mensagem para começar a conversa.</p>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {messages.map((msg, i) => (
                      <div
                        key={i}
                        className={cn(
                          "flex min-w-0 px-2",
                          msg.role === "user" ? "justify-end" : "justify-start",
                        )}
                      >
                        <div
                          className={cn(
                            "min-w-0 max-w-[85%] rounded-2xl px-4 py-2 text-sm",
                            msg.role === "user"
                              ? "rounded-br-md bg-primary text-primary-foreground"
                              : "rounded-bl-md bg-muted",
                          )}
                        >
                          <p className="whitespace-pre-wrap break-words [overflow-wrap:anywhere]">
                            {msg.content || "..."}
                          </p>
                        </div>
                      </div>
                    ))}
                    {isLoading && (
                      <div className="flex justify-start">
                        <div
                          className="flex items-center gap-1 rounded-2xl rounded-bl-md bg-muted px-4 py-3"
                          role="status"
                          aria-label="Assistente está digitando"
                        >
                          <span
                            className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground/60"
                            style={{ animationDelay: "0ms" }}
                          />
                          <span
                            className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground/60"
                            style={{ animationDelay: "150ms" }}
                          />
                          <span
                            className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground/60"
                            style={{ animationDelay: "300ms" }}
                          />
                        </div>
                      </div>
                    )}
                    <div ref={bottomRef} />
                  </div>
                )}
              </div>
            </ScrollArea>

            <div className="border-t border-border p-4">
              <div className="flex gap-2">
                <Input
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={handleKeyPress}
                  placeholder="Digite sua mensagem..."
                  disabled={isLoading}
                  className="flex-1"
                />
                <Button onClick={sendMessage} disabled={isLoading || !input.trim()} size="icon">
                  {isLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={confirmClear}
        onOpenChange={(next) => {
          if (!isClearing) setConfirmClear(next);
        }}
        title="Apagar histórico do chat?"
        description="Todas as suas mensagens serão removidas permanentemente. Essa ação não pode ser desfeita."
        confirmLabel={isClearing ? "Apagando..." : "Apagar"}
        cancelLabel="Cancelar"
        variant="destructive"
        onConfirm={handleClearHistory}
      />
    </>
  );
}
