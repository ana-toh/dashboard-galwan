import { createClient } from "@supabase/supabase-js"
import { z } from "zod"

const envSchema = z.object({
  VITE_SUPABASE_URL: z.url(),
  VITE_SUPABASE_ANON_KEY: z.string().min(1),
  VITE_SUPABASE_FUNCTIONS_URL: z.url().optional(),
})

const env = envSchema.parse({
  VITE_SUPABASE_URL: import.meta.env.VITE_SUPABASE_URL,
  VITE_SUPABASE_ANON_KEY: import.meta.env.VITE_SUPABASE_ANON_KEY,
  VITE_SUPABASE_FUNCTIONS_URL: import.meta.env.VITE_SUPABASE_FUNCTIONS_URL || undefined,
})

export const supabaseEnv = env

export const supabase = createClient(env.VITE_SUPABASE_URL, env.VITE_SUPABASE_ANON_KEY)
