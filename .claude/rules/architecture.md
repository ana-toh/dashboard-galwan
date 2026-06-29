# Arquitetura do Projeto — Galwan Dash

Sistema profissional organizado como monorepo simples com frontend React e backend/BaaS Supabase.

## 1) Estrutura Geral

- `apps/web/`: frontend principal (Vite + React + TypeScript).
- `src/`: camada Node/TypeScript na raiz para scripts, seeds e integracoes server-side com Supabase.
- `dist/`: output de build da camada Node da raiz.

## 2) Stack Oficial

### Frontend (`apps/web`)

- Build/runtime: Vite + React 19 + TypeScript.
- UI: Tailwind CSS + shadcn-ui (Base UI + tokens via CSS variables).
- Dados: React Query (fetch/cache/mutations).
- BaaS: Supabase (Auth, Postgres, Storage, Edge Functions).
- Relatorios: Recharts, jsPDF, xlsx.
- Utilitarios visuais: `lucide-react`, `class-variance-authority`, `clsx`, `tailwind-merge`.

### Root (`/`)

- Node.js ESM + TypeScript (`tsx` em desenvolvimento).
- `zod` para validacao de ambiente.
- `@supabase/supabase-js` para scripts/integracoes fora do frontend.

## 3) Arquitetura Frontend (apps/web/src)

```
apps/web/src/
  pages/            # Paginas de rota (Login, Dashboard, etc.)
  components/
    ui/             # Primitives do design system (shadcn)
    auth/           # Componentes de autenticacao
    shared/         # Componentes compartilhados entre features
  hooks/            # Hooks de dominio e dados (useLeads, useProjects, etc.)
  services/         # Use cases e logica de negocio do frontend
  integrations/
    supabase/       # Cliente, tipos e helpers do Supabase
  lib/              # Utilitarios puros (utils, formatters, constants)
  schemas/          # Schemas Zod para validacao de formularios e respostas
```

## 4) Seguranca — Regras Inviolaveis

### Supabase no frontend

- O `VITE_SUPABASE_ANON_KEY` e o `VITE_SUPABASE_URL` sao as unicas variaveis permitidas no frontend. A anon key e projetada pelo Supabase para uso publico — ela **NAO** e um segredo. A seguranca real esta no RLS.
- **NUNCA** coloque `SUPABASE_SERVICE_ROLE_KEY`, tokens internos ou API secrets no frontend. Estes vao apenas no backend (raiz `/src` ou Edge Functions).
- **SEMPRE** que criar ou alterar uma tabela, ative RLS e crie policies explicitas. Sem policy = sem acesso (comportamento padrao com RLS ativo).
- O frontend **NUNCA** decide acesso sozinho. Esconder botao/menu e UX, nao seguranca. A seguranca real e feita por RLS + policies no Supabase.

### Ambiente

- **Arquivo unico na raiz**: `.env` (nao versionado) + `.env.example` (versionado, sem valores reais). Frontend (Vite) e scripts Node da raiz (`src/`) leem o **mesmo** arquivo.
  - O Vite le da raiz via `envDir` em `apps/web/vite.config.ts` (`path.resolve(__dirname, '../..')`).
  - Padronize todas as variaveis com prefixo `VITE_` (ex.: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`). O Vite so injeta no bundle do cliente variaveis com esse prefixo.
  - Secrets server-side (se um dia necessarios) vao no mesmo `.env` **sem** o prefixo `VITE_` — assim ficam disponiveis ao `src/` e nunca vazam pro frontend.
- **NUNCA** commitar `.env` com valores reais.

## 5) Services (Use Cases no Frontend)

Toda logica de negocio e acesso a dados deve estar concentrada em **services**. Uma pagina ou componente **NUNCA** deve chamar o Supabase diretamente.

### Regras

- **SEMPRE** crie services em `apps/web/src/services/`.
- **SEMPRE** nomeie services com verbos que descrevam a acao (ex.: `fetchLeads`, `createProject`, `updateLeadStatus`).
- **SEMPRE** tipe a entrada com uma interface `Input` e a saida com uma interface `Output`, definidas no mesmo arquivo.
- **SEMPRE** mapeie o retorno do Supabase para o `Output` — **NUNCA** retorne o objeto bruto do banco diretamente.
- **NUNCA** trate erros dentro do service com try/catch. Quem trata erros e o hook ou a pagina que chama o service.
- Caso o service precise lancar excecao, **SEMPRE** lance um erro customizado de `apps/web/src/lib/errors.ts`.

### Exemplo:

```ts
// apps/web/src/services/fetchLeads.ts
import { supabase } from "@/integrations/supabase/client"
import { AppError } from "@/lib/errors"

interface Input {
  projectId: string
  status?: string
}

interface Output {
  id: string
  name: string
  email: string
  status: string
  createdAt: string
}

export async function fetchLeads(input: Input): Promise<Output[]> {
  let query = supabase
    .from("leads")
    .select("id, name, email, status, created_at")
    .eq("project_id", input.projectId)
    .order("created_at", { ascending: false })

  if (input.status) {
    query = query.eq("status", input.status)
  }

  const { data, error } = await query

  if (error) {
    throw new AppError("Falha ao buscar leads", { cause: error })
  }

  return (data ?? []).map((row) => ({
    id: row.id,
    name: row.name,
    email: row.email,
    status: row.status,
    createdAt: row.created_at,
  }))
}
```

## 6) Hooks de Dados (React Query)

**SEMPRE** centralize chamadas de dados em hooks customizados que usam React Query. Uma pagina **NUNCA** deve usar `useQuery`/`useMutation` diretamente — deve chamar o hook de dominio.

### Regras

- **SEMPRE** crie hooks de dados em `apps/web/src/hooks/`.
- **SEMPRE** use query keys padronizadas e tipadas: `["leads", { projectId, status }]`.
- **SEMPRE** configure `staleTime` e `gcTime` adequados ao tipo de dado.
- Mutations devem **SEMPRE** invalidar queries relacionadas no `onSuccess`.
- **NUNCA** faca fetch manual com `useEffect` + `useState` quando React Query resolve.

### Exemplo:

```ts
// apps/web/src/hooks/useLeads.ts
import { useQuery } from "@tanstack/react-query"
import { fetchLeads } from "@/services/fetchLeads"

interface UseLeadsParams {
  projectId: string
  status?: string
}

export function useLeads({ projectId, status }: UseLeadsParams) {
  return useQuery({
    queryKey: ["leads", { projectId, status }],
    queryFn: () => fetchLeads({ projectId, status }),
    staleTime: 1000 * 60 * 2,
    enabled: Boolean(projectId),
  })
}
```

### Exemplo de mutation:

```ts
// apps/web/src/hooks/useCreateLead.ts
import { useMutation, useQueryClient } from "@tanstack/react-query"
import { createLead } from "@/services/createLead"

export function useCreateLead(projectId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: createLead,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["leads", { projectId }] })
    },
  })
}
```

## 7) Schemas de Validacao

- **SEMPRE** crie schemas Zod em `apps/web/src/schemas/`.
- **SEMPRE** valide formularios no client antes de enviar dados (email, URL, tamanho, tipos de arquivo).
- **SEMPRE** use os schemas para tipar respostas de erro padronizadas.
- **NUNCA** confie apenas em validacao de frontend — RLS e constraints no banco sao obrigatorios.

### Exemplo:

```ts
// apps/web/src/schemas/lead.ts
import { z } from "zod"

export const createLeadSchema = z.object({
  name: z.string().min(2, "Nome deve ter pelo menos 2 caracteres"),
  email: z.string().email("E-mail invalido"),
  phone: z.string().optional(),
  projectId: z.string().uuid(),
})

export type CreateLeadInput = z.infer<typeof createLeadSchema>
```

```ts
// apps/web/src/schemas/error.ts
import { z } from "zod"

export const errorSchema = z.object({
  message: z.string(),
  code: z.string(),
})

export type AppErrorResponse = z.infer<typeof errorSchema>
```

## 8) Paginas e Componentes

### Paginas (`pages/`)

- **SEMPRE** orquestre layout e composicao. Paginas chamam hooks de dados e renderizam componentes.
- Uma pagina **NUNCA** deve conter logica de negocio, queries brutas ao Supabase ou manipulacao complexa de dados.
- **SEMPRE** trate erros vindos dos hooks na pagina (loading, error, empty state).

### Componentes

- `components/ui/`: primitives do design system (shadcn). **NUNCA** altere diretamente — use composicao.
- `components/auth/`: dominio de autenticacao (`AuthCard`, `LoginForm`, `PasswordField`).
- `components/shared/`: componentes compartilhados entre features.
- Componentes de dominio ficam em pastas por contexto (ex.: `components/leads/`, `components/dashboard/`).

## 9) Estilo e Tema

- **SEMPRE** use tokens definidos em `apps/web/src/index.css` via CSS variables.
- **SEMPRE** use classes semanticas do Tailwind (`bg-background`, `text-foreground`, `border-border`).
- **NUNCA** use hex/rgb hardcoded.
- Variacoes visuais devem usar opacidade utilitaria (`/5`, `/20`, `/50`, etc.) sobre tokens.

## 10) UX e Hardening de Interface

- **SEMPRE** previna duplo submit com estado `isPending` em botoes de acao.
- **SEMPRE** use `disabled` e indicador de loading em acoes criticas.
- **NUNCA** use `dangerouslySetInnerHTML`. Se absolutamente necessario, sanitize com biblioteca dedicada.
- **NUNCA** renderize HTML vindo de usuario sem sanitizacao.
- **SEMPRE** limite upload por tamanho, extensao e MIME type.

## 11) Tratamento de Erros

- **SEMPRE** separe erros de usuario (mensagem amigavel) de erros tecnicos (log para debug).
- **NUNCA** exponha mensagens de erro internas do Supabase/Postgres para o usuario final.
- **SEMPRE** tenha um `ErrorBoundary` global com fallback visual.
- Erros customizados ficam em `apps/web/src/lib/errors.ts`.

### Exemplo:

```ts
// apps/web/src/lib/errors.ts
export class AppError extends Error {
  public readonly code: string

  constructor(message: string, options?: { cause?: unknown; code?: string }) {
    super(message, { cause: options?.cause })
    this.name = "AppError"
    this.code = options?.code ?? "APP_ERROR"
  }
}
```

## 12) Qualidade e Fluxo de Trabalho

- Antes de concluir qualquer alteracao no frontend:
  - **SEMPRE** rodar `pnpm lint` em `apps/web`.
  - **SEMPRE** rodar `pnpm build` em `apps/web`.
- **SEMPRE** use Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`.
- **NUNCA** commitar sem solicitacao explicita do usuario.

## 13) Git

- **SEMPRE** use [Conventional Commits](https://www.conventionalcommits.org/). Exemplo: `feat: add login page`, `fix: lead form validation`, `docs: update architecture rules`.
- **NUNCA** faca commit sem permissao explicita do usuario.
- **NUNCA** commitar `.env` com valores reais.
