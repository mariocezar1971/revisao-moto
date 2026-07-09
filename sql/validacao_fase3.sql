-- =====================================================================
-- REVISAO-MOTO :: Validacao da Fase 3
-- =====================================================================
-- Cole no SQL Editor do Supabase apos 004_fase3_execucao.sql
-- =====================================================================

DO $$
DECLARE
    v_ok    BOOLEAN;
    v_falhas INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '======================================================';
    RAISE NOTICE '  VALIDACAO FASE 3 - Execucao do Checklist';
    RAISE NOTICE '======================================================';

    -- Funcao sugerir_revisao
    SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='sugerir_revisao') INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [PASS] funcao sugerir_revisao criada';
    ELSE RAISE NOTICE '  [FAIL] funcao sugerir_revisao ausente'; v_falhas := v_falhas + 1;
    END IF;

    -- Funcao pode_finalizar_inspecao
    SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='pode_finalizar_inspecao') INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [PASS] funcao pode_finalizar_inspecao criada';
    ELSE RAISE NOTICE '  [FAIL] funcao pode_finalizar_inspecao ausente'; v_falhas := v_falhas + 1;
    END IF;

    -- View vw_inspecao_progresso
    SELECT EXISTS(SELECT 1 FROM information_schema.views
                  WHERE table_schema='public' AND table_name='vw_inspecao_progresso') INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [PASS] view vw_inspecao_progresso criada';
    ELSE RAISE NOTICE '  [FAIL] view vw_inspecao_progresso ausente'; v_falhas := v_falhas + 1;
    END IF;

    -- View vw_inspecoes_lista
    SELECT EXISTS(SELECT 1 FROM information_schema.views
                  WHERE table_schema='public' AND table_name='vw_inspecoes_lista') INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [PASS] view vw_inspecoes_lista criada';
    ELSE RAISE NOTICE '  [FAIL] view vw_inspecoes_lista ausente'; v_falhas := v_falhas + 1;
    END IF;

    -- Trigger set_km_moto_ao_finalizar
    SELECT EXISTS(SELECT 1 FROM information_schema.triggers
                  WHERE trigger_name='set_km_moto_ao_finalizar') INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [PASS] trigger set_km_moto_ao_finalizar criado';
    ELSE RAISE NOTICE '  [FAIL] trigger set_km_moto_ao_finalizar ausente'; v_falhas := v_falhas + 1;
    END IF;

    -- Indices adicionais
    IF EXISTS(SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_inspecoes_data_fim') THEN
        RAISE NOTICE '  [PASS] indice idx_inspecoes_data_fim criado';
    ELSE
        RAISE NOTICE '  [FAIL] indice idx_inspecoes_data_fim ausente';
        v_falhas := v_falhas + 1;
    END IF;

    IF EXISTS(SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_inspecoes_itens_item') THEN
        RAISE NOTICE '  [PASS] indice idx_inspecoes_itens_item criado';
    ELSE
        RAISE NOTICE '  [FAIL] indice idx_inspecoes_itens_item ausente';
        v_falhas := v_falhas + 1;
    END IF;

    RAISE NOTICE '';
    IF v_falhas = 0 THEN
        RAISE NOTICE '  RESULTADO: TODAS AS VALIDACOES PASSARAM (OK)';
    ELSE
        RAISE NOTICE '  RESULTADO: % FALHA(S)', v_falhas;
    END IF;
    RAISE NOTICE '======================================================';
END $$;
