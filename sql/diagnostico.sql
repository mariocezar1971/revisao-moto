-- =====================================================================
-- REVISAO-MOTO :: Diagnostico rapido
-- =====================================================================
-- Cole no SQL Editor do Supabase para identificar o estado atual.
-- =====================================================================

-- 1. As tabelas existem?
SELECT
    'modelos'         AS tabela,
    EXISTS(SELECT 1 FROM information_schema.tables
           WHERE table_schema='public' AND table_name='modelos') AS existe
UNION ALL SELECT 'revisoes',
    EXISTS(SELECT 1 FROM information_schema.tables
           WHERE table_schema='public' AND table_name='revisoes')
UNION ALL SELECT 'itens_checklist',
    EXISTS(SELECT 1 FROM information_schema.tables
           WHERE table_schema='public' AND table_name='itens_checklist');

-- 2. Quantas linhas em cada uma? (este e o teste critico)
SELECT 'modelos'         AS tabela, COUNT(*) AS linhas FROM modelos
UNION ALL
SELECT 'revisoes',         COUNT(*) FROM revisoes
UNION ALL
SELECT 'itens_checklist',  COUNT(*) FROM itens_checklist;
-- Esperado: 10, 70, 1300

-- 3. Quais modelos estao cadastrados?
SELECT nome, plataforma, cilindrada FROM modelos ORDER BY plataforma, cilindrada DESC;

-- 4. As policies RLS estao no lugar?
SELECT tablename, policyname, roles, cmd
FROM pg_policies
WHERE schemaname='public'
ORDER BY tablename;
