// src/config/env.ts
import { z } from "zod";
import "dotenv/config";

const envSchema = z.object({
  VITE_SUPABASE_URL: z.url(),
  VITE_SUPABASE_ANON_KEY: z.string().min(1),
});

export const env = envSchema.parse(process.env);