--
-- PostgreSQL database dump
--

-- \restrict WENfpXik1SoOhrvJD3gkcPJazUvXfh5xIdGVbi892Grk38ch4VUjqagf7XGv35n

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
-- SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: SCHEMA "public"; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA "public" IS 'standard public schema';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";


--
-- Name: EXTENSION "pg_stat_statements"; Type: COMMENT; Schema: -; Owner: 
--

-- COMMENT ON EXTENSION "pg_stat_statements" IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";


--
-- Name: EXTENSION "pgcrypto"; Type: COMMENT; Schema: -; Owner: 
--

-- COMMENT ON EXTENSION "pgcrypto" IS 'cryptographic functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";


--
-- Name: EXTENSION "supabase_vault"; Type: COMMENT; Schema: -; Owner: 
--

-- COMMENT ON EXTENSION "supabase_vault" IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

-- COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public";


--
-- Name: EXTENSION "vector"; Type: COMMENT; Schema: -; Owner: 
--

-- COMMENT ON EXTENSION "vector" IS 'vector data type and ivfflat and hnsw access methods';


--
-- Name: alert_severity; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE "public"."alert_severity" AS ENUM (
    'Alto',
    'Médio',
    'Baixo'
);


ALTER TYPE "public"."alert_severity" OWNER TO "postgres";

--
-- Name: alert_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE "public"."alert_status" AS ENUM (
    'resolvido',
    'em andamento',
    'em testes',
    'pendente',
    'cancelado'
);


ALTER TYPE "public"."alert_status" OWNER TO "postgres";

--
-- Name: log_action; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE "public"."log_action" AS ENUM (
    'CREATE',
    'UPDATE',
    'DELETE'
);


ALTER TYPE "public"."log_action" OWNER TO "postgres";

--
-- Name: log_feature; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE "public"."log_feature" AS ENUM (
    'prompts',
    'projetos',
    'corretores',
    'chat',
    'leads',
    'metricas'
);


ALTER TYPE "public"."log_feature" OWNER TO "postgres";

--
-- Name: project_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE "public"."project_status" AS ENUM (
    'Ativo',
    'Inativo',
    'Disponível em breve'
);


ALTER TYPE "public"."project_status" OWNER TO "postgres";

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE "public"."user_role" AS ENUM (
    'admin',
    'colaborador'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";

--
-- Name: can_access_area("text"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."can_access_area"("area" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select case
    when u.role = 'admin' then true
    when u.is_active = false then false
    else area = any(u.permitted_areas)
  end
  from public.users u
  where u.id = auth.uid();
$$;


ALTER FUNCTION "public"."can_access_area"("area" "text") OWNER TO "postgres";

--
-- Name: delete_chat_history_on_user_delete(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."delete_chat_history_on_user_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if old.email is not null then
    delete from public.n8n_assistant_dash_history
    where session_id = old.email;
  end if;
  return old;
end;
$$;


ALTER FUNCTION "public"."delete_chat_history_on_user_delete"() OWNER TO "postgres";

--
-- Name: get_hallucination_rate(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."get_hallucination_rate"("p_start" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_end" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS TABLE("total_messages" bigint, "total_incorrect" bigint, "rate" numeric)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with msg as (
    select count(*)::bigint as total_messages
    from public.n8n_history
    where (p_start is null or created_at >= p_start)
      and (p_end   is null or created_at <= p_end)
  ),
  incorrect as (
    select coalesce(sum(number_incorrect_messages), 0)::bigint as total_incorrect
    from public.hallucination_alerts
    where (p_start is null or created_at >= p_start)
      and (p_end   is null or created_at <= p_end)
  )
  select
    msg.total_messages,
    incorrect.total_incorrect,
    case when msg.total_messages > 0
      then (incorrect.total_incorrect::numeric / msg.total_messages::numeric) * 100
      else 0
    end as rate
  from msg, incorrect;
$$;


ALTER FUNCTION "public"."get_hallucination_rate"("p_start" timestamp with time zone, "p_end" timestamp with time zone) OWNER TO "postgres";

--
-- Name: get_next_corretor(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."get_next_corretor"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_now timestamptz := now() at time zone 'America/Sao_Paulo';
  v_hoje date := v_now::date;
  v_hora text := to_char(v_now, 'HH24:MI:SS');
  v_corretor record;
  v_proximo record;
begin

  select b.id, b.first_name, b.last_name, b.whatsapp,
         ba.id as avail_id, ba.queue_position
  into v_corretor
  from brokers b
  join broker_availability ba on ba.broker_id = b.id
  where ba.available_date = v_hoje
    and ba.is_available = true
    and v_hora between ba.start_time and ba.end_time
    and b.is_active = true
  order by ba.queue_position asc
  limit 1;

  if v_corretor is not null then
    update broker_availability
    set queue_position = (
      select max(queue_position) + 1
      from broker_availability
      where available_date = v_hoje
        and is_available = true
        and start_time = (select start_time from broker_availability where id = v_corretor.avail_id)
        and end_time = (select end_time from broker_availability where id = v_corretor.avail_id)
    )
    where id = v_corretor.avail_id;

    return json_build_object(
      'disponivel_agora', true,
      'nome', v_corretor.first_name || ' ' || v_corretor.last_name,
      'whatsapp', v_corretor.whatsapp,
      'data', null
    );
  end if;

  select b.id, b.first_name, b.last_name, b.whatsapp,
         ba.id as avail_id, ba.available_date, ba.start_time, ba.queue_position
  into v_proximo
  from brokers b
  join broker_availability ba on ba.broker_id = b.id
  where ba.is_available = true
    and b.is_active = true
    and (
      ba.available_date > v_hoje or
      (ba.available_date = v_hoje and ba.start_time > v_hora)
    )
  order by ba.available_date asc, ba.start_time asc, ba.queue_position asc
  limit 1;

  if v_proximo is not null then
    update broker_availability
    set queue_position = (
      select max(queue_position) + 1
      from broker_availability
      where available_date = v_proximo.available_date
        and start_time = v_proximo.start_time
        and is_available = true
    )
    where id = v_proximo.avail_id;

    return json_build_object(
      'disponivel_agora', false,
      'nome', v_proximo.first_name || ' ' || v_proximo.last_name,
      'whatsapp', v_proximo.whatsapp,
      'data', (v_proximo.available_date::text || 'T' || v_proximo.start_time)
    );
  end if;

  return json_build_object('erro', 'Nenhum corretor disponível');

end;
$$;


ALTER FUNCTION "public"."get_next_corretor"() OWNER TO "postgres";

--
-- Name: handle_new_auth_user(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.users (id, email, role, is_active, permitted_areas)
  values (new.id, new.email, 'colaborador', true, '{}')
  on conflict (id) do nothing;
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_auth_user"() OWNER TO "postgres";

--
-- Name: is_active_user("uuid"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."is_active_user"("uid" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.users
    where id = uid and is_active = true
  )
$$;


ALTER FUNCTION "public"."is_active_user"("uid" "uuid") OWNER TO "postgres";

--
-- Name: is_admin(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin'
  );
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";

--
-- Name: FUNCTION "is_admin"(); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION "public"."is_admin"() IS 'Returns true if the current authenticated user is an admin';


--
-- Name: is_admin("uuid"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."is_admin"("uid" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.users
    where id = uid and role = 'admin' and is_active = true
  )
$$;


ALTER FUNCTION "public"."is_admin"("uid" "uuid") OWNER TO "postgres";

--
-- Name: match_documents("text", "jsonb", integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."match_documents"("query_embedding" "text", "filter" "jsonb" DEFAULT '{}'::"jsonb", "match_count" integer DEFAULT 10) RETURNS TABLE("id" "uuid", "content" "text", "metadata" "jsonb", "similarity" double precision)
    LANGUAGE "sql" STABLE PARALLEL SAFE
    AS $$
  SELECT
    p.id,
    p.content,
    COALESCE(p.metadata, '{}'::jsonb) AS metadata,
    (1 - (p.embedding <=> query_embedding::vector))::double precision AS similarity
  FROM public.projects AS p
  WHERE p.embedding IS NOT NULL
    AND p.content IS NOT NULL
    AND p.content <> ''
    AND (filter = '{}'::jsonb OR COALESCE(p.metadata, '{}'::jsonb) @> filter)
  ORDER BY p.embedding <=> query_embedding::vector
  LIMIT LEAST(coalesce(match_count, 10), 100);
$$;


ALTER FUNCTION "public"."match_documents"("query_embedding" "text", "filter" "jsonb", "match_count" integer) OWNER TO "postgres";

--
-- Name: FUNCTION "match_documents"("query_embedding" "text", "filter" "jsonb", "match_count" integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION "public"."match_documents"("query_embedding" "text", "filter" "jsonb", "match_count" integer) IS 'Vector similarity on projects.embedding; optional metadata filter; query_embedding as text cast to vector.';


--
-- Name: search_projects_by_embedding("public"."vector", double precision, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."search_projects_by_embedding"("query_embedding" "public"."vector", "match_threshold" double precision DEFAULT 0.7, "match_count" integer DEFAULT 10) RETURNS TABLE("id" "uuid", "nome" "text", "bairro" "text", "descricao" "text", "status" "public"."project_status", "data_entrega" "date", "data_lancamento" "date", "pdf_url" "text", "email_responsavel" "text", "criado_em" timestamp with time zone, "similarity_score" double precision)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.nome,
    p.bairro,
    p.descricao,
    p.status,
    p.data_entrega,
    p.data_lancamento,
    p.pdf_url,
    p.email_responsavel,
    p.criado_em,
    1 - (p.embedding <=> query_embedding) as similarity_score
  FROM public.projetos p
  WHERE p.embedding IS NOT NULL
    AND 1 - (p.embedding <=> query_embedding) > match_threshold
  ORDER BY p.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;


ALTER FUNCTION "public"."search_projects_by_embedding"("query_embedding" "public"."vector", "match_threshold" double precision, "match_count" integer) OWNER TO "postgres";

--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";

--
-- Name: update_atualizado_em_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."update_atualizado_em_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.atualizado_em = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."update_atualizado_em_column"() OWNER TO "postgres";

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

--
-- Name: user_has_area("uuid", "text"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE OR REPLACE FUNCTION "public"."user_has_area"("uid" "uuid", "area" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.users
    where id = uid
      and is_active = true
      and (role = 'admin' or area = any(permitted_areas))
  )
$$;


ALTER FUNCTION "public"."user_has_area"("uid" "uuid", "area" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

--
-- Name: broker_availability; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."broker_availability" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "broker_id" "uuid",
    "available_date" "date",
    "is_available" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "start_time" "text",
    "end_time" "text",
    "queue_position" integer DEFAULT 0
);


ALTER TABLE "public"."broker_availability" OWNER TO "postgres";

--
-- Name: brokers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."brokers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "first_name" "text",
    "last_name" "text",
    "email" "text",
    "whatsapp" "text",
    "calendar_color" "text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."brokers" OWNER TO "postgres";

--
-- Name: hallucination_alerts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."hallucination_alerts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text",
    "description" "text",
    "status" "public"."alert_status" DEFAULT 'pendente'::"public"."alert_status",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "severity" "public"."alert_severity",
    "number_incorrect_messages" smallint
);


ALTER TABLE "public"."hallucination_alerts" OWNER TO "postgres";

--
-- Name: improvement_suggestions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."improvement_suggestions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "category" "text",
    "problem_description" "text",
    "reason" "text",
    "solution" "text",
    "is_resolved" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."improvement_suggestions" OWNER TO "postgres";

--
-- Name: leads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."leads" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "whatsapp" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "agreed_terms" boolean,
    "request_notes" "text",
    "is_active" boolean,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "initial_message" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."leads" OWNER TO "postgres";

--
-- Name: TABLE "leads"; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE "public"."leads" IS 'Leads captados (atribuição por nome).';


--
-- Name: logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_email" "text" NOT NULL,
    "action" "public"."log_action" NOT NULL,
    "feature" "public"."log_feature" NOT NULL,
    "description" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."logs" OWNER TO "postgres";

--
-- Name: n8n_assistant_dash_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."n8n_assistant_dash_history" (
    "id" integer NOT NULL,
    "session_id" character varying(255) NOT NULL,
    "message" "jsonb" NOT NULL
);


ALTER TABLE "public"."n8n_assistant_dash_history" OWNER TO "postgres";

--
-- Name: n8n_assistant_dash_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE IF NOT EXISTS "public"."n8n_assistant_dash_history_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."n8n_assistant_dash_history_id_seq" OWNER TO "postgres";

--
-- Name: n8n_assistant_dash_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "public"."n8n_assistant_dash_history_id_seq" OWNED BY "public"."n8n_assistant_dash_history"."id";


--
-- Name: n8n_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."n8n_history" (
    "id" integer NOT NULL,
    "session_id" character varying(255) NOT NULL,
    "message" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."n8n_history" OWNER TO "postgres";

--
-- Name: n8n_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE IF NOT EXISTS "public"."n8n_history_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."n8n_history_id_seq" OWNER TO "postgres";

--
-- Name: n8n_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE "public"."n8n_history_id_seq" OWNED BY "public"."n8n_history"."id";


--
-- Name: project_images; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."project_images" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "project_id" "uuid" NOT NULL,
    "image_url" "text" NOT NULL,
    "index_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."project_images" OWNER TO "postgres";

--
-- Name: TABLE "project_images"; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE "public"."project_images" IS 'Imagens de cada projeto, com ordenação.';


--
-- Name: COLUMN "project_images"."index_order"; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN "public"."project_images"."index_order" IS 'Ordem de exibição (0,1,2,...)';


--
-- Name: projects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."projects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text",
    "launch_date" "date",
    "delivery_date" "date",
    "neighborhood" "text",
    "description" "text",
    "status" "public"."project_status" DEFAULT 'Ativo'::"public"."project_status",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "embedding" "public"."vector"(1536),
    "content" "text",
    "metadata" "jsonb",
    "reference_points" "text",
    "project_images_urls" "text"[] DEFAULT '{}'::"text"[],
    "project_website" "text",
    "city" "text",
    "state" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."projects" OWNER TO "postgres";

--
-- Name: TABLE "projects"; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE "public"."projects" IS 'Empreendimentos (projetos imobiliários).';


--
-- Name: COLUMN "projects"."neighborhood"; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN "public"."projects"."neighborhood" IS 'Nome do bairro (string direta, sem tabela de bairros).';


--
-- Name: prompt; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."prompt" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "identity" "text" NOT NULL,
    "qualification_methodology" "text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "emojis" "text",
    "full_prompt" "text"
);


ALTER TABLE "public"."prompt" OWNER TO "postgres";

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "role" "public"."user_role" DEFAULT 'colaborador'::"public"."user_role" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "permitted_areas" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."users" OWNER TO "postgres";

--
-- Name: n8n_assistant_dash_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."n8n_assistant_dash_history" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."n8n_assistant_dash_history_id_seq"'::"regclass");


--
-- Name: n8n_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."n8n_history" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."n8n_history_id_seq"'::"regclass");


--
-- Name: prompt agent_prompts_pkey1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."prompt"
    ADD CONSTRAINT "agent_prompts_pkey1" PRIMARY KEY ("id");


--
-- Name: broker_availability broker_availability_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."broker_availability"
    ADD CONSTRAINT "broker_availability_pkey" PRIMARY KEY ("id");


--
-- Name: brokers brokers_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."brokers"
    ADD CONSTRAINT "brokers_email_key" UNIQUE ("email");


--
-- Name: brokers brokers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."brokers"
    ADD CONSTRAINT "brokers_pkey" PRIMARY KEY ("id");


--
-- Name: hallucination_alerts hallucination_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."hallucination_alerts"
    ADD CONSTRAINT "hallucination_alerts_pkey" PRIMARY KEY ("id");


--
-- Name: improvement_suggestions improvement_suggestions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."improvement_suggestions"
    ADD CONSTRAINT "improvement_suggestions_pkey" PRIMARY KEY ("id");


--
-- Name: leads leads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."leads"
    ADD CONSTRAINT "leads_pkey" PRIMARY KEY ("id");


--
-- Name: logs logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."logs"
    ADD CONSTRAINT "logs_pkey" PRIMARY KEY ("id");


--
-- Name: n8n_assistant_dash_history n8n_assistant_dash_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."n8n_assistant_dash_history"
    ADD CONSTRAINT "n8n_assistant_dash_history_pkey" PRIMARY KEY ("id");


--
-- Name: n8n_history n8n_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."n8n_history"
    ADD CONSTRAINT "n8n_history_pkey" PRIMARY KEY ("id");


--
-- Name: project_images project_images_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."project_images"
    ADD CONSTRAINT "project_images_pkey" PRIMARY KEY ("id");


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_pkey" PRIMARY KEY ("id");


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");


--
-- Name: idx_project_images_project_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "idx_project_images_project_id" ON "public"."project_images" USING "btree" ("project_id");


--
-- Name: idx_project_images_project_order; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "idx_project_images_project_order" ON "public"."project_images" USING "btree" ("project_id", "index_order");


--
-- Name: idx_projects_delivery_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "idx_projects_delivery_date" ON "public"."projects" USING "btree" ("delivery_date");


--
-- Name: idx_projects_launch_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "idx_projects_launch_date" ON "public"."projects" USING "btree" ("launch_date");


--
-- Name: idx_projects_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "idx_projects_status" ON "public"."projects" USING "btree" ("status");


--
-- Name: logs_action_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "logs_action_idx" ON "public"."logs" USING "btree" ("action");


--
-- Name: logs_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "logs_created_at_idx" ON "public"."logs" USING "btree" ("created_at" DESC);


--
-- Name: logs_feature_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "logs_feature_idx" ON "public"."logs" USING "btree" ("feature");


--
-- Name: projects_embedding_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "projects_embedding_idx" ON "public"."projects" USING "hnsw" ("embedding" "public"."vector_cosine_ops") WITH ("m"='16', "ef_construction"='64');


--
-- Name: projects_embedding_ivfflat; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "projects_embedding_ivfflat" ON "public"."projects" USING "ivfflat" ("embedding" "public"."vector_cosine_ops");


--
-- Name: projects_metadata_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "projects_metadata_gin" ON "public"."projects" USING "gin" ("metadata");


--
-- Name: users users_set_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE OR REPLACE TRIGGER "users_set_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


--
-- Name: broker_availability broker_availability_broker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."broker_availability"
    ADD CONSTRAINT "broker_availability_broker_id_fkey" FOREIGN KEY ("broker_id") REFERENCES "public"."brokers"("id") ON DELETE CASCADE;


--
-- Name: project_images project_images_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."project_images"
    ADD CONSTRAINT "project_images_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;


--
-- Name: users users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: prompt access_agent_prompts; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "access_agent_prompts" ON "public"."prompt" TO "authenticated" USING ("public"."can_access_area"('prompt'::"text")) WITH CHECK ("public"."can_access_area"('prompt'::"text"));


--
-- Name: broker_availability access_broker_availability; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "access_broker_availability" ON "public"."broker_availability" TO "authenticated" USING ("public"."can_access_area"('brokers'::"text")) WITH CHECK ("public"."can_access_area"('brokers'::"text"));


--
-- Name: brokers access_brokers; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "access_brokers" ON "public"."brokers" TO "authenticated" USING ("public"."can_access_area"('brokers'::"text")) WITH CHECK ("public"."can_access_area"('brokers'::"text"));


--
-- Name: hallucination_alerts access_hallucination_alerts; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "access_hallucination_alerts" ON "public"."hallucination_alerts" TO "authenticated" USING ("public"."can_access_area"('insights'::"text")) WITH CHECK ("public"."can_access_area"('insights'::"text"));


--
-- Name: improvement_suggestions access_improvement_suggestions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "access_improvement_suggestions" ON "public"."improvement_suggestions" TO "authenticated" USING ("public"."can_access_area"('insights'::"text")) WITH CHECK ("public"."can_access_area"('insights'::"text"));


--
-- Name: leads access_leads; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "access_leads" ON "public"."leads" TO "authenticated" USING ("public"."can_access_area"('leads'::"text")) WITH CHECK ("public"."can_access_area"('leads'::"text"));


--
-- Name: project_images access_project_images; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "access_project_images" ON "public"."project_images" TO "authenticated" USING ("public"."can_access_area"('projects'::"text")) WITH CHECK ("public"."can_access_area"('projects'::"text"));


--
-- Name: projects access_projects; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "access_projects" ON "public"."projects" TO "authenticated" USING ("public"."can_access_area"('projects'::"text")) WITH CHECK ("public"."can_access_area"('projects'::"text"));


--
-- Name: broker_availability; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."broker_availability" ENABLE ROW LEVEL SECURITY;

--
-- Name: brokers; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."brokers" ENABLE ROW LEVEL SECURITY;

--
-- Name: n8n_assistant_dash_history chat_history_all_own; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "chat_history_all_own" ON "public"."n8n_assistant_dash_history" TO "authenticated" USING ((("session_id")::"text" = ("auth"."jwt"() ->> 'email'::"text")));


--
-- Name: hallucination_alerts; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."hallucination_alerts" ENABLE ROW LEVEL SECURITY;

--
-- Name: improvement_suggestions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."improvement_suggestions" ENABLE ROW LEVEL SECURITY;

--
-- Name: leads; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."leads" ENABLE ROW LEVEL SECURITY;

--
-- Name: logs; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."logs" ENABLE ROW LEVEL SECURITY;

--
-- Name: logs logs_insert_authenticated; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "logs_insert_authenticated" ON "public"."logs" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND (("u"."role" = 'admin'::"public"."user_role") OR ("u"."is_active" = true))))));


--
-- Name: logs logs_select_admin; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "logs_select_admin" ON "public"."logs" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = 'admin'::"public"."user_role")))));


--
-- Name: n8n_assistant_dash_history; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."n8n_assistant_dash_history" ENABLE ROW LEVEL SECURITY;

--
-- Name: n8n_history; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."n8n_history" ENABLE ROW LEVEL SECURITY;

--
-- Name: project_images; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."project_images" ENABLE ROW LEVEL SECURITY;

--
-- Name: project_images project_images_all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "project_images_all" ON "public"."project_images" USING ("public"."user_has_area"("auth"."uid"(), 'projects'::"text")) WITH CHECK ("public"."user_has_area"("auth"."uid"(), 'projects'::"text"));


--
-- Name: projects; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."projects" ENABLE ROW LEVEL SECURITY;

--
-- Name: prompt; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."prompt" ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_admin_all; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "users_admin_all" ON "public"."users" TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());


--
-- Name: users users_select_self; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "users_select_self" ON "public"."users" FOR SELECT TO "authenticated" USING (("id" = "auth"."uid"()));


--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: postgres
--

-- CREATE PUBLICATION "supabase_realtime" WITH (publish = 'insert, update, delete, truncate');


ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";

--
-- Name: SCHEMA "public"; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";


--
-- Name: FUNCTION "halfvec_in"("cstring", "oid", integer); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_in"("cstring", "oid", integer) TO "service_role";


--
-- Name: FUNCTION "halfvec_out"("public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_out"("public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_recv"("internal", "oid", integer); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_recv"("internal", "oid", integer) TO "service_role";


--
-- Name: FUNCTION "halfvec_send"("public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_send"("public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_typmod_in"("cstring"[]); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_typmod_in"("cstring"[]) TO "service_role";


--
-- Name: TYPE "log_action"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TYPE "public"."log_action" TO "authenticated";


--
-- Name: TYPE "log_feature"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TYPE "public"."log_feature" TO "authenticated";


--
-- Name: FUNCTION "sparsevec_in"("cstring", "oid", integer); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_in"("cstring", "oid", integer) TO "service_role";


--
-- Name: FUNCTION "sparsevec_out"("public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_out"("public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "sparsevec_recv"("internal", "oid", integer); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_recv"("internal", "oid", integer) TO "service_role";


--
-- Name: FUNCTION "sparsevec_send"("public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_send"("public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "sparsevec_typmod_in"("cstring"[]); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_typmod_in"("cstring"[]) TO "service_role";


--
-- Name: FUNCTION "vector_in"("cstring", "oid", integer); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_in"("cstring", "oid", integer) TO "service_role";


--
-- Name: FUNCTION "vector_out"("public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_out"("public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_recv"("internal", "oid", integer); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_recv"("internal", "oid", integer) TO "service_role";


--
-- Name: FUNCTION "vector_send"("public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_send"("public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_typmod_in"("cstring"[]); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_typmod_in"("cstring"[]) TO "service_role";


--
-- Name: FUNCTION "array_to_halfvec"(real[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(real[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "array_to_sparsevec"(real[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(real[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "array_to_vector"(real[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(real[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "array_to_halfvec"(double precision[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(double precision[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "array_to_sparsevec"(double precision[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(double precision[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "array_to_vector"(double precision[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(double precision[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "array_to_halfvec"(integer[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(integer[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "array_to_sparsevec"(integer[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(integer[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "array_to_vector"(integer[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(integer[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "array_to_halfvec"(numeric[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_halfvec"(numeric[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "array_to_sparsevec"(numeric[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_sparsevec"(numeric[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "array_to_vector"(numeric[], integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."array_to_vector"(numeric[], integer, boolean) TO "service_role";


--
-- Name: FUNCTION "halfvec_to_float4"("public"."halfvec", integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_float4"("public"."halfvec", integer, boolean) TO "service_role";


--
-- Name: FUNCTION "halfvec"("public"."halfvec", integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec"("public"."halfvec", integer, boolean) TO "service_role";


--
-- Name: FUNCTION "halfvec_to_sparsevec"("public"."halfvec", integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_sparsevec"("public"."halfvec", integer, boolean) TO "service_role";


--
-- Name: FUNCTION "halfvec_to_vector"("public"."halfvec", integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_to_vector"("public"."halfvec", integer, boolean) TO "service_role";


--
-- Name: FUNCTION "sparsevec_to_halfvec"("public"."sparsevec", integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_halfvec"("public"."sparsevec", integer, boolean) TO "service_role";


--
-- Name: FUNCTION "sparsevec"("public"."sparsevec", integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec"("public"."sparsevec", integer, boolean) TO "service_role";


--
-- Name: FUNCTION "sparsevec_to_vector"("public"."sparsevec", integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_to_vector"("public"."sparsevec", integer, boolean) TO "service_role";


--
-- Name: FUNCTION "vector_to_float4"("public"."vector", integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_float4"("public"."vector", integer, boolean) TO "service_role";


--
-- Name: FUNCTION "vector_to_halfvec"("public"."vector", integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_halfvec"("public"."vector", integer, boolean) TO "service_role";


--
-- Name: FUNCTION "vector_to_sparsevec"("public"."vector", integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_to_sparsevec"("public"."vector", integer, boolean) TO "service_role";


--
-- Name: FUNCTION "vector"("public"."vector", integer, boolean); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector"("public"."vector", integer, boolean) TO "service_role";


--
-- Name: FUNCTION "armor"("bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."armor"("bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."armor"("bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."armor"("bytea") TO "dashboard_user";


--
-- Name: FUNCTION "armor"("bytea", "text"[], "text"[]); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."armor"("bytea", "text"[], "text"[]) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."armor"("bytea", "text"[], "text"[]) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."armor"("bytea", "text"[], "text"[]) TO "dashboard_user";


--
-- Name: FUNCTION "crypt"("text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."crypt"("text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."crypt"("text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."crypt"("text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "dearmor"("text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."dearmor"("text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."dearmor"("text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."dearmor"("text") TO "dashboard_user";


--
-- Name: FUNCTION "decrypt"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."decrypt"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."decrypt"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."decrypt"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "decrypt_iv"("bytea", "bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."decrypt_iv"("bytea", "bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."decrypt_iv"("bytea", "bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."decrypt_iv"("bytea", "bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "digest"("bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."digest"("bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."digest"("bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."digest"("bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "digest"("text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."digest"("text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."digest"("text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."digest"("text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "encrypt"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."encrypt"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."encrypt"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."encrypt"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "encrypt_iv"("bytea", "bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."encrypt_iv"("bytea", "bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."encrypt_iv"("bytea", "bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."encrypt_iv"("bytea", "bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "gen_random_bytes"(integer); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."gen_random_bytes"(integer) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."gen_random_bytes"(integer) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."gen_random_bytes"(integer) TO "dashboard_user";


--
-- Name: FUNCTION "gen_random_uuid"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."gen_random_uuid"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."gen_random_uuid"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."gen_random_uuid"() TO "dashboard_user";


--
-- Name: FUNCTION "gen_salt"("text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."gen_salt"("text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."gen_salt"("text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."gen_salt"("text") TO "dashboard_user";


--
-- Name: FUNCTION "gen_salt"("text", integer); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."gen_salt"("text", integer) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."gen_salt"("text", integer) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."gen_salt"("text", integer) TO "dashboard_user";


--
-- Name: FUNCTION "hmac"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."hmac"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."hmac"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."hmac"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "hmac"("text", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."hmac"("text", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."hmac"("text", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."hmac"("text", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pg_stat_statements"("showtext" boolean, OUT "userid" "oid", OUT "dbid" "oid", OUT "toplevel" boolean, OUT "queryid" bigint, OUT "query" "text", OUT "plans" bigint, OUT "total_plan_time" double precision, OUT "min_plan_time" double precision, OUT "max_plan_time" double precision, OUT "mean_plan_time" double precision, OUT "stddev_plan_time" double precision, OUT "calls" bigint, OUT "total_exec_time" double precision, OUT "min_exec_time" double precision, OUT "max_exec_time" double precision, OUT "mean_exec_time" double precision, OUT "stddev_exec_time" double precision, OUT "rows" bigint, OUT "shared_blks_hit" bigint, OUT "shared_blks_read" bigint, OUT "shared_blks_dirtied" bigint, OUT "shared_blks_written" bigint, OUT "local_blks_hit" bigint, OUT "local_blks_read" bigint, OUT "local_blks_dirtied" bigint, OUT "local_blks_written" bigint, OUT "temp_blks_read" bigint, OUT "temp_blks_written" bigint, OUT "shared_blk_read_time" double precision, OUT "shared_blk_write_time" double precision, OUT "local_blk_read_time" double precision, OUT "local_blk_write_time" double precision, OUT "temp_blk_read_time" double precision, OUT "temp_blk_write_time" double precision, OUT "wal_records" bigint, OUT "wal_fpi" bigint, OUT "wal_bytes" numeric, OUT "jit_functions" bigint, OUT "jit_generation_time" double precision, OUT "jit_inlining_count" bigint, OUT "jit_inlining_time" double precision, OUT "jit_optimization_count" bigint, OUT "jit_optimization_time" double precision, OUT "jit_emission_count" bigint, OUT "jit_emission_time" double precision, OUT "jit_deform_count" bigint, OUT "jit_deform_time" double precision, OUT "stats_since" timestamp with time zone, OUT "minmax_stats_since" timestamp with time zone); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pg_stat_statements"("showtext" boolean, OUT "userid" "oid", OUT "dbid" "oid", OUT "toplevel" boolean, OUT "queryid" bigint, OUT "query" "text", OUT "plans" bigint, OUT "total_plan_time" double precision, OUT "min_plan_time" double precision, OUT "max_plan_time" double precision, OUT "mean_plan_time" double precision, OUT "stddev_plan_time" double precision, OUT "calls" bigint, OUT "total_exec_time" double precision, OUT "min_exec_time" double precision, OUT "max_exec_time" double precision, OUT "mean_exec_time" double precision, OUT "stddev_exec_time" double precision, OUT "rows" bigint, OUT "shared_blks_hit" bigint, OUT "shared_blks_read" bigint, OUT "shared_blks_dirtied" bigint, OUT "shared_blks_written" bigint, OUT "local_blks_hit" bigint, OUT "local_blks_read" bigint, OUT "local_blks_dirtied" bigint, OUT "local_blks_written" bigint, OUT "temp_blks_read" bigint, OUT "temp_blks_written" bigint, OUT "shared_blk_read_time" double precision, OUT "shared_blk_write_time" double precision, OUT "local_blk_read_time" double precision, OUT "local_blk_write_time" double precision, OUT "temp_blk_read_time" double precision, OUT "temp_blk_write_time" double precision, OUT "wal_records" bigint, OUT "wal_fpi" bigint, OUT "wal_bytes" numeric, OUT "jit_functions" bigint, OUT "jit_generation_time" double precision, OUT "jit_inlining_count" bigint, OUT "jit_inlining_time" double precision, OUT "jit_optimization_count" bigint, OUT "jit_optimization_time" double precision, OUT "jit_emission_count" bigint, OUT "jit_emission_time" double precision, OUT "jit_deform_count" bigint, OUT "jit_deform_time" double precision, OUT "stats_since" timestamp with time zone, OUT "minmax_stats_since" timestamp with time zone) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements"("showtext" boolean, OUT "userid" "oid", OUT "dbid" "oid", OUT "toplevel" boolean, OUT "queryid" bigint, OUT "query" "text", OUT "plans" bigint, OUT "total_plan_time" double precision, OUT "min_plan_time" double precision, OUT "max_plan_time" double precision, OUT "mean_plan_time" double precision, OUT "stddev_plan_time" double precision, OUT "calls" bigint, OUT "total_exec_time" double precision, OUT "min_exec_time" double precision, OUT "max_exec_time" double precision, OUT "mean_exec_time" double precision, OUT "stddev_exec_time" double precision, OUT "rows" bigint, OUT "shared_blks_hit" bigint, OUT "shared_blks_read" bigint, OUT "shared_blks_dirtied" bigint, OUT "shared_blks_written" bigint, OUT "local_blks_hit" bigint, OUT "local_blks_read" bigint, OUT "local_blks_dirtied" bigint, OUT "local_blks_written" bigint, OUT "temp_blks_read" bigint, OUT "temp_blks_written" bigint, OUT "shared_blk_read_time" double precision, OUT "shared_blk_write_time" double precision, OUT "local_blk_read_time" double precision, OUT "local_blk_write_time" double precision, OUT "temp_blk_read_time" double precision, OUT "temp_blk_write_time" double precision, OUT "wal_records" bigint, OUT "wal_fpi" bigint, OUT "wal_bytes" numeric, OUT "jit_functions" bigint, OUT "jit_generation_time" double precision, OUT "jit_inlining_count" bigint, OUT "jit_inlining_time" double precision, OUT "jit_optimization_count" bigint, OUT "jit_optimization_time" double precision, OUT "jit_emission_count" bigint, OUT "jit_emission_time" double precision, OUT "jit_deform_count" bigint, OUT "jit_deform_time" double precision, OUT "stats_since" timestamp with time zone, OUT "minmax_stats_since" timestamp with time zone) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements"("showtext" boolean, OUT "userid" "oid", OUT "dbid" "oid", OUT "toplevel" boolean, OUT "queryid" bigint, OUT "query" "text", OUT "plans" bigint, OUT "total_plan_time" double precision, OUT "min_plan_time" double precision, OUT "max_plan_time" double precision, OUT "mean_plan_time" double precision, OUT "stddev_plan_time" double precision, OUT "calls" bigint, OUT "total_exec_time" double precision, OUT "min_exec_time" double precision, OUT "max_exec_time" double precision, OUT "mean_exec_time" double precision, OUT "stddev_exec_time" double precision, OUT "rows" bigint, OUT "shared_blks_hit" bigint, OUT "shared_blks_read" bigint, OUT "shared_blks_dirtied" bigint, OUT "shared_blks_written" bigint, OUT "local_blks_hit" bigint, OUT "local_blks_read" bigint, OUT "local_blks_dirtied" bigint, OUT "local_blks_written" bigint, OUT "temp_blks_read" bigint, OUT "temp_blks_written" bigint, OUT "shared_blk_read_time" double precision, OUT "shared_blk_write_time" double precision, OUT "local_blk_read_time" double precision, OUT "local_blk_write_time" double precision, OUT "temp_blk_read_time" double precision, OUT "temp_blk_write_time" double precision, OUT "wal_records" bigint, OUT "wal_fpi" bigint, OUT "wal_bytes" numeric, OUT "jit_functions" bigint, OUT "jit_generation_time" double precision, OUT "jit_inlining_count" bigint, OUT "jit_inlining_time" double precision, OUT "jit_optimization_count" bigint, OUT "jit_optimization_time" double precision, OUT "jit_emission_count" bigint, OUT "jit_emission_time" double precision, OUT "jit_deform_count" bigint, OUT "jit_deform_time" double precision, OUT "stats_since" timestamp with time zone, OUT "minmax_stats_since" timestamp with time zone) TO "dashboard_user";


--
-- Name: FUNCTION "pg_stat_statements_info"(OUT "dealloc" bigint, OUT "stats_reset" timestamp with time zone); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pg_stat_statements_info"(OUT "dealloc" bigint, OUT "stats_reset" timestamp with time zone) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements_info"(OUT "dealloc" bigint, OUT "stats_reset" timestamp with time zone) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements_info"(OUT "dealloc" bigint, OUT "stats_reset" timestamp with time zone) TO "dashboard_user";


--
-- Name: FUNCTION "pg_stat_statements_reset"("userid" "oid", "dbid" "oid", "queryid" bigint, "minmax_only" boolean); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pg_stat_statements_reset"("userid" "oid", "dbid" "oid", "queryid" bigint, "minmax_only" boolean) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements_reset"("userid" "oid", "dbid" "oid", "queryid" bigint, "minmax_only" boolean) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements_reset"("userid" "oid", "dbid" "oid", "queryid" bigint, "minmax_only" boolean) TO "dashboard_user";


--
-- Name: FUNCTION "pgp_armor_headers"("text", OUT "key" "text", OUT "value" "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_armor_headers"("text", OUT "key" "text", OUT "value" "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_armor_headers"("text", OUT "key" "text", OUT "value" "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_armor_headers"("text", OUT "key" "text", OUT "value" "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_key_id"("bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_key_id"("bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_key_id"("bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_key_id"("bytea") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt"("bytea", "bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt"("bytea", "bytea", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt_bytea"("bytea", "bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt_bytea"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt_bytea"("bytea", "bytea", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_encrypt"("text", "bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_encrypt"("text", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_encrypt_bytea"("bytea", "bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_encrypt_bytea"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_decrypt"("bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_decrypt"("bytea", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_decrypt_bytea"("bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_decrypt_bytea"("bytea", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_encrypt"("text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_encrypt"("text", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_encrypt_bytea"("bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_encrypt_bytea"("bytea", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "uuid_generate_v1"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_generate_v1"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v1"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v1"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_generate_v1mc"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_generate_v1mc"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v1mc"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v1mc"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_generate_v3"("namespace" "uuid", "name" "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_generate_v3"("namespace" "uuid", "name" "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v3"("namespace" "uuid", "name" "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v3"("namespace" "uuid", "name" "text") TO "dashboard_user";


--
-- Name: FUNCTION "uuid_generate_v4"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_generate_v4"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v4"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v4"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_generate_v5"("namespace" "uuid", "name" "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_generate_v5"("namespace" "uuid", "name" "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v5"("namespace" "uuid", "name" "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v5"("namespace" "uuid", "name" "text") TO "dashboard_user";


--
-- Name: FUNCTION "uuid_nil"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_nil"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_nil"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_nil"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_ns_dns"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_ns_dns"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_dns"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_dns"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_ns_oid"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_ns_oid"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_oid"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_oid"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_ns_url"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_ns_url"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_url"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_url"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_ns_x500"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_ns_x500"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_x500"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_x500"() TO "dashboard_user";


--
-- Name: FUNCTION "binary_quantize"("public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "binary_quantize"("public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."binary_quantize"("public"."vector") TO "service_role";


--
-- Name: FUNCTION "can_access_area"("area" "text"); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."can_access_area"("area" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."can_access_area"("area" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_access_area"("area" "text") TO "service_role";


--
-- Name: FUNCTION "cosine_distance"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "cosine_distance"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "cosine_distance"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cosine_distance"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "delete_chat_history_on_user_delete"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."delete_chat_history_on_user_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_chat_history_on_user_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_chat_history_on_user_delete"() TO "service_role";


--
-- Name: FUNCTION "get_hallucination_rate"("p_start" timestamp with time zone, "p_end" timestamp with time zone); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."get_hallucination_rate"("p_start" timestamp with time zone, "p_end" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."get_hallucination_rate"("p_start" timestamp with time zone, "p_end" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_hallucination_rate"("p_start" timestamp with time zone, "p_end" timestamp with time zone) TO "service_role";


--
-- Name: FUNCTION "get_next_corretor"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."get_next_corretor"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_next_corretor"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_next_corretor"() TO "service_role";


--
-- Name: FUNCTION "halfvec_accum"(double precision[], "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_accum"(double precision[], "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_add"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_add"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_avg"(double precision[]); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_avg"(double precision[]) TO "service_role";


--
-- Name: FUNCTION "halfvec_cmp"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_cmp"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_combine"(double precision[], double precision[]); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_combine"(double precision[], double precision[]) TO "service_role";


--
-- Name: FUNCTION "halfvec_concat"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_concat"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_eq"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_eq"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_ge"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ge"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_gt"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_gt"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_l2_squared_distance"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_le"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_le"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_lt"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_lt"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_mul"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_mul"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_ne"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_ne"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_negative_inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_spherical_distance"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_spherical_distance"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "halfvec_sub"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."halfvec_sub"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "hamming_distance"(bit, bit); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."hamming_distance"(bit, bit) TO "service_role";


--
-- Name: FUNCTION "handle_new_auth_user"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "service_role";


--
-- Name: FUNCTION "hnsw_bit_support"("internal"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_bit_support"("internal") TO "service_role";


--
-- Name: FUNCTION "hnsw_halfvec_support"("internal"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_halfvec_support"("internal") TO "service_role";


--
-- Name: FUNCTION "hnsw_sparsevec_support"("internal"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnsw_sparsevec_support"("internal") TO "service_role";


--
-- Name: FUNCTION "hnswhandler"("internal"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hnswhandler"("internal") TO "service_role";


--
-- Name: FUNCTION "inner_product"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "inner_product"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "inner_product"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inner_product"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "is_active_user"("uid" "uuid"); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION "public"."is_active_user"("uid" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_active_user"("uid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_active_user"("uid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_active_user"("uid" "uuid") TO "service_role";


--
-- Name: FUNCTION "is_admin"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."is_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";


--
-- Name: FUNCTION "is_admin"("uid" "uuid"); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION "public"."is_admin"("uid" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_admin"("uid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"("uid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"("uid" "uuid") TO "service_role";


--
-- Name: FUNCTION "ivfflat_bit_support"("internal"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_bit_support"("internal") TO "service_role";


--
-- Name: FUNCTION "ivfflat_halfvec_support"("internal"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflat_halfvec_support"("internal") TO "service_role";


--
-- Name: FUNCTION "ivfflathandler"("internal"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ivfflathandler"("internal") TO "service_role";


--
-- Name: FUNCTION "jaccard_distance"(bit, bit); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "postgres";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "anon";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "authenticated";
GRANT ALL ON FUNCTION "public"."jaccard_distance"(bit, bit) TO "service_role";


--
-- Name: FUNCTION "l1_distance"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "l1_distance"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "l1_distance"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l1_distance"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "l2_distance"("public"."halfvec", "public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."halfvec", "public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "l2_distance"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "l2_distance"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_distance"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "l2_norm"("public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "l2_norm"("public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_norm"("public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "l2_normalize"("public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "l2_normalize"("public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "l2_normalize"("public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."l2_normalize"("public"."vector") TO "service_role";


--
-- Name: FUNCTION "match_documents"("query_embedding" "text", "filter" "jsonb", "match_count" integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."match_documents"("query_embedding" "text", "filter" "jsonb", "match_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."match_documents"("query_embedding" "text", "filter" "jsonb", "match_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."match_documents"("query_embedding" "text", "filter" "jsonb", "match_count" integer) TO "service_role";


--
-- Name: FUNCTION "search_projects_by_embedding"("query_embedding" "public"."vector", "match_threshold" double precision, "match_count" integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."search_projects_by_embedding"("query_embedding" "public"."vector", "match_threshold" double precision, "match_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."search_projects_by_embedding"("query_embedding" "public"."vector", "match_threshold" double precision, "match_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_projects_by_embedding"("query_embedding" "public"."vector", "match_threshold" double precision, "match_count" integer) TO "service_role";


--
-- Name: FUNCTION "set_updated_at"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";


--
-- Name: FUNCTION "sparsevec_cmp"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_cmp"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "sparsevec_eq"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_eq"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "sparsevec_ge"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ge"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "sparsevec_gt"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_gt"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_l2_squared_distance"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "sparsevec_le"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_le"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "sparsevec_lt"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_lt"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "sparsevec_ne"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_ne"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "anon";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sparsevec_negative_inner_product"("public"."sparsevec", "public"."sparsevec") TO "service_role";


--
-- Name: FUNCTION "subvector"("public"."halfvec", integer, integer); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."halfvec", integer, integer) TO "service_role";


--
-- Name: FUNCTION "subvector"("public"."vector", integer, integer); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "postgres";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "anon";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."subvector"("public"."vector", integer, integer) TO "service_role";


--
-- Name: FUNCTION "update_atualizado_em_column"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."update_atualizado_em_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_atualizado_em_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_atualizado_em_column"() TO "service_role";


--
-- Name: FUNCTION "update_updated_at_column"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";


--
-- Name: FUNCTION "user_has_area"("uid" "uuid", "area" "text"); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION "public"."user_has_area"("uid" "uuid", "area" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."user_has_area"("uid" "uuid", "area" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."user_has_area"("uid" "uuid", "area" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_has_area"("uid" "uuid", "area" "text") TO "service_role";


--
-- Name: FUNCTION "vector_accum"(double precision[], "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_accum"(double precision[], "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_add"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_add"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_avg"(double precision[]); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_avg"(double precision[]) TO "service_role";


--
-- Name: FUNCTION "vector_cmp"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_cmp"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_combine"(double precision[], double precision[]); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "anon";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_combine"(double precision[], double precision[]) TO "service_role";


--
-- Name: FUNCTION "vector_concat"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_concat"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_dims"("public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "vector_dims"("public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_dims"("public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_eq"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_eq"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_ge"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ge"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_gt"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_gt"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_l2_squared_distance"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_l2_squared_distance"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_le"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_le"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_lt"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_lt"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_mul"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_mul"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_ne"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_ne"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_negative_inner_product"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_negative_inner_product"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_norm"("public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_norm"("public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_spherical_distance"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_spherical_distance"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "vector_sub"("public"."vector", "public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vector_sub"("public"."vector", "public"."vector") TO "service_role";


--
-- Name: FUNCTION "_crypto_aead_det_decrypt"("message" "bytea", "additional" "bytea", "key_id" bigint, "context" "bytea", "nonce" "bytea"); Type: ACL; Schema: vault; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "vault"."_crypto_aead_det_decrypt"("message" "bytea", "additional" "bytea", "key_id" bigint, "context" "bytea", "nonce" "bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "vault"."_crypto_aead_det_decrypt"("message" "bytea", "additional" "bytea", "key_id" bigint, "context" "bytea", "nonce" "bytea") TO "service_role";


--
-- Name: FUNCTION "create_secret"("new_secret" "text", "new_name" "text", "new_description" "text", "new_key_id" "uuid"); Type: ACL; Schema: vault; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "vault"."create_secret"("new_secret" "text", "new_name" "text", "new_description" "text", "new_key_id" "uuid") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "vault"."create_secret"("new_secret" "text", "new_name" "text", "new_description" "text", "new_key_id" "uuid") TO "service_role";


--
-- Name: FUNCTION "update_secret"("secret_id" "uuid", "new_secret" "text", "new_name" "text", "new_description" "text", "new_key_id" "uuid"); Type: ACL; Schema: vault; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "vault"."update_secret"("secret_id" "uuid", "new_secret" "text", "new_name" "text", "new_description" "text", "new_key_id" "uuid") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "vault"."update_secret"("secret_id" "uuid", "new_secret" "text", "new_name" "text", "new_description" "text", "new_key_id" "uuid") TO "service_role";


--
-- Name: FUNCTION "avg"("public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "avg"("public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."avg"("public"."vector") TO "service_role";


--
-- Name: FUNCTION "sum"("public"."halfvec"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."halfvec") TO "service_role";


--
-- Name: FUNCTION "sum"("public"."vector"); Type: ACL; Schema: public; Owner: supabase_admin
--

GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "postgres";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "anon";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sum"("public"."vector") TO "service_role";


--
-- Name: TABLE "pg_stat_statements"; Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON TABLE "extensions"."pg_stat_statements" FROM "postgres";
-- GRANT ALL ON TABLE "extensions"."pg_stat_statements" TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON TABLE "extensions"."pg_stat_statements" TO "dashboard_user";


--
-- Name: TABLE "pg_stat_statements_info"; Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON TABLE "extensions"."pg_stat_statements_info" FROM "postgres";
-- GRANT ALL ON TABLE "extensions"."pg_stat_statements_info" TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON TABLE "extensions"."pg_stat_statements_info" TO "dashboard_user";


--
-- Name: TABLE "broker_availability"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."broker_availability" TO "anon";
GRANT ALL ON TABLE "public"."broker_availability" TO "authenticated";
GRANT ALL ON TABLE "public"."broker_availability" TO "service_role";


--
-- Name: TABLE "brokers"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."brokers" TO "anon";
GRANT ALL ON TABLE "public"."brokers" TO "authenticated";
GRANT ALL ON TABLE "public"."brokers" TO "service_role";


--
-- Name: TABLE "hallucination_alerts"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."hallucination_alerts" TO "anon";
GRANT ALL ON TABLE "public"."hallucination_alerts" TO "authenticated";
GRANT ALL ON TABLE "public"."hallucination_alerts" TO "service_role";


--
-- Name: TABLE "improvement_suggestions"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."improvement_suggestions" TO "anon";
GRANT ALL ON TABLE "public"."improvement_suggestions" TO "authenticated";
GRANT ALL ON TABLE "public"."improvement_suggestions" TO "service_role";


--
-- Name: TABLE "leads"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."leads" TO "anon";
GRANT ALL ON TABLE "public"."leads" TO "authenticated";
GRANT ALL ON TABLE "public"."leads" TO "service_role";


--
-- Name: TABLE "logs"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."logs" TO "anon";
GRANT ALL ON TABLE "public"."logs" TO "authenticated";
GRANT ALL ON TABLE "public"."logs" TO "service_role";


--
-- Name: TABLE "n8n_assistant_dash_history"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."n8n_assistant_dash_history" TO "anon";
GRANT ALL ON TABLE "public"."n8n_assistant_dash_history" TO "authenticated";
GRANT ALL ON TABLE "public"."n8n_assistant_dash_history" TO "service_role";


--
-- Name: SEQUENCE "n8n_assistant_dash_history_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE "public"."n8n_assistant_dash_history_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."n8n_assistant_dash_history_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."n8n_assistant_dash_history_id_seq" TO "service_role";


--
-- Name: TABLE "n8n_history"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."n8n_history" TO "anon";
GRANT ALL ON TABLE "public"."n8n_history" TO "authenticated";
GRANT ALL ON TABLE "public"."n8n_history" TO "service_role";


--
-- Name: SEQUENCE "n8n_history_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE "public"."n8n_history_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."n8n_history_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."n8n_history_id_seq" TO "service_role";


--
-- Name: TABLE "project_images"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."project_images" TO "anon";
GRANT ALL ON TABLE "public"."project_images" TO "authenticated";
GRANT ALL ON TABLE "public"."project_images" TO "service_role";


--
-- Name: TABLE "projects"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."projects" TO "anon";
GRANT ALL ON TABLE "public"."projects" TO "authenticated";
GRANT ALL ON TABLE "public"."projects" TO "service_role";


--
-- Name: TABLE "prompt"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."prompt" TO "anon";
GRANT ALL ON TABLE "public"."prompt" TO "authenticated";
GRANT ALL ON TABLE "public"."prompt" TO "service_role";


--
-- Name: TABLE "users"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";


--
-- Name: TABLE "secrets"; Type: ACL; Schema: vault; Owner: supabase_admin
--

-- GRANT SELECT,REFERENCES,DELETE,TRUNCATE ON TABLE "vault"."secrets" TO "postgres" WITH GRANT OPTION;
-- GRANT SELECT,DELETE ON TABLE "vault"."secrets" TO "service_role";


--
-- Name: TABLE "decrypted_secrets"; Type: ACL; Schema: vault; Owner: supabase_admin
--

-- GRANT SELECT,REFERENCES,DELETE,TRUNCATE ON TABLE "vault"."decrypted_secrets" TO "postgres" WITH GRANT OPTION;
-- GRANT SELECT,DELETE ON TABLE "vault"."decrypted_secrets" TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: supabase_admin
--

-- CREATE EVENT TRIGGER "issue_graphql_placeholder" ON "sql_drop"
--          WHEN TAG IN ('DROP EXTENSION')
--    EXECUTE FUNCTION "extensions"."set_graphql_placeholder"();


-- ALTER EVENT TRIGGER "issue_graphql_placeholder" OWNER TO "supabase_admin";

--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: supabase_admin
--

-- CREATE EVENT TRIGGER "issue_pg_cron_access" ON "ddl_command_end"
--          WHEN TAG IN ('CREATE EXTENSION')
--    EXECUTE FUNCTION "extensions"."grant_pg_cron_access"();


-- ALTER EVENT TRIGGER "issue_pg_cron_access" OWNER TO "supabase_admin";

--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: supabase_admin
--

-- CREATE EVENT TRIGGER "issue_pg_graphql_access" ON "ddl_command_end"
--          WHEN TAG IN ('CREATE FUNCTION')
--    EXECUTE FUNCTION "extensions"."grant_pg_graphql_access"();


-- ALTER EVENT TRIGGER "issue_pg_graphql_access" OWNER TO "supabase_admin";

--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: supabase_admin
--

-- CREATE EVENT TRIGGER "issue_pg_net_access" ON "ddl_command_end"
--          WHEN TAG IN ('CREATE EXTENSION')
--    EXECUTE FUNCTION "extensions"."grant_pg_net_access"();


-- ALTER EVENT TRIGGER "issue_pg_net_access" OWNER TO "supabase_admin";

--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: supabase_admin
--

-- CREATE EVENT TRIGGER "pgrst_ddl_watch" ON "ddl_command_end"
--    EXECUTE FUNCTION "extensions"."pgrst_ddl_watch"();


-- ALTER EVENT TRIGGER "pgrst_ddl_watch" OWNER TO "supabase_admin";

--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: supabase_admin
--

-- CREATE EVENT TRIGGER "pgrst_drop_watch" ON "sql_drop"
--    EXECUTE FUNCTION "extensions"."pgrst_drop_watch"();


-- ALTER EVENT TRIGGER "pgrst_drop_watch" OWNER TO "supabase_admin";

--
-- PostgreSQL database dump complete
--

-- \unrestrict WENfpXik1SoOhrvJD3gkcPJazUvXfh5xIdGVbi892Grk38ch4VUjqagf7XGv35n



-- ============================================================================
-- storage.objects — RLS policies (não capturadas pelo dump default)
-- ============================================================================

ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;

-- bucket "imagens-projetos": leitura pública + write gated por área 'projects'
DROP POLICY IF EXISTS "imagens_projetos_select_public" ON "storage"."objects";
CREATE POLICY "imagens_projetos_select_public" ON "storage"."objects"
  FOR SELECT TO "authenticated", "anon"
  USING ("bucket_id" = 'imagens-projetos');

DROP POLICY IF EXISTS "imagens_projetos_insert_projects" ON "storage"."objects";
CREATE POLICY "imagens_projetos_insert_projects" ON "storage"."objects"
  FOR INSERT TO "authenticated"
  WITH CHECK ("bucket_id" = 'imagens-projetos'
    AND "public"."user_has_area"("auth"."uid"(), 'projects'));

DROP POLICY IF EXISTS "imagens_projetos_update_projects" ON "storage"."objects";
CREATE POLICY "imagens_projetos_update_projects" ON "storage"."objects"
  FOR UPDATE TO "authenticated"
  USING ("bucket_id" = 'imagens-projetos'
    AND "public"."user_has_area"("auth"."uid"(), 'projects'))
  WITH CHECK ("bucket_id" = 'imagens-projetos'
    AND "public"."user_has_area"("auth"."uid"(), 'projects'));

DROP POLICY IF EXISTS "imagens_projetos_delete_projects" ON "storage"."objects";
CREATE POLICY "imagens_projetos_delete_projects" ON "storage"."objects"
  FOR DELETE TO "authenticated"
  USING ("bucket_id" = 'imagens-projetos'
    AND "public"."user_has_area"("auth"."uid"(), 'projects'));

-- bucket "imagens-projetos": policies "frouxas" duplicadas (legado do painel).
-- Mantidas pra refletir o estado atual de produção. TODO: consolidar.
DROP POLICY IF EXISTS "Allow public read from imagens-projetos" ON "storage"."objects";
CREATE POLICY "Allow public read from imagens-projetos" ON "storage"."objects"
  FOR SELECT USING ("bucket_id" = 'imagens-projetos');

DROP POLICY IF EXISTS "Allow authenticated uploads to imagens-projetos" ON "storage"."objects";
CREATE POLICY "Allow authenticated uploads to imagens-projetos" ON "storage"."objects"
  FOR INSERT TO "authenticated"
  WITH CHECK ("bucket_id" = 'imagens-projetos');

DROP POLICY IF EXISTS "Allow authenticated updates to imagens-projetos" ON "storage"."objects";
CREATE POLICY "Allow authenticated updates to imagens-projetos" ON "storage"."objects"
  FOR UPDATE TO "authenticated"
  USING ("bucket_id" = 'imagens-projetos');

DROP POLICY IF EXISTS "Allow authenticated deletes from imagens-projetos" ON "storage"."objects";
CREATE POLICY "Allow authenticated deletes from imagens-projetos" ON "storage"."objects"
  FOR DELETE TO "authenticated"
  USING ("bucket_id" = 'imagens-projetos');

-- bucket "projetos": frouxas, qualquer authenticated read/write
DROP POLICY IF EXISTS "Public read access for projetos bucket" ON "storage"."objects";
CREATE POLICY "Public read access for projetos bucket" ON "storage"."objects"
  FOR SELECT USING ("bucket_id" = 'projetos');

DROP POLICY IF EXISTS "Authenticated users can upload to projetos bucket" ON "storage"."objects";
CREATE POLICY "Authenticated users can upload to projetos bucket" ON "storage"."objects"
  FOR INSERT TO "authenticated"
  WITH CHECK ("bucket_id" = 'projetos');

DROP POLICY IF EXISTS "Authenticated users can update projetos bucket files" ON "storage"."objects";
CREATE POLICY "Authenticated users can update projetos bucket files" ON "storage"."objects"
  FOR UPDATE TO "authenticated"
  USING ("bucket_id" = 'projetos')
  WITH CHECK ("bucket_id" = 'projetos');

DROP POLICY IF EXISTS "Authenticated users can delete from projetos bucket" ON "storage"."objects";
CREATE POLICY "Authenticated users can delete from projetos bucket" ON "storage"."objects"
  FOR DELETE TO "authenticated"
  USING ("bucket_id" = 'projetos');

-- ============================================================================
-- auth.users — triggers de provisionamento e cleanup
-- (não capturados pelo dump default por estarem em schema auth)
-- ============================================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

DROP TRIGGER IF EXISTS on_auth_user_deleted_clear_chat ON auth.users;
CREATE TRIGGER on_auth_user_deleted_clear_chat
  BEFORE DELETE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.delete_chat_history_on_user_delete();
