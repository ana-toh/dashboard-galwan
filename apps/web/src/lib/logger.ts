const isDev = import.meta.env.DEV

/**
 * Sink externo opcional para erros em produção (ex.: Sentry, Logtail, endpoint
 * próprio). Permanece desacoplado de qualquer vendor: registre um reporter com
 * `setErrorReporter` no bootstrap da app e o logger passa a encaminhar.
 */
type ErrorReporter = (error: unknown, context?: Record<string, unknown>) => void

let errorReporter: ErrorReporter | null = null

export const setErrorReporter = (reporter: ErrorReporter | null): void => {
  errorReporter = reporter
}

export const logger = {
  /** Log verboso: apenas em desenvolvimento. */
  log: (...args: unknown[]) => {
    if (isDev) console.log(...args)
  },
  /** Avisos: emitidos em dev e produção. */
  warn: (...args: unknown[]) => {
    console.warn(...args)
  },
  /** Erros: emitidos em dev e produção. */
  error: (...args: unknown[]) => {
    console.error(...args)
  },
}

/**
 * Reporta um erro capturado: loga no console (dev e prod) e encaminha ao sink
 * externo, se registrado. Use em ErrorBoundary e em catch de fluxos críticos.
 */
export const reportError = (error: unknown, context?: Record<string, unknown>): void => {
  logger.error("[reportError]", error, context ?? "")
  if (errorReporter) {
    try {
      errorReporter(error, context)
    } catch (reporterError) {
      logger.error("[reportError] sink falhou", reporterError)
    }
  }
}
