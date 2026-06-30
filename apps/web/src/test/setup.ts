import "@testing-library/jest-dom/vitest"

// Defaults de ambiente para os testes não dependerem de um `.env` real
// (que é gitignored e ausente no CI). Só preenche se não vier do ambiente.
const testEnv = import.meta.env as Record<string, string | undefined>
testEnv.VITE_SUPABASE_URL ??= "http://localhost:54321"
testEnv.VITE_SUPABASE_ANON_KEY ??= "test-anon-key"
