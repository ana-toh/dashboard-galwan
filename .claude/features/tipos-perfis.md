# Contexto

- A plataforma possui diferentes níveis de acesso baseado em:
  - tipo de usuário (role)
  - permissões por área (módulos do sistema)segurança e organização das ações realizadas pelos usuários 
  - se o usuário está ativo 
- Os perfis determinam quais funcionalidades cada usuário pode visualizar e executar  
- O objetivo é permitir que administradores controlem exatamente quais partes do sistema cada colaborador pode acessar

# Tipos de Perfis

## Administrador

- Acesso total à plataforma. Pode:
  - Visualizar e editar todos os dados  
  - Criar, editar e excluir informações  
  - Gerenciar usuários  
  - Visualizar logs de atividade  
  - Definir permissões de colaboradores
- Não possui restrições de permissão  
- Sempre considerado como **ativo**   

## Colaborador

- Acesso controlado pelo administrador  
- Só pode acessar áreas explicitamente permitidas  
- Deve estar com status **ativo** para acessar o sistema   

- Não pode:
  - Acessar logs  
  - Gerenciar outros usuários  
  - Acessar áreas administrativas  


# Modelo de Permissões

- O sistema deve funcionar com base em:
  - **Role (perfil)** + **Permissões específicas** + verificação de perfil ativo (is_active)

## Áreas do Sistema

As permissões são definidas por área (módulos da plataforma):

- Prompt  
- Corretores  
- Chat  
- Insights  
- Projetos  
- Leads  

### Permissões por Área

Cada área possui ações específicas permitidas:

### Prompt
- Visualizar  
- Inserir  
- Editar  

> Permite gerenciar informações do Prompt enviadas ao Agente SDR no WhatsApp  

### Corretores
- Visualizar  
- Inserir  
- Editar  
- Deletar  

> Inclui gerenciamento de corretores, horários e disponibilidades  

### Chat
- Visualizar  

> Acesso ao chat para coleta de feedbacks  

### Insights
- Visualizar  
- Inserir  
- Editar  
- Deletar  

### Projetos
- Visualizar  
- Inserir  
- Editar  
- Deletar  

### Leads
- Visualizar  
- Editar  
- Deletar  

# Regra de Aplicação

- O administrador define:
  - quais áreas o colaborador pode acessar  
  - e automaticamente herda as ações permitidas daquela área  

- O colaborador:
  - só pode executar ações dentro das áreas liberadas  

# Regras de Acesso

- Todas as rotas e ações devem validar:
  - usuário autenticado  
  - perfil do usuário  
  - permissões atribuídas  

- Caso o usuário tente acessar algo não permitido:
  - acesso deve ser bloqueado, retornando à página de onde o usuário saiu  
  - sistema retorna erro de autorização com popup

# Backend

- Todas as requisições devem validar:
  - usuário autenticado  
  - role (admin ou colaborador)  
  - status do usuário (ativo)  
  - permissão para a área e ação solicitada  

# Regras

- Admin:
  - acesso irrestrito  

- Colaborador:
  - deve estar ativo  
  - deve possuir permissão para a área  

# Resposta

- Autorizado:
  - requisição processada normalmente  

- Não autorizado:
  - retornar **403 (forbidden)**  
  - não retornar dados sensíveis ou id do usuário  

# Frontend

- Ocultar áreas e ações não permitidas  
- Tratar erro 403 com:
  - mensagem de acesso negado  
  - redirecionamento para página válida (ou dashboard)  

# Segurança

- O backend é a única fonte de autenticação e autorização  
- A identidade do usuário deve ser obtida exclusivamente a partir da sessão (token)
- Nenhum identificador sensível (ex: ID interno) deve ser exposto ou aceito via cliente  
- Todas as permissões devem ser validadas no backend a cada requisição  
- Requisições não autorizadas devem retornar **403 (forbidden)**, sem exposição de dados  
- Aplicar rate limiting para:
  - tentativas de login  
  - requisições sensíveis (ex: reset de senha)
- Registrar tentativas de acesso não autorizado  
- Sessões devem expirar conforme política definida  
- Tokens devem ser armazenados de forma segura (ex: cookies httpOnly, quando aplicável)  

# Estrutura de Dados

## Tabela Users

- id (uuid, PK, referência a auth.users.id)
- email (string, único, opcional - preferir ref usar auth.users)
- role (enum: 'admin' | 'colaborador')
- is_active (boolean, default: true)
- permitted_areas (text[])
- updated_at (timestamp with time zone, default: now())
- created_at (timestamp with time zone, default: now())

## Functions:

### can_access_area

create function can_access_area(area text)
returns boolean
language sql
security definer
as $$
  select 
    case 
      when role = 'admin' then true
      when is_active = false then false
      else area = any(permitted_areas)
    end
  from users
  where id = auth.uid();
$$;

## RLS (Row Level Security)

create policy "Acesso [table]"
on [table]
for all
to authenticated
using (
  can_access_area('[table]')
)
with check (
  can_access_area('[table]')
);
