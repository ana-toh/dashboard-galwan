import { useEffect } from "react"
import { useRouteError, useNavigate } from "react-router-dom"
import { AlertTriangle } from "lucide-react"

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { reportError } from "@/lib/logger"

export function RouteErrorBoundary() {
  const error = useRouteError()
  const navigate = useNavigate()

  useEffect(() => {
    if (error) reportError(error, { boundary: "RouteErrorBoundary" })
  }, [error])

  const message =
    error instanceof Error ? error.message : "Ocorreu um erro inesperado."

  return (
    <div className="flex min-h-[60vh] items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <div className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5 text-destructive" />
            <CardTitle>Algo deu errado</CardTitle>
          </div>
          <CardDescription>
            Não foi possível carregar esta página. Tente novamente.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {import.meta.env.DEV && (
            <div className="rounded-md bg-destructive/10 p-3 text-sm">
              <p className="font-mono text-xs text-destructive">{message}</p>
            </div>
          )}
          <div className="flex gap-2">
            <Button onClick={() => navigate(0)} variant="outline">
              Tentar novamente
            </Button>
            <Button onClick={() => navigate("/home")}>
              Voltar ao início
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
