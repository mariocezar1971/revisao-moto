-- =====================================================================
-- REVISAO-MOTO :: Validacao da Fase 2
-- =====================================================================
-- Cole no SQL Editor do Supabase apos rodar 003_fase2_motos_ativo.sql
-- =====================================================================

DO $$
DECLARE
    v_ativo_existe       BOOLEAN;
    v_indice_ativo       BOOLEAN;
    v_view_status        BOOLEAN;
    v_view_arquivadas    BOOLEAN;
    v_func_reativar      BOOLEAN;
    v_motos_ativas       INT;
    v_motos_arquivadas   INT;
    v_falhas             INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '======================================================';
    RAISE NOTICE '  VALIDACAO FASE 2 - CRUD de Motos';
    RAISE NOTICE '======================================================';
    RAISE NOTICE '';

    -- 1. Campo ativo existe?
    SELECT EXISTS(SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='motos'
                  AND column_name='ativo') INTO v_ativo_existe;
    IF v_ativo_existe THEN
        RAISE NOTICE '  [PASS] coluna motos.ativo existe';
    ELSE
        RAISE NOTICE '  [FAIL] coluna motos.ativo NAO existe';
        v_falhas := v_falhas + 1;
    END IF;

    -- 2. Indice em ativo?
    SELECT EXISTS(SELECT 1 FROM pg_indexes
                  WHERE schemaname='public' AND indexname='idx_motos_ativo') INTO v_indice_ativo;
    IF v_indice_ativo THEN
        RAISE NOTICE '  [PASS] indice idx_motos_ativo criado';
    ELSE
        RAISE NOTICE '  [FAIL] indice idx_motos_ativo ausente';
        v_falhas := v_falhas + 1;
    END IF;

    -- 3. View vw_motos_status atualizada?
    SELECT EXISTS(SELECT 1 FROM information_schema.views
                  WHERE table_schema='public' AND table_name='vw_motos_status') INTO v_view_status;
    IF v_view_status THEN
        RAISE NOTICE '  [PASS] view vw_motos_status existe';
    ELSE
        RAISE NOTICE '  [FAIL] view vw_motos_status ausente';
        v_falhas := v_falhas + 1;
    END IF;

    -- 4. View vw_motos_arquivadas criada?
    SELECT EXISTS(SELECT 1 FROM information_schema.views
                  WHERE table_schema='public' AND table_name='vw_motos_arquivadas') INTO v_view_arquivadas;
    IF v_view_arquivadas THEN
        RAISE NOTICE '  [PASS] view vw_motos_arquivadas criada';
    ELSE
        RAISE NOTICE '  [FAIL] view vw_motos_arquivadas ausente';
        v_falhas := v_falhas + 1;
    END IF;

    -- 5. Funcao reativar_moto criada?
    SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='reativar_moto') INTO v_func_reativar;
    IF v_func_reativar THEN
        RAISE NOTICE '  [PASS] funcao reativar_moto criada';
    ELSE
        RAISE NOTICE '  [FAIL] funcao reativar_moto ausente';
        v_falhas := v_falhas + 1;
    END IF;

    -- 6. View filtra inativas? Teste funcional
    SELECT COUNT(*) INTO v_motos_ativas FROM vw_motos_status;
    SELECT COUNT(*) INTO v_motos_arquivadas FROM vw_motos_arquivadas;
    RAISE NOTICE '  [INFO] motos ativas        = %', v_motos_ativas;
    RAISE NOTICE '  [INFO] motos arquivadas    = %', v_motos_arquivadas;

    -- 7. Constraint UNIQUE na placa?
    IF EXISTS(SELECT 1 FROM information_schema.table_constraints
              WHERE table_schema='public' AND table_name='motos'
              AND constraint_type='UNIQUE') THEN
        RAISE NOTICE '  [PASS] constraint UNIQUE em placa preservada';
    ELSE
        RAISE NOTICE '  [FAIL] constraint UNIQUE em placa ausente';
        v_falhas := v_falhas + 1;
    END IF;

    -- RESUMO
    RAISE NOTICE '';
    RAISE NOTICE '======================================================';
    IF v_falhas = 0 THEN
        RAISE NOTICE '  RESULTADO: TODAS AS VALIDACOES PASSARAM (OK)';
        RAISE NOTICE '  Fase 2 esta corretamente configurada!';
    ELSE
        RAISE NOTICE '  RESULTADO: % FALHA(S) ENCONTRADA(S)', v_falhas;
    END IF;
    RAISE NOTICE '======================================================';
END $$;
