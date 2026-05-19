# Objetivo

- Permitir que administradores e colaboradores autorizados **visualizem, editem e removam** registros de contatos (leads) capturados pelo fluxo de atendimento, com **nome**, **WhatsApp**, **aceite de termos**, **status ativo** e **observações** opcionais.
- A rota no app é **`/leads`** (item **Leads** na sidebar). Os dados vêm da tabela Supabase **`public.leads`**.

# Modelo de dados (tabela `leads`)

| Campo | Uso no app |
|--------|------------|
| `id` | Identificador (UUID) |
| `name` | Nome do contato (exibido na lista e no modal; **somente leitura** na edição atual) |
| `whatsapp` | Telefone / WhatsApp (lista e detalhes; **somente leitura** na edição) |
| `agreed_terms` | Se aceitou termos (Sim / Não) — **editável** no modal |
| `is_active` | Se o lead está ativo — **editável** no modal |
| `request_notes` | Observações internas — **editável** no modal |
| `created_at` | Data/hora do contato (exibida como “Data do Contato”) |
| `updated_at` | Atualizado pelo backend ao alterar o registro |

# Regras de criação (service)

- Existe a função **`createLead`** no serviço: antes de inserir, o sistema **valida duplicidade de WhatsApp**; se já existir lead com o mesmo `whatsapp`, retorna erro **“Já existe um lead com este WhatsApp”**.
- A tela **Leads** hoje **não** expõe formulário de criação; a criação pode ser usada por outros fluxos (ex.: integração futura) via o mesmo serviço.

# Permissões (área `leads`)

Definidas em `lib/permissions` para a área **`leads`**:

- **Ações previstas no produto:** `view`, `edit`, `delete` (não há ação `create` na área, alinhado à tela atual).
- **Administradores:** acesso total às ações acima.
- **Colaboradores:** acessam somente se **`leads`** estiver em `permitted_areas` e a conta estiver **ativa** (`is_active = true` no perfil do app).
- **Rota protegida:** `AccessGuard` + `getAreaForRoute` — quem não tem a área é redirecionado e recebe *toast* de acesso negado.
- **Supabase (RLS):** o acesso a linhas em `leads` deve seguir a política do banco (ex.: `can_access_area('leads')` para usuários autenticados), em linha com as instruções de schema do projeto.

# Comportamento da interface (`Leads.tsx`)

- **KPI:** card “Leads atendidos” com **total de leads** (contagem de registros retornados).
- **Lista:** tabela com Nome, WhatsApp, Termos, Ativo e ação “Ver detalhes”.
- **Busca:** filtra por **nome** ou **WhatsApp** (texto, sem acento especial).
- **Paginação:** 10 itens por página, com controle de página.
- **Modal de detalhes:** mostra nome, WhatsApp, data do contato, termos, ativo e observações.
- **Edição (no modal):** altera apenas **aceite de termos** (switch), **ativo** (switch) e **observações** (textarea). Nome e WhatsApp **não** são editáveis na UI atual.
- **Exclusão:** botão de deletar abre **confirmação**; após confirmar, o lead é removido e a lista é atualizada.

# Uso em outras partes do app

- **Métricas (`/metricas`):** carrega os mesmos leads para **filtrar por intervalo de datas** (`created_at`) e exibir totais; o **relatório PDF** inclui métricas derivadas (total no período, ativos, aceitaram termos).
- **Layout do dashboard:** o assistente pode receber contagem de leads (ex.: `leadsCount`) para contexto; o **home** com KPIs fixos pode ainda mostrar valores estáticos — a fonte de verdade da listagem é a página **Leads** e o hook **`useLeads`**.

# Stack técnica (referência)

- Dados: **`@/services/leads`** (Supabase `from("leads")`).
- Estado: **`useLeads`** (React Query: `fetchLeads`, `createLead`, `updateLead`, `deleteLead`).
