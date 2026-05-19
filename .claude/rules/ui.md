---
paths:
  - "apps/web/src/**/*.tsx"
  - "apps/web/src/**/*.css"
---

# Regras de UI — Galwan Dash

Padrao visual profissional, limpo, com hierarquia clara via cor, gradiente e espacamento.

## Stack de Componentes

- **Primitivos**: `@radix-ui/react-*` (Radix UI) — base de todos os componentes interativos.
- **Estilo**: `class-variance-authority` (CVA) para variantes, `clsx` + `tailwind-merge` via `cn()`.
- **NUNCA** use `@base-ui/react`. O projeto padroniza em `@radix-ui/react-*`.
- **NUNCA** adicione componentes UI manualmente. Use `pnpm dlx shadcn@latest add <componente>` e depois ajuste ao padrao Radix se necessario.

### Componentes disponiveis em `components/ui/`

| Componente | Primitivo | Arquivo |
|---|---|---|
| AlertDialog | `@radix-ui/react-alert-dialog` | `alert-dialog.tsx` |
| Badge | CVA standalone | `badge.tsx` |
| Button | `@radix-ui/react-slot` | `button.tsx` |
| Calendar | `react-day-picker` v9 | `calendar.tsx` |
| Card | HTML nativo | `card.tsx` |
| Checkbox | `@radix-ui/react-checkbox` | `checkbox.tsx` |
| Dialog | `@radix-ui/react-dialog` | `dialog.tsx` |
| DropdownMenu | `@radix-ui/react-dropdown-menu` | `dropdown-menu.tsx` |
| Input | HTML nativo | `input.tsx` |
| Label | `@radix-ui/react-label` | `label.tsx` |
| Pagination | HTML nativo + CVA | `pagination.tsx` |
| Popover | `@radix-ui/react-popover` | `popover.tsx` |
| Select | `@radix-ui/react-select` | `select.tsx` |
| Separator | `@radix-ui/react-separator` | `separator.tsx` |
| Sonner (Toaster) | `sonner` | `sonner.tsx` |
| Switch | `@radix-ui/react-switch` | `switch.tsx` |
| Tooltip | `@radix-ui/react-tooltip` | `tooltip.tsx` |

## Principios Visuais

- Visual **limpo e moderno**. Sem efeitos decorativos desnecessarios.
- **NUNCA** use `drop-shadow`, `blur-*`, `glow` ou `backdrop-blur` em componentes.
- **NUNCA** use `bg-*/95` (opacidade de fundo). Fundos devem ser solidos.
- Hierarquia visual se faz com **espacamento**, **tipografia**, **cor** e **gradientes pontuais**.
- `shadow` sutil e permitido em cards e sidebar para dar profundidade.

## Gradientes

- Gradientes sao usados **apenas** em:
  - **Header do layout**: `bg-gradient-to-r from-primary to-secondary`
  - **Item ativo da sidebar**: `bg-gradient-to-r from-primary to-secondary`
  - **Headers de SectionCards**: `bg-gradient-to-r from-primary to-secondary`
- **NUNCA** use gradientes em backgrounds de pagina, modais ou inputs.
- **NUNCA** use gradientes de texto (`bg-clip-text`, `text-transparent`).

## Sidebar

- Fundo: `bg-white` (solido, claro).
- `shadow` para separar da area de conteudo.
- Item ativo: `bg-gradient-to-r from-primary to-secondary text-primary-foreground font-medium rounded-xl`.
- Item inativo: `text-foreground/70 hover:bg-muted`.
- Mobile: sidebar fixa com `translate-x` transition, overlay `bg-black/50` no fundo.
- Botao de fechar (X) visivel apenas no mobile.

## Header (Topbar)

- Fundo: `bg-gradient-to-r from-primary to-secondary`.
- Titulo: `text-primary-foreground font-bold`.
- Subtitulo: `text-primary-foreground/80`.
- Hamburger mobile: `lg:hidden`, icone `Menu`.

## Cores e Tokens

- **SEMPRE** use tokens do tema definidos em `apps/web/src/index.css`.
- **SEMPRE** use classes semanticas do Tailwind: `bg-background`, `text-foreground`, `border-border`, `text-primary`, `bg-muted`, etc.
- **NUNCA** use hex, rgb ou hsl hardcoded em componentes.
- Opacidades utilitarias (`/5`, `/10`, `/20`, `/50`, `/80`) sao permitidas apenas sobre tokens (ex.: `text-primary/80`, `bg-muted/50`).

### Tokens principais

| Token | Uso |
|-------|-----|
| `background` / `foreground` | Fundo e texto geral |
| `primary` / `primary-foreground` | Botoes principais, links, acentos, gradientes |
| `secondary` / `accent` | Elementos secundarios, segundo tom do gradiente |
| `muted` / `muted-foreground` | Fundos sutis, textos auxiliares |
| `border` / `input` | Bordas e campos de entrada |
| `ring` | Focus ring em inputs e botoes |
| `destructive` | Acoes perigosas (deletar, erro) |

## Tipografia

- Fonte do projeto: `Geist Variable` (sans-serif), definida no tema.
- Titulos de pagina: `font-bold text-xl lg:text-2xl`.
- Titulos de card/secao: `font-semibold text-lg`.
- Corpo de texto: `text-sm` como padrao. `text-base` para textos principais de leitura.
- Labels de formulario: `text-sm font-medium`.
- Textos auxiliares e descricoes: `text-sm text-muted-foreground`.

## Espacamento

- **SEMPRE** use o sistema de espacamento do Tailwind (multiplos de 4: `p-4`, `gap-6`, `space-y-4`).
- **NUNCA** use valores arbitrarios (`p-[13px]`) a menos que estritamente necessario.
- Paddings internos de cards e secoes: `p-4` (mobile) a `p-6` (desktop) via `p-4 lg:p-6`.
- Gaps entre campos de formulario: `space-y-4`.

## Bordas e Separadores

- Cards de dashboard: `border-0 rounded-xl shadow`. Sem borda explicita, shadow sutil.
- Cards de formulario/auth: `border border-border rounded-xl`. Sem shadow.
- Arredondamento padrao: `rounded-xl` para cards, `rounded-md` para inputs e botoes.
- Separadores visuais: usar `border-t border-border` ou `<Separator />` de `@radix-ui/react-separator`.

## Botoes

- Variantes: `default`, `destructive`, `outline`, `secondary`, `ghost`, `link`.
- Tamanhos: `default` (h-10), `sm` (h-9), `lg` (h-11), `icon` (h-10 w-10).
- Botao primario: variante `default` (fundo `primary`, texto `primary-foreground`).
- Botao secundario: variante `outline` ou `secondary`.
- Botao perigoso: variante `destructive`.
- Botao de logout: `variant="ghost"` com `text-destructive hover:bg-destructive/10`.
- Altura padrao para botoes de acao principal em formularios: `size="lg"` (h-11).
- **SEMPRE** incluir estado `disabled` com `isPending` em acoes que fazem requisicao.
- Suporta `asChild` via `@radix-ui/react-slot` para composicao com links.

## Inputs e Formularios

- Altura padrao de inputs: `h-10` (via componente). Usar `className="h-11"` para formularios de auth.
- Borda: `border-input`.
- Fundo: `bg-background` (solido, sem opacidade).
- Focus: `focus-visible:ring-ring` (via token `ring`).
- Placeholder: `text-muted-foreground` (automatico via shadcn).
- Labels acima do campo, com `space-y-2` entre label e input.

## Cards de Dashboard

- Padrao: `rounded-xl border-0 shadow p-0`.
- Header com gradiente: `bg-gradient-to-r from-primary to-secondary px-4 lg:px-6 py-4`.
- Texto do header: `text-primary-foreground`, subtitulo `text-primary-foreground/80`.
- Conteudo: `CardContent` com `p-4 lg:p-6`.

## KPI Cards

- Padrao: `rounded-xl border-0 shadow p-4`.
- Icone em circle: `size-8 rounded-full` com fundo `bg-{token}/10`.
- Valor: `text-3xl font-bold`.
- Label: `text-sm text-muted-foreground`.

## Badges

- Variantes: `default`, `secondary`, `destructive`, `outline`.
- Formato: `rounded-full` com `px-2.5 py-0.5 text-xs font-semibold`.
- Usar para status, contadores, tags.

## Dialogs e AlertDialogs

- Container: `border-0 rounded-xl shadow` (sem borda, com shadow).
- Overlay: `bg-black/80`.
- `DialogContent` suporta prop `withGradientHeader` para headers com gradiente (botao X fica branco).
- Header: `DialogHeader` > `DialogTitle` + `DialogDescription`.
- Footer: `DialogFooter` com botoes alinhados a direita.

## Select

- Trigger: `h-10 rounded-md border-input`.
- Content: `rounded-md border shadow-md` com animacoes de entrada/saida.
- Items: `rounded-sm` com focus em `bg-accent`.

## Popover

- Content: `rounded-md border shadow-md w-72`.
- Animacoes de fade/zoom/slide automaticas.

## Calendar

- Baseado em `react-day-picker` v9.
- Estilizado via `classNames` para manter consistencia com o tema.
- Selected: `bg-primary text-primary-foreground`.
- Today: `bg-accent text-accent-foreground`.

## Links

- Cor: `text-primary`.
- Hover: `hover:text-primary/80`.
- Transicao: `transition-colors`.
- **NUNCA** use `underline` por padrao. Usar `hover:underline` se necessario.

## Loading e Estados Vazios

- Loading: usar `Skeleton` do shadcn ou spinner simples com `animate-spin`.
- Estado vazio: texto centralizado com `text-muted-foreground`, sem ilustracoes decorativas pesadas.
- Erro: texto em `text-destructive` com `bg-destructive/10 rounded-md p-3`.

## Toasts (Sonner)

- Usar `toast.success()`, `toast.error()`, `toast.info()`, `toast.warning()` de `sonner`.
- Estilos aplicados via `toastOptions.classNames` no `Toaster`.
- Icones customizados do `lucide-react`.

## Responsividade

- Mobile-first: escrever classes base para mobile, usar `sm:`, `md:`, `lg:` para telas maiores.
- Sidebar: `fixed` no mobile com overlay, `static` em `lg:`.
- Largura maxima de conteudo principal: `max-w-md` para auth, sem limite para dashboard.
- Padding de paginas: `p-4` (mobile), `p-8` (desktop) via `p-4 lg:p-8`.

## Componentes shadcn

- **NUNCA** altere diretamente os arquivos em `components/ui/` sem justificativa. Use composicao e override via `className`.
- Componentes de dominio (ex.: `AuthCard`, `KpiCard`, `SectionCard`) ficam fora de `ui/`, em pastas por contexto.
- Regra do ESLint `react-refresh/only-export-components` esta desabilitada para `components/ui/` no `eslint.config.js`.

## Icones

- Usar exclusivamente `lucide-react`.
- Tamanho padrao: `size-4` em botoes, `size-5` em navegacao.
- Cor: herdar do contexto (`currentColor`) ou usar `text-muted-foreground`.

## Providers no App.tsx

- Ordem de wrapping: `ErrorBoundary > QueryClientProvider > TooltipProvider > Toaster + BrowserRouter`.
- `QueryClient` com `retry: 1` e `refetchOnWindowFocus: false`.
