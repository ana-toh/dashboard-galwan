# Objetivo

Permitir que a empresa acompanhe e audite todas as ações realizadas por usuários 
dentro do dashboard, registrando inserções, alterações e exclusões por funcionalidade.

- Acesso restrito a usuários com perfil **Admin**

# Estrutura do Registro (tabela `logs`)

Cada evento deve registrar os seguintes campos:

| Campo         | Tipo        | Descrição                                              |
|---------------|-------------|--------------------------------------------------------|
| `user_email`  | text        | E-mail do usuário que executou a ação                  |
| `action`      | enum        | Tipo da ação: `CREATE`, `UPDATE`, `DELETE`             |
| `feature`     | enum        | Funcionalidade: `prompts`, `projetos`, `corretores`, `chat`, `leads`, `metricas` |
| `description` | text        | Texto descritivo legível para exibição no frontend     |
| `created_at`  | timestamptz | Horário da ação (armazenado em UTC)                    |

> A exibição de `created_at` no frontend deve converter o horário para o fuso 
> horário do usuário autenticado que está visualizando o log.

# Formato dos Textos Descritivos (`description`)

### CREATE

O usuário [email] criou [entidade] [identificador] em [data e hora].

**Exemplos:**
- `O usuário ana@email.com criou um novo projeto "Villa Lobos" em 20/04/2025 às 14:32.`
- `O usuário ana@email.com adicionou o corretor joao@email.com em 20/04/2025 às 09:10.`
- `O usuário ana@email.com criou um novo colaborador maria@email.com com acesso a [Projetos, Leads] em 20/04/2025 às 11:00.`

### UPDATE

O usuário [email] alterou o campo [campo] em [entidade] [identificador] em [data e hora].

**Exemplos:**
- `O usuário ana@email.com alterou o campo "nome" no projeto "Villa Lobos" em 20/04/2025 às 15:45.`
- `O usuário ana@email.com atualizou o horário do corretor joao@email.com em 20/04/2025 às 10:20.`

### DELETE

O usuário [email] excluiu [entidade] [identificador] em [data e hora].

**Exemplos:**
- `O usuário ana@email.com excluiu o projeto "Villa Lobos" em 20/04/2025 às 16:00.`
- `O usuário ana@email.com excluiu o lead "Carlos Silva" em 20/04/2025 às 13:55.`

# Eventos por Funcionalidade

## Prompts
| Ação   | O que registrar                              |
|--------|----------------------------------------------|
| UPDATE | Quem alterou, quando                         |

## Projetos
| Ação   | O que registrar                                            |
|--------|------------------------------------------------------------|
| CREATE | Quem criou, quando                                         |
| UPDATE | Quem alterou, quando, nome do projeto e campo(s) alterado(s) |
| DELETE | Quem excluiu, quando, nome do projeto                      |

## Chat com Assistente
| Ação   | O que registrar         |
|--------|-------------------------|
| CREATE | Quem enviou mensagem, quando |

## Leads
| Ação   | O que registrar                                    |
|--------|----------------------------------------------------|
| UPDATE | Quem alterou, quando, campo alterado               |
| DELETE | Quem excluiu, quando, identificação do lead        |

## Métricas
| Ação   | O que registrar                                    |
|--------|----------------------------------------------------|
| CREATE | Quem baixou relatório, quando                      |
| UPDATE | Quem atualizou, quando, campo alterado             |
| DELETE | Quem excluiu o alerta, quando                      |

## Corretores
| Ação   | O que registrar                                              |
|--------|--------------------------------------------------------------|
| CREATE | Quem adicionou, quando, e-mail do corretor                   |
| CREATE | Quem fez upload da planilha de corretores/horários, quando   |
| UPDATE | Quem alterou, quando, campo alterado e corretor afetado      |
| DELETE | Quem excluiu, quando, e-mail do corretor                     |
