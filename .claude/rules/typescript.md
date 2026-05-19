---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# Regras TypeScript

## Principios Basicos

- **SEMPRE** use TypeScript para escrever codigo. Nao use JavaScript em **hipotese alguma**.
- **NUNCA** use `any`. Prefira `unknown` e faca narrowing explicito.
- **NUNCA** use `@ts-ignore` ou `@ts-expect-error` sem justificativa clara em comentario.
- **SEMPRE** prefira named exports ao inves de default exports, a menos quando estritamente necessario (ex.: paginas com lazy loading).
- **SEMPRE** use `type` imports para tipos: `import type { Foo } from "..."`.

## Funcoes

- **SEMPRE** use arrow functions ao inves de funcoes convencionais, a menos quando estritamente necessario.
- **SEMPRE** nomeie funcoes como verbos (ex.: `fetchLeads`, `createProject`, `validateInput`).
- **SEMPRE** prefira early returns ao inves de ifs muito aninhados.
- Priorize higher-order functions ao inves de loops (`map`, `filter`, `reduce`, etc.).
- Ao receber mais de 2 parametros, **SEMPRE** receba um objeto.

### Exemplo:

```ts
// Ruim
const getUser = (id: string, includeProjects: boolean, limit: number) => { ... }

// Bom
interface GetUserParams {
  id: string
  includeProjects: boolean
  limit: number
}

const getUser = ({ id, includeProjects, limit }: GetUserParams) => { ... }
```

## Nomenclatura

- **SEMPRE** prefira `interface` ao inves de `type`, a menos quando estritamente necessario (unions, mapped types, etc.).
- **SEMPRE** use `kebab-case` para nomear arquivos (ex.: `auth-client.ts`, `fetch-leads.ts`).
  - Excecao: componentes React usam `PascalCase.tsx` (ex.: `LoginForm.tsx`).
  - Excecao: use cases/services podem usar `camelCase.ts` com verbo (ex.: `fetchLeads.ts`).
- **SEMPRE** use `PascalCase` para classes, interfaces e tipos.
- **SEMPRE** use `camelCase` para variaveis, funcoes e metodos.
- **SEMPRE** use `UPPER_SNAKE_CASE` para constantes.

## Datas

- **SEMPRE** use a biblioteca `date-fns` para manipular e formatar datas.
- **NUNCA** use `new Date()` diretamente para parsing ou formatacao — use funcoes do `date-fns` (`format`, `parse`, `parseISO`, etc.).
- **NUNCA** manipule strings de data com regex manual.
- **NUNCA** use `dayjs` ou `moment` — o projeto padroniza em `date-fns` (dependencia nativa do `react-day-picker`).

## Zod

- **SEMPRE** use Zod v4. **NUNCA** use Zod v3.
- **SEMPRE** valide dados com os validadores mais especificos possiveis:
  - `z.url()` para URLs
  - `z.email()` para e-mails
  - `z.uuid()` para UUIDs
  - `z.iso.date()` para datas (`YYYY-MM-DD`)
  - `z.iso.datetime()` para timestamps ISO
  - `z.iso.time()` para horarios
  - `z.iso.duration()` para duracoes
- **NUNCA** use regex manual quando Zod ja tem validador nativo para o tipo.

### Exemplo:

```ts
import { z } from "zod"

// Ruim
const schema = z.object({
  email: z.string().regex(/^[^\s@]+@[^\s@]+\.[^\s@]+$/),
  website: z.string(),
  birthDate: z.string(),
})

// Bom
const schema = z.object({
  email: z.email(),
  website: z.url(),
  birthDate: z.iso.date(),
})
```
