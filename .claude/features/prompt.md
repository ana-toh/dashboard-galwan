# Objetivo

- Permitir que administradores e colaboradores autorizados realizem a gestão dos direcionamentos específicos enviados ao Agente SDR Rafa  

# Direcionamentos Específicos

Os campos editáveis dentro do prompt do Rafa são:

- Metodologia de Qualificação  
- Identidade  
- Emojis  

> Outras alterações devem ser realizadas diretamente no agente via N8N  

# Permissões

- Administradores:
  - acesso total (visualizar e editar)

- Colaboradores:
  - podem visualizar e editar **apenas se** possuírem a área "prompt" no campo permitted_areas

# Comportamento da Interface

- Antes de salvar qualquer alteração:
  - deve ser exibido um popup de confirmação informando que:
    - alterações nesses campos impactam diretamente o comportamento do agente  
    - a ação **não pode ser desfeita automaticamente**  

# Logs

Todas as ações realizadas nesta funcionalidade devem ser registradas na tabela de logs.

## Eventos registrados (interno - sistema)

- prompt_updated → alteração em qualquer campo do prompt  

## Campos obrigatórios

- user_email  
- action (evento interno, ex: prompt_updated)  
- entity (prompt)  
- field_changed (campo alterado)  
- timestamp (UTC + convertido para horário de Brasília)  
- status (success | error)  
- error_message (se houver)  

## Mapeamento dos campos (exibição)

- qualification_methodology → "Metodologia de Qualificação"  
- identity → "Identidade do agente"  
- emojis → "Emojis"  

## Regras de uso

- O sistema deve salvar o evento com o nome técnico (ex: `prompt_updated`)  
- O campo alterado deve ser salvo em `field_changed` (ex: `identity`)  
- A interface deve traduzir os nomes técnicos para português na exibição  

## Tradução para exibição (frontend)

- prompt_updated → alterou os dados do campo  

## Formato do log (exibição para usuário)

> "O usuário [email] alterou os dados do campo [campo], em [data] às [hora] (horário de Brasília)"

## Exemplo

> "O usuário email@email.com.br alterou os dados do campo Metodologia de Qualificação, hoje às 15:35 (horário de Brasília)"

# Segurança

- O acesso deve ser controlado via RLS (Row Level Security) no banco de dados  
- Apenas usuários autenticados (`authenticated`) podem acessar a funcionalidade  

- A validação de permissão deve ocorrer no backend, considerando:
  - usuário autenticado (`auth.uid()`)  
  - role (`admin` ou `colaborador`)  
  - status ativo (`is_active = true`)  
  - presença da área `"prompt"` em `permitted_areas`  
- Administradores possuem acesso irrestrito  
- Todas as validações devem ser centralizadas na função:
  - can_access_area('prompt') 

# Estrutura de Dados

## Tabela Prompt

- id (uuid, PK)
- identity (text)
- qualification_methodology (text)
- emojis (text)
- updated_at (timestamp with time zone, default: now())
- created_at (timestamp with time zone, default: now())

## RLS (Row Level Security)

create policy "Acess prompt"
on prompt
for all
to authenticated
using (
  can_access_area('prompt')
)
with check (
  can_access_area('prompt')
);