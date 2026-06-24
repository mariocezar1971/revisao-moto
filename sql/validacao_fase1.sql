-- =====================================================================
-- REVISAO-MOTO :: Validacao da Fase 1
-- =====================================================================
-- Cole este script no SQL Editor do Supabase e clique em Run.
-- Output: mensagens PASS/FAIL para cada validacao.
-- Execute APOS rodar 001_schema.sql e 002_seed_royal_enfield.sql.
-- =====================================================================

DO $$
DECLARE
    v_modelos        INT;
    v_revisoes       INT;
    v_itens          INT;
    v_views          INT;
    v_triggers       INT;
    v_policies       INT;
    v_indices        INT;
    v_itens_500      INT;
    v_itens_5k       INT;
    v_itens_10k      INT;
    v_itens_15k      INT;
    v_itens_20k      INT;
    v_itens_25k      INT;
    v_itens_30k      INT;
    v_falhas         INT := 0;
    v_modelos_lista  TEXT;
BEGIN
    -- =============================================================
    -- BLOCO 1: TABELAS DO CATALOGO
    -- =============================================================
    RAISE NOTICE '';
    RAISE NOTICE '======================================================';
    RAISE NOTICE '  VALIDACAO FASE 1 - CATALOGO NO BANCO';
    RAISE NOTICE '======================================================';
    RAISE NOTICE '';
    RAISE NOTICE '-- [1] Contagens basicas --';

    SELECT COUNT(*) INTO v_modelos FROM modelos;
    IF v_modelos = 10 THEN
        RAISE NOTICE '  [PASS] modelos          = %', v_modelos;
    ELSE
        RAISE NOTICE '  [FAIL] modelos          = % (esperado: 10)', v_modelos;
        v_falhas := v_falhas + 1;
    END IF;

    SELECT COUNT(*) INTO v_revisoes FROM revisoes;
    IF v_revisoes = 70 THEN
        RAISE NOTICE '  [PASS] revisoes         = %', v_revisoes;
    ELSE
        RAISE NOTICE '  [FAIL] revisoes         = % (esperado: 70)', v_revisoes;
        v_falhas := v_falhas + 1;
    END IF;

    SELECT COUNT(*) INTO v_itens FROM itens_checklist;
    IF v_itens = 1300 THEN
        RAISE NOTICE '  [PASS] itens_checklist  = %', v_itens;
    ELSE
        RAISE NOTICE '  [FAIL] itens_checklist  = % (esperado: 1300)', v_itens;
        v_falhas := v_falhas + 1;
    END IF;

    -- =============================================================
    -- BLOCO 2: MODELOS ESPERADOS
    -- =============================================================
    RAISE NOTICE '';
    RAISE NOTICE '-- [2] Modelos Royal Enfield --';

    SELECT string_agg(nome, ', ' ORDER BY nome) INTO v_modelos_lista FROM modelos;
    RAISE NOTICE '  Cadastrados: %', v_modelos_lista;

    FOR v_modelos_lista IN
        SELECT unnest(ARRAY[
            'Shotgun 650', 'Super Meteor 650', 'Interceptor 650',
            'Continental GT 650', 'Classic 650', 'Bear 650',
            'Hunter 350', 'Classic 350', 'Meteor 350', 'Himalayan 450'
        ])
    LOOP
        IF EXISTS(SELECT 1 FROM modelos WHERE nome = v_modelos_lista) THEN
            RAISE NOTICE '  [PASS] %', v_modelos_lista;
        ELSE
            RAISE NOTICE '  [FAIL] AUSENTE: %', v_modelos_lista;
            v_falhas := v_falhas + 1;
        END IF;
    END LOOP;

    -- =============================================================
    -- BLOCO 3: DISTRIBUICAO DE ITENS POR KM (modelo Shotgun 650)
    -- =============================================================
    RAISE NOTICE '';
    RAISE NOTICE '-- [3] Itens por revisao (Shotgun 650) --';

    SELECT COUNT(i.id) INTO v_itens_500 FROM itens_checklist i
        JOIN revisoes r ON r.id = i.revisao_id
        JOIN modelos m ON m.id = r.modelo_id
        WHERE m.nome='Shotgun 650' AND r.km = 500;
    IF v_itens_500 = 14 THEN
        RAISE NOTICE '  [PASS]    500 km: % itens', v_itens_500;
    ELSE
        RAISE NOTICE '  [FAIL]    500 km: % itens (esperado: 14)', v_itens_500;
        v_falhas := v_falhas + 1;
    END IF;

    SELECT COUNT(i.id) INTO v_itens_5k FROM itens_checklist i
        JOIN revisoes r ON r.id = i.revisao_id
        JOIN modelos m ON m.id = r.modelo_id
        WHERE m.nome='Shotgun 650' AND r.km = 5000;
    IF v_itens_5k = 16 THEN
        RAISE NOTICE '  [PASS]   5000 km: % itens', v_itens_5k;
    ELSE
        RAISE NOTICE '  [FAIL]   5000 km: % itens (esperado: 16)', v_itens_5k;
        v_falhas := v_falhas + 1;
    END IF;

    SELECT COUNT(i.id) INTO v_itens_10k FROM itens_checklist i
        JOIN revisoes r ON r.id = i.revisao_id
        JOIN modelos m ON m.id = r.modelo_id
        WHERE m.nome='Shotgun 650' AND r.km = 10000;
    IF v_itens_10k = 22 THEN
        RAISE NOTICE '  [PASS]  10000 km: % itens', v_itens_10k;
    ELSE
        RAISE NOTICE '  [FAIL]  10000 km: % itens (esperado: 22)', v_itens_10k;
        v_falhas := v_falhas + 1;
    END IF;

    SELECT COUNT(i.id) INTO v_itens_15k FROM itens_checklist i
        JOIN revisoes r ON r.id = i.revisao_id
        JOIN modelos m ON m.id = r.modelo_id
        WHERE m.nome='Shotgun 650' AND r.km = 15000;
    IF v_itens_15k = 16 THEN
        RAISE NOTICE '  [PASS]  15000 km: % itens', v_itens_15k;
    ELSE
        RAISE NOTICE '  [FAIL]  15000 km: % itens (esperado: 16)', v_itens_15k;
        v_falhas := v_falhas + 1;
    END IF;

    SELECT COUNT(i.id) INTO v_itens_20k FROM itens_checklist i
        JOIN revisoes r ON r.id = i.revisao_id
        JOIN modelos m ON m.id = r.modelo_id
        WHERE m.nome='Shotgun 650' AND r.km = 20000;
    IF v_itens_20k = 24 THEN
        RAISE NOTICE '  [PASS]  20000 km: % itens', v_itens_20k;
    ELSE
        RAISE NOTICE '  [FAIL]  20000 km: % itens (esperado: 24)', v_itens_20k;
        v_falhas := v_falhas + 1;
    END IF;

    SELECT COUNT(i.id) INTO v_itens_25k FROM itens_checklist i
        JOIN revisoes r ON r.id = i.revisao_id
        JOIN modelos m ON m.id = r.modelo_id
        WHERE m.nome='Shotgun 650' AND r.km = 25000;
    IF v_itens_25k = 16 THEN
        RAISE NOTICE '  [PASS]  25000 km: % itens', v_itens_25k;
    ELSE
        RAISE NOTICE '  [FAIL]  25000 km: % itens (esperado: 16)', v_itens_25k;
        v_falhas := v_falhas + 1;
    END IF;

    SELECT COUNT(i.id) INTO v_itens_30k FROM itens_checklist i
        JOIN revisoes r ON r.id = i.revisao_id
        JOIN modelos m ON m.id = r.modelo_id
        WHERE m.nome='Shotgun 650' AND r.km = 30000;
    IF v_itens_30k = 22 THEN
        RAISE NOTICE '  [PASS]  30000 km: % itens', v_itens_30k;
    ELSE
        RAISE NOTICE '  [FAIL]  30000 km: % itens (esperado: 22)', v_itens_30k;
        v_falhas := v_falhas + 1;
    END IF;

    -- =============================================================
    -- BLOCO 4: ESTRUTURAS DO SCHEMA
    -- =============================================================
    RAISE NOTICE '';
    RAISE NOTICE '-- [4] Estruturas do banco --';

    SELECT COUNT(*) INTO v_views FROM information_schema.views
        WHERE table_schema='public'
        AND table_name IN ('vw_checklist_completo', 'vw_motos_status');
    IF v_views = 2 THEN
        RAISE NOTICE '  [PASS] views (vw_checklist_completo, vw_motos_status) criadas';
    ELSE
        RAISE NOTICE '  [FAIL] views esperadas = 2, encontradas = %', v_views;
        v_falhas := v_falhas + 1;
    END IF;

    SELECT COUNT(*) INTO v_triggers FROM information_schema.triggers
        WHERE event_object_schema='public';
    IF v_triggers >= 1 THEN
        RAISE NOTICE '  [PASS] triggers ativos = %', v_triggers;
    ELSE
        RAISE NOTICE '  [FAIL] nenhum trigger ativo (esperado: pelo menos 1)';
        v_falhas := v_falhas + 1;
    END IF;

    SELECT COUNT(*) INTO v_policies FROM pg_policies WHERE schemaname='public';
    IF v_policies >= 6 THEN
        RAISE NOTICE '  [PASS] RLS policies = %', v_policies;
    ELSE
        RAISE NOTICE '  [FAIL] RLS policies = % (esperado: >= 6)', v_policies;
        v_falhas := v_falhas + 1;
    END IF;

    SELECT COUNT(*) INTO v_indices FROM pg_indexes
        WHERE schemaname='public' AND indexname LIKE 'idx_%';
    IF v_indices >= 8 THEN
        RAISE NOTICE '  [PASS] indices de performance = %', v_indices;
    ELSE
        RAISE NOTICE '  [FAIL] indices = % (esperado: >= 8)', v_indices;
        v_falhas := v_falhas + 1;
    END IF;

    -- =============================================================
    -- RESUMO
    -- =============================================================
    RAISE NOTICE '';
    RAISE NOTICE '======================================================';
    IF v_falhas = 0 THEN
        RAISE NOTICE '  RESULTADO: TODAS AS VALIDACOES PASSARAM (OK)';
        RAISE NOTICE '  Catalogo Fase 1 esta corretamente configurado!';
    ELSE
        RAISE NOTICE '  RESULTADO: % FALHA(S) ENCONTRADA(S)', v_falhas;
        RAISE NOTICE '  Verifique os logs acima para detalhes.';
    END IF;
    RAISE NOTICE '======================================================';
    RAISE NOTICE '';
END $$;

-- =====================================================================
-- NOTA: Storage bucket e usuarios sao validados separadamente
-- pelo script tests/test_fase1.py (que acessa as APIs REST/Admin).
-- =====================================================================
