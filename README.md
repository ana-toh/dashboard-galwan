# Galwan Dash

Dashboard profissional organizado como monorepo simples: frontend React (Vite) +
backend/BaaS Supabase, com uma camada Node na raiz para scripts e integrações
server-side.

- **Idioma do código:** inglês · **Idioma da UI:** pt-BR
- **Stack:** Vite + React 19 + TypeScript · Tailwind + shadcn-ui (Radix) ·
  React Query · Supabase (Auth, Postgres, Storage, Edge Functions) · Zod v4

## Pré-requisitos

- **Node.js 24.x**
- **pnpm 10**

## Estrutura

```
galwan-dash/
  apps/web/           # Frontend principal (Vite + React)
    src/
      pages/          # Páginas de rota
      components/     # ui/ (shadcn), auth/, shared/, layout/, domínio/
      hooks/          # Hooks de dados (React Query) e domínio
      services/       # Use cases / acesso a dados (única camada que fala com Supabase)
      schemas/        # Schemas Zod (validação + tipos)
      integrations/   # Cliente Supabase
      lib/            # Utilitários puros (errors, logger, utils, permissions)
  src/                # Camada Node (scripts/integrações server-side)
  supabase/           # Migrations, edge functions e seed
  .claude/rules/      # Regras de arquitetura/código (fonte da verdade técnica)
  .claude/features/   # Regras de domínio/produto
```

## Configuração de ambiente

O projeto usa **um único `.env` na raiz**, compartilhado pelo frontend (Vite) e
pela camada Node de `src/`. O Vite lê da raiz via `envDir` (ver
`apps/web/vite.config.ts`).

```bash
cp .env.example .env
```

Preencha com os valores do painel do Supabase (Project Settings → API):

```
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

> A `anon key` é pública por design do Supabase — a segurança real é feita por
> **RLS + policies** no banco. **Nunca** coloque `SERVICE_ROLE_KEY` ou secrets no
> `.env` com prefixo `VITE_` (só vars `VITE_*` chegam ao bundle do cliente).
> Secrets server-side vão no mesmo arquivo **sem** o prefixo `VITE_`.

## Comandos

### Frontend (`apps/web`)

```bash
cd apps/web
pnpm dev        # Vite dev server
pnpm build      # Type-check (tsc -b) + build de produção
pnpm lint       # ESLint
pnpm test       # Vitest (run)
pnpm test:watch # Vitest (watch)
pnpm preview    # Preview do build local
```

Análise de bundle: `ANALYZE=true pnpm build` gera `dist/bundle-stats.html`.

### Raiz (scripts/integrações Node)

```bash
pnpm dev        # tsx watch src/index.ts
pnpm typecheck  # tsc --noEmit
```

## Qualidade

Antes de finalizar qualquer alteração no frontend, rode **`pnpm lint`** e
**`pnpm build`** em `apps/web`. O CI (`.github/workflows/ci.yml`) executa
lint + type-check + build + test em push/PR para `main`.

Convenção de commits: **[Conventional Commits](https://www.conventionalcommits.org/)**
(`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).

## Documentação interna

- **Arquitetura e regras de código:** `.claude/rules/` (`architecture.md`,
  `general.md`, `typescript.md`, `ui.md`).
- **Regras de domínio/produto:** `.claude/features/` (auth, leads, logs,
  projetos, prompt, tipos-perfis).
