# Objetivo

Permitir que a empresa (administradores ou colaboradores autorizados) possa:

- Ver projetos  
- Criar projetos  
- Editar projetos  
- Deletar projetos  

Os dados são utilizados pelo Agente SDR Rafa, com busca semântica baseada em vetorização (pgvector no Supabase).

# Busca Semântica (SDR Rafa)

Usa embeddings do projeto
Armazenado no Supabase (pgvector)
Permite busca contextual por significado

# Permissões

## Administrador
- Acesso total (CRUD completo em todos os projetos)

## Colaboradores
- Acesso apenas se `"projects"` estiver em `permitted_areas`
- Podem:
  - visualizar
  - criar
  - editar
  - deletar

# Regras de Acesso (RLS)

- Todas as rotas devem validar:
  - usuário autenticado (Supabase Auth)
  - role (admin ou colaborador)
  - status ativo (`is_active = true`)
  - permissão de área via `can_access_area('projects')`

- Admin:
  - acesso irrestrito

- Colaborador:
  - deve estar ativo
  - deve ter permissão para "projects"

# Imagens dos Projetos

## Regras:
- Máximo: 10 imagens por projeto
- Upload automático para bucket:
  - imagens_projetos > pasta com nome = ao id do projeto a qual a foto pertence

## Estrutura:
- Pasta: project_id
- Nome do arquivo: 01
  - O nome do arquivo sempre deve ser um número em sequência ao último número inserido na pasta

## Comportamento:
- Upload → salva no bucket e na tabela
- Delete de imagem → aviso de que essa ação não pode ser desfeita → se não, cancela. Se sim → remove do bucket e da tabela

# Exclusão de Projeto

Ao deletar um projeto:

- Remove registro da tabela `projects`
- Remove embeddings (pgvector)
- Remove imagens do bucket
- Remove registros de `project_images`

## Aviso obrigatório:
- "Essa ação não pode ser desfeita", conitnuar apenas se usuário apertar sim. Caso aperte não, cancelar operação.

# Estrutura de Dados (Projects)

## Tabela Projects

- id (uuid, PK)
- name (text) 
- launch_date (date) 
- delivery_date (date, apenas mês e ano) 
- neighborhood (text) 
- description (text) 
- status (enum project_status) 
- city (text) 
- state (text)
- reference_points (text) 
- project_website (text) 
- embedding (vector)
- content (text)
- metadata (jsonb)
- project_images_urls ([] text)
- updated_at (timestamp with time zone, default: now())
- created_at (timestamp with time zone, default: now())

### Campos que serão vetorizados:

- name  
- launch_date  
- delivery_date  
- neighborhood  
- description  
- status  
- city  
- state  
- reference_points  
- project_website

*Todos serão inseridos em content, metadata e embedding  

## Tabela project_images

- id (uuid)
- project_id
- image_url
- file_name
- index (ordem de exibição)
- created_at

## Vetorização (Embeddings)

## Quando ocorre:
- Criação de projeto
- Atualização de projeto

## Regras:
- Sempre reprocessa TODOS os campos
- Substitui embedding anterior (overwrite)
- Nunca versiona embeddings

## Falhas:
- Retry automático até 3 tentativas
- Se falhar 3x:
  - marcar `embedding_failed = true`
  - registrar erro em logs
  - bloquear finalização do processo

## Erro de API de IA para vetorização:
- 429 (rate limit):
  - informar limite atingido
- Outros erros:
  - registrar e retry automático

## Edge Function (Supabase)

## Responsabilidade:
- Buscar dados do projeto
- Criar texto consolidado
- Gerar embedding via OpenAI
- Salvar embedding no Supabase (pgvector)
- Atualizar metadata

## Secrets necessárias:

- OPENAI_API_KEY
- SUPABASE_URL
- SUPABASE_ANON_KEY
- SUPABASE_SERVICE_ROLE_KEY
- ALLOWED_ORIGINS

## Function

import "https://deno.land/x/xhr@0.1.0/mod.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Get allowed origins from environment variable or default to wildcard for development
const allowedOrigins = Deno.env.get("ALLOWED_ORIGINS")?.split(",") || ["*"];

const getCorsHeaders = (requestOrigin: string | null) => {
  const originHeader = allowedOrigins.includes("*") || (requestOrigin && allowedOrigins.includes(requestOrigin))
    ? requestOrigin || "*"
    : allowedOrigins[0];

  return {
    "Access-Control-Allow-Origin": originHeader,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
};

serve(async (req) => {
  const requestOrigin = req.headers.get("origin");
  const corsHeaders = getCorsHeaders(requestOrigin);

  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Verify JWT token (Supabase does this automatically when verify_jwt = true)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Create Supabase client to verify user
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    // Verify user is authenticated
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    
    // Validate input
    if (!body.projectId || typeof body.projectId !== "string") {
      return new Response(
        JSON.stringify({ error: "Invalid request: projectId (string) is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { projectId } = body;
    
    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(projectId)) {
      return new Response(
        JSON.stringify({ error: "Invalid request: projectId must be a valid UUID" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Generating embedding for project: ${projectId}`);

    // Use service role key for database operations
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // Fetch project data
    const { data: project, error: fetchError } = await supabaseAdmin
      .from('projects')
      .select('name, neighborhood, city, state, description, reference_points, project_website, launch_date, delivery_date, status')
      .eq('id', projectId)
      .single();

    if (fetchError) {
      console.error('Error fetching project:', fetchError);
      throw fetchError;
    }

    if (!project) {
      throw new Error('Project not found');
    }

    // Build text to embed
    const textParts = [
      project.name && `Project: ${project.name}`,
      project.city && project.state
        ? `Location: ${project.city}, ${project.state}`
        : (project.city && `City: ${project.city}`) || (project.state && `State: ${project.state}`),
      project.neighborhood && `Neighborhood: ${project.neighborhood}`,
      project.description && `Description: ${project.description}`,
      project.reference_points && `Reference Points: ${project.reference_points}`,
      project.project_website && `Site: ${project.project_website}`,
      project.launch_date && `Launch Date: ${project.launch_date}`,
      project.delivery_date && `Estimte delivery: ${project.delivery_date}`,
    ].filter(Boolean);

    const textToEmbed = textParts.join('\n');

    if (!textToEmbed.trim()) {
      console.log('No text to embed, skipping');
      return new Response(JSON.stringify({ success: true, skipped: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log(`Text to embed: ${textToEmbed.substring(0, 100)}...`);

    // Generate embedding via OpenAI
    const openAIApiKey = Deno.env.get('OPENAI_API_KEY');
    if (!openAIApiKey) {
      throw new Error('OPENAI_API_KEY not configured');
    }

    const embeddingResponse = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openAIApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'text-embedding-3-small',
        input: textToEmbed,
      }),
    });

    if (!embeddingResponse.ok) {
      const errorText = await embeddingResponse.text();
      console.error('OpenAI API error:', errorText);
      throw new Error(`OpenAI API error: ${embeddingResponse.status}`);
    }

    const embeddingData = await embeddingResponse.json();
    const embedding = embeddingData.data[0].embedding;

    console.log(`Generated embedding with ${embedding.length} dimensions`);

    // Save embedding, content and metadata to database
    const { error: updateError } = await supabaseAdmin
      .from('projects')
      .update({ 
        embedding,
        content: textToEmbed,
        metadata: {
          name: project.name,
          neighborhood: project.neighborhood,
          city: project.city,
          state: project.state,
          description: project.description,
          reference_points: project.reference_points,
          project_website: project.project_website,
          launch_date: project.launch_date,
          delivery_date: project.delivery_date,
          status: project.status,
        }
      })
      .eq('id', projectId);

    if (updateError) {
      console.error('Error updating embedding:', updateError);
      throw updateError;
    }

    console.log(`Embedding saved successfully for project: ${projectId}`);

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error('Error generating embedding:', error);
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});



# Logs

## Eventos registrados (interno - sistema)

### Projetos
- project_created  
- project_updated  
- project_deleted  

### Imagens
- project_image_uploaded  
- project_image_deleted  

### Embeddings
- project_embedding_generated  
- project_embedding_failed  
- project_embedding_retried  

## Campos obrigatórios

- user_email  
- action (evento interno, ex: project_created)  
- entity (project / image / embedding)  
- field_changed (quando aplicável)  
- project_id  
- timestamp (UTC + convertido para horário de Brasília)  
- status (success | error)  
- error_message (se houver)  

## Regras de uso

- O sistema sempre salva o evento em inglês (campo `action`)
- A interface deve traduzir isso para português na exibição

## Tradução para exibição (frontend)

### Projetos
- project_created → criou um projeto  
- project_updated → atualizou um projeto  
- project_deleted → deletou um projeto  

### Imagens
- project_image_uploaded → adicionou uma imagem  
- project_image_deleted → deletou uma imagem  

### Embeddings
- project_embedding_generated → gerou o embedding  
- project_embedding_failed → falha ao gerar embedding  
- project_embedding_retried → tentou gerar embedding novamente  

## Formato do log (exibição para usuário)

> "O usuário [email] [ação traduzida], em [data] às [hora] (horário de Brasília)"

## Exemplos

> "O usuário email@email.com criou um projeto, hoje às 14:22 (horário de Brasília)"

> "O usuário email@email.com atualizou o projeto, hoje às 15:10 (horário de Brasília)"

> "O usuário email@email.com deletou uma imagem, hoje às 16:45 (horário de Brasília)"

> "Falha ao gerar embedding do projeto: limite da API atingido, hoje às 17:06 (horário de Brasília)"

# # Segurança

- Frontend nunca valida permissões  
- Todas as requisições usam auth.uid()  
- Nenhum ID sensível pode ser enviado manualmente ou acessado pelo cliente  

## RLS Policy:

alter table projects enable row level security;

create policy "Acesso projects"
on projects
for all
to authenticated
using (
  can_access_area('projects')
)
with check (
  can_access_area('projects')
);
