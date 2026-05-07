-- RLS para todas as tabelas em public.
-- Helpers SECURITY DEFINER evitam recursão ao consultar users a partir de policies em users.

-- ============================================================================
-- Helpers
-- ============================================================================

create or replace function public.is_admin(uid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.users
    where id = uid and role = 'admin' and is_active = true
  )
$$;

create or replace function public.is_active_user(uid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.users
    where id = uid and is_active = true
  )
$$;

create or replace function public.user_has_area(uid uuid, area text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.users
    where id = uid
      and is_active = true
      and (role = 'admin' or area = any(permitted_areas))
  )
$$;

revoke all on function public.is_admin(uuid) from public;
revoke all on function public.is_active_user(uuid) from public;
revoke all on function public.user_has_area(uuid, text) from public;
grant execute on function public.is_admin(uuid) to authenticated;
grant execute on function public.is_active_user(uuid) to authenticated;
grant execute on function public.user_has_area(uuid, text) to authenticated;

-- ============================================================================
-- users
-- ============================================================================

alter table public.users enable row level security;

drop policy if exists users_select_self on public.users;
create policy users_select_self on public.users
  for select using (id = auth.uid());

drop policy if exists users_select_admin on public.users;
create policy users_select_admin on public.users
  for select using (public.is_admin(auth.uid()));

drop policy if exists users_insert_admin on public.users;
create policy users_insert_admin on public.users
  for insert with check (public.is_admin(auth.uid()));

drop policy if exists users_update_admin on public.users;
create policy users_update_admin on public.users
  for update using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

drop policy if exists users_delete_admin on public.users;
create policy users_delete_admin on public.users
  for delete using (public.is_admin(auth.uid()));

grant select, insert, update, delete on public.users to authenticated;

-- ============================================================================
-- brokers + broker_availability  (leitura: ativos / escrita: admin)
-- ============================================================================

alter table public.brokers enable row level security;

drop policy if exists brokers_select_active on public.brokers;
create policy brokers_select_active on public.brokers
  for select using (public.is_active_user(auth.uid()));

drop policy if exists brokers_insert_admin on public.brokers;
create policy brokers_insert_admin on public.brokers
  for insert with check (public.is_admin(auth.uid()));

drop policy if exists brokers_update_admin on public.brokers;
create policy brokers_update_admin on public.brokers
  for update using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

drop policy if exists brokers_delete_admin on public.brokers;
create policy brokers_delete_admin on public.brokers
  for delete using (public.is_admin(auth.uid()));

grant select, insert, update, delete on public.brokers to authenticated;

alter table public.broker_availability enable row level security;

drop policy if exists broker_availability_select_active on public.broker_availability;
create policy broker_availability_select_active on public.broker_availability
  for select using (public.is_active_user(auth.uid()));

drop policy if exists broker_availability_insert_admin on public.broker_availability;
create policy broker_availability_insert_admin on public.broker_availability
  for insert with check (public.is_admin(auth.uid()));

drop policy if exists broker_availability_update_admin on public.broker_availability;
create policy broker_availability_update_admin on public.broker_availability
  for update using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

drop policy if exists broker_availability_delete_admin on public.broker_availability;
create policy broker_availability_delete_admin on public.broker_availability
  for delete using (public.is_admin(auth.uid()));

grant select, insert, update, delete on public.broker_availability to authenticated;

-- ============================================================================
-- leads / projects / project_images / prompt  (gated por área)
-- ============================================================================

alter table public.leads enable row level security;

drop policy if exists leads_all on public.leads;
create policy leads_all on public.leads
  for all
  using (public.user_has_area(auth.uid(), 'leads'))
  with check (public.user_has_area(auth.uid(), 'leads'));

grant select, insert, update, delete on public.leads to authenticated;

alter table public.projects enable row level security;

drop policy if exists projects_all on public.projects;
create policy projects_all on public.projects
  for all
  using (public.user_has_area(auth.uid(), 'projects'))
  with check (public.user_has_area(auth.uid(), 'projects'));

grant select, insert, update, delete on public.projects to authenticated;

alter table public.project_images enable row level security;

drop policy if exists project_images_all on public.project_images;
create policy project_images_all on public.project_images
  for all
  using (public.user_has_area(auth.uid(), 'projects'))
  with check (public.user_has_area(auth.uid(), 'projects'));

grant select, insert, update, delete on public.project_images to authenticated;

alter table public.prompt enable row level security;

drop policy if exists prompt_all on public.prompt;
create policy prompt_all on public.prompt
  for all
  using (public.user_has_area(auth.uid(), 'prompt'))
  with check (public.user_has_area(auth.uid(), 'prompt'));

grant select, insert, update, delete on public.prompt to authenticated;

-- ============================================================================
-- hallucination_alerts / improvement_suggestions  (admin only)
-- ============================================================================

alter table public.hallucination_alerts enable row level security;

drop policy if exists hallucination_alerts_admin on public.hallucination_alerts;
create policy hallucination_alerts_admin on public.hallucination_alerts
  for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

grant select, insert, update, delete on public.hallucination_alerts to authenticated;

alter table public.improvement_suggestions enable row level security;

drop policy if exists improvement_suggestions_admin on public.improvement_suggestions;
create policy improvement_suggestions_admin on public.improvement_suggestions
  for all
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

grant select, insert, update, delete on public.improvement_suggestions to authenticated;

-- ============================================================================
-- n8n_assistant_dash_history  (cada usuário lê só o próprio histórico, escrita via service_role)
-- ============================================================================

alter table public.n8n_assistant_dash_history enable row level security;

drop policy if exists assistant_history_select_self on public.n8n_assistant_dash_history;
create policy assistant_history_select_self on public.n8n_assistant_dash_history
  for select using (session_id = (auth.jwt() ->> 'email'));

drop policy if exists assistant_history_delete_self on public.n8n_assistant_dash_history;
create policy assistant_history_delete_self on public.n8n_assistant_dash_history
  for delete using (session_id = (auth.jwt() ->> 'email'));

grant select, delete on public.n8n_assistant_dash_history to authenticated;

-- ============================================================================
-- n8n_history  (RLS habilitada sem policies — só service_role acessa)
-- ============================================================================

alter table public.n8n_history enable row level security;
-- (sem policies => acesso negado para anon/authenticated; service_role bypassa)

-- ============================================================================
-- storage: bucket "imagens-projetos"
--   leitura pública (download direto pelo agente n8n via URL pública)
--   escrita restrita a usuários com área 'projects'
-- ============================================================================

drop policy if exists imagens_projetos_select_public on storage.objects;
create policy imagens_projetos_select_public on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'imagens-projetos');

drop policy if exists imagens_projetos_insert_projects on storage.objects;
create policy imagens_projetos_insert_projects on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'imagens-projetos'
    and public.user_has_area(auth.uid(), 'projects')
  );

drop policy if exists imagens_projetos_update_projects on storage.objects;
create policy imagens_projetos_update_projects on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'imagens-projetos'
    and public.user_has_area(auth.uid(), 'projects')
  )
  with check (
    bucket_id = 'imagens-projetos'
    and public.user_has_area(auth.uid(), 'projects')
  );

drop policy if exists imagens_projetos_delete_projects on storage.objects;
create policy imagens_projetos_delete_projects on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'imagens-projetos'
    and public.user_has_area(auth.uid(), 'projects')
  );
