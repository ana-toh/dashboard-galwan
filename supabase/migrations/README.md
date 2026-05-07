# Migrations

Arquivos `*_baseline.sql` são placeholders vazios criados em 2026-05-07 para
sincronizar o histórico local com o que já estava aplicado no banco remoto
(migrations originalmente rodadas via SQL Editor / CLI antiga). Não rode-os —
estão registrados como `applied` na tabela `supabase_migrations.schema_migrations`.

A partir de 2026-05-07, novas migrations seguem o fluxo normal:

```
supabase migration new <nome>
# edite o SQL gerado
supabase db push
```
