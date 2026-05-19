# Regras Gerais — Galwan Dash

Orientacoes globais para qualquer agente ou assistente trabalhando neste repositorio.

## Projeto

- **Nome:** Galwan Dash
- **Tipo:** Dashboard profissional (monorepo simples)
- **Idioma do codigo:** ingles (variaveis, funcoes, componentes, commits)
- **Idioma da UI/mensagens:** portugues (pt-BR)
- **Idioma de comunicacao com o usuario:** portugues

## Precedencia de Documentacao

- **`.cursor/features/*`** e a fonte da verdade para regras de dominio e produto.
- Em caso de conflito entre `.cursor/rules/` e `.cursor/features/`, **features vence**.
- Quando uma rule for ajustada para acomodar features, deixar nota explicita com referencia ao arquivo de feature correspondente.
- Features relevantes ja mapeadas:
  - `.cursor/features/tipos-perfis.md` — modelo de autorizacao (roles, is_active, permitted_areas, RLS).

## Stack

| Camada | Tecnologias |
|--------|-------------|
| Frontend | Vite + React 19 + TypeScript |
| UI | Tailwind CSS + shadcn-ui (Base UI) |
| Dados (frontend) | React Query |
| BaaS | Supabase (Auth, Postgres, Storage, Edge Functions) |
| Validacao | Zod v4 |
| Relatorios | Recharts, jsPDF, xlsx |
| Runtime raiz | Node.js 24 ESM + TypeScript (`tsx`) |
| Package manager | pnpm 10 |

## Comandos

```bash
# Frontend (apps/web)
cd apps/web
pnpm dev              # Inicia Vite dev server
pnpm build            # Type-check + build de producao
pnpm lint             # ESLint
pnpm preview          # Preview do build local

# Root (scripts/integracoes)
pnpm dev              # Roda src/index.ts com tsx watch
```

## Estrutura de Diretorios

```
galwan-dash/
  apps/web/           # Frontend principal
    src/
      pages/          # Paginas de rota
      components/     # UI (ui/, auth/, shared/, dominio/)
      hooks/          # Hooks de dados e dominio
      services/       # Use cases / logica de acesso a dados
      schemas/        # Schemas Zod (validacao + tipos)
      integrations/   # Clientes externos (supabase/)
      lib/            # Utilitarios puros (errors, utils, constants)
  src/                # Scripts e integracoes server-side (Node)
    config/           # Validacao de env
    lib/              # Client Supabase server-side
  .cursor/rules/      # Regras do agente
```

## Regras de Codigo

> Regras detalhadas de TypeScript, nomenclatura, funcoes e Zod estao em `.cursor/rules/typescript.md` (aplicada automaticamente em `**/*.ts` e `**/*.tsx`).

### Imports

- **SEMPRE** use alias `@/` para imports dentro de `apps/web/src/`.
- **NUNCA** use caminhos relativos longos (`../../../`).
- Ordem de imports: bibliotecas externas > alias internos > imports relativos.

### React

- **SEMPRE** use componentes funcionais.
- **NUNCA** use class components.
- **SEMPRE** extraia logica reutilizavel para hooks customizados.
- **NUNCA** faca fetch de dados com `useEffect` + `useState` — use React Query.
- **SEMPRE** previna duplo submit com `isPending`/`disabled` em acoes criticas.

### Estilo

- **SEMPRE** use tokens do tema (`bg-background`, `text-primary`, etc.).
- **NUNCA** use hex/rgb hardcoded.
- **SEMPRE** use Tailwind utility classes — evite CSS inline ou arquivos `.css` avulsos (exceto `index.css` de tokens).

## Seguranca

- **NUNCA** exponha secrets no frontend (`SERVICE_ROLE_KEY`, tokens internos, API keys privadas).
- `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` sao as unicas variaveis permitidas no bundle. A anon key e publica por design do Supabase — a seguranca real e RLS + policies.
- **NUNCA** commitar `.env` com valores reais. Versione apenas `.env.example`.
- **NUNCA** logar `process.env`, tokens ou payloads sensiveis no console.
- **NUNCA** usar `dangerouslySetInnerHTML` sem sanitizacao.

## Qualidade

- **SEMPRE** rodar `pnpm lint` e `pnpm build` em `apps/web` antes de finalizar alteracoes.
- **SEMPRE** verificar que nao introduziu warnings criticos no build.
- **SEMPRE** validar responsividade basica (mobile/tablet/desktop) em alteracoes de UI.

## Git e Commits

- **SEMPRE** use [Conventional Commits](https://www.conventionalcommits.org/).
  - `feat:` nova funcionalidade
  - `fix:` correcao de bug
  - `docs:` documentacao
  - `refactor:` refatoracao sem mudanca de comportamento
  - `chore:` tarefas de manutencao
  - `style:` formatacao (sem mudanca de logica)
- **NUNCA** faca commit sem permissao explicita do usuario.
- **NUNCA** commitar `.env`, credenciais ou arquivos gerados (`dist/`, `node_modules/`).

## MCPs

- **SEMPRE** use Context7 para buscar documentacoes atualizadas de bibliotecas.
- **SEMPRE** use ClickUp para consultar e gerenciar tarefas do projeto.

## Comunicacao

- Responda em portugues (pt-BR).
- Seja direto e objetivo.
- Quando sugerir codigo, mostre exemplos concretos e prontos para copiar.
- Quando houver trade-off, apresente opcoes com pros/contras antes de decidir.
- Nao adicione emojis a menos que o usuario peca.
