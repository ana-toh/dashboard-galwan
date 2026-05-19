# Contexto

- Os usuários administradores precisam acessar a plataforma  
- A autenticação garante a integridade da plataforma e a segurança na inserção e alteração de dados  
- A funcionalidade aparece no início da jornada (login)  

# Objetivo

Permitir que o usuário:
- Acesse a plataforma (login)  
- Redefina sua senha  

Permitir que a empresa:
- Controle atividades dentro da plataforma (logs de ações dos usuários)
- Veja, Altere, insira e delete informações.

> Inserções de novos perfis serão realizadas manualmente por administradores.

# Fluxo

## Login

1. Usuário insere email e senha  
2. Sistema valida credenciais via Supabase Auth  
3. Se válido:
   - cria sessão autenticada  
   - redireciona para o dashboard  
4. Se inválido:
   - exibe erro: **"Email ou senha inválidos"**  

## Reset de senha

1. Usuário acessa página "Esqueci minha senha"  
2. Informa o email  
3. Se o email existir:
   - recebe link de redefinição por email (via Integração com Resend) 
4. Se não existir:
   - exibe erro: **"Email não encontrado"**  
5. Usuário pode redefinir senha **até 2 vezes por dia**  

## Sessão

- Autenticação gerenciada pelo **Supabase Auth**  
- Estratégia: JWT + refresh token (padrão do Supabase)  
- Duração da sessão: **2 horas**  
- O ID do usuário é derivado exclusivamente do token de autenticação (JWT)

## Comportamento:
- Sessão possui **refresh automático**  
- Enquanto o usuário estiver ativo, a sessão será renovada automaticamente  
- Se o usuário ficar inativo e o refresh expirar:
  - será necessário realizar login novamente  

## Estados

### Loading
- Botão desabilitado  
- Indicador visual de carregamento  

### Sucesso
- Redirecionamento automático para o dashboard  

### Erro
- Credenciais inválidas:
  - **"Email ou senha inválidos"**  
- Email não encontrado:
  - **"Email não encontrado"**  
- Sistema indisponível:
  - **"Sistema temporariamente indisponível"**  

# Regras de Negócio

- Email deve ser único  
- Senha deve ter no mínimo 8 caracteres  
- Login só é permitido se:
  - usuário existir  
  - senha estiver correta  

- Reset de senha limitado a:
  - **2 requisições por dia por usuário/email**  

- Limite de tentativas de login:
  - Ex: 5 tentativas por minuto (rate limit)

# Logs

Eventos registrados:

- Login realizado (sucesso)  
- Tentativa de login falha  
- Solicitação de reset de senha  
- Alteração de senha

Campos registrados:

- Email do usuário  
- Ação realizada  
- Data e hora  

# Logout

- Usuário pode realizar logout manualmente  
- Sessão é encerrada no cliente  
- Token é removido
- Usuário é redirecionado para a tela de login  

# Edge Cases

- Usuário clica múltiplas vezes no botão de login  
- API demora ou falha  
- Token expira durante uso  
- Usuário tenta acessar rota protegida sem autenticação  
- Email inválido (formato incorreto)  
- Muitas tentativas de login consecutivas  
- Solicitações excessivas de reset de senha  

# Segurança

- O ID real do usuário (ex: ID interno do banco) **não deve ser exposto em nenhuma chamada de API, frontend ou integração externa**
- Todas as referências ao usuário devem utilizar:
  - identificadores seguros (ex: UUID público)
  - ou IDs anonimizados
- Caso seja necessário trafegar identificadores:
  - devem estar **criptografados ou assinados**
- Nunca confiar em IDs vindos do cliente:
  - o backend deve sempre validar o usuário a partir do token de autenticação (JWT)
- O ID do usuário deve ser obtido exclusivamente a partir da sessão autenticada (token), e nunca por input manual

# Observações

- Permissões de perfis (Administrador / Colaborador) serão definidas em documento separado
- Supabase será responsável pela gestão de autenticação e sessão  