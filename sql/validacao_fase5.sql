-- =====================================================================
-- REVISAO-MOTO :: Validacao da Fase 5
-- =====================================================================
DO $$
DECLARE
    v_ok BOOLEAN;
    v_falhas INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '======================================================';
    RAISE NOTICE '  VALIDACAO FASE 5 - Historico e Relatorios';
    RAISE NOTICE '======================================================';

    -- Funcoes
    FOR v_ok IN
        SELECT proname IN ('status_revisao_moto', 'estatisticas_gerais')
        FROM pg_proc WHERE proname IN ('status_revisao_moto', 'estatisticas_gerais')
    LOOP END LOOP;

    IF (SELECT COUNT(*) FROM pg_proc WHERE proname='status_revisao_moto') > 0 THEN
        RAISE NOTICE '  [PASS] funcao status_revisao_moto criada';
    ELSE RAISE NOTICE '  [FAIL] status_revisao_moto ausente'; v_falhas := v_falhas + 1;
    END IF;

    IF (SELECT COUNT(*) FROM pg_proc WHERE proname='estatisticas_gerais') > 0 THEN
        RAISE NOTICE '  [PASS] funcao estatisticas_gerais criada';
    ELSE RAISE NOTICE '  [FAIL] estatisticas_gerais ausente'; v_falhas := v_falhas + 1;
    END IF;

    -- Views
    FOR v_ok IN
        SELECT TRUE FROM information_schema.views
        WHERE table_schema='public' AND table_name IN
              ('vw_motos_com_status_revisao','vw_timeline_inspecoes',
               'vw_inspecoes_por_mecanico_mes','vw_itens_mais_reprovados')
    LOOP END LOOP;

    IF (SELECT COUNT(*) FROM information_schema.views
        WHERE table_schema='public'
          AND table_name IN ('vw_motos_com_status_revisao','vw_timeline_inspecoes',
                             'vw_inspecoes_por_mecanico_mes','vw_itens_mais_reprovados')) = 4 THEN
        RAISE NOTICE '  [PASS] 4 views de historico criadas';
    ELSE
        RAISE NOTICE '  [FAIL] views incompletas: encontrei %',
              (SELECT COUNT(*) FROM information_schema.views
               WHERE table_schema='public'
                 AND table_name IN ('vw_motos_com_status_revisao','vw_timeline_inspecoes',
                                    'vw_inspecoes_por_mecanico_mes','vw_itens_mais_reprovados'));
        v_falhas := v_falhas + 1;
    END IF;

    -- Indices
    IF EXISTS(SELECT 1 FROM pg_indexes WHERE indexname='idx_inspecoes_mecanico_id') THEN
        RAISE NOTICE '  [PASS] indice idx_inspecoes_mecanico_id criado';
    ELSE
        RAISE NOTICE '  [FAIL] idx_inspecoes_mecanico_id ausente'; v_falhas := v_falhas + 1;
    END IF;

    IF EXISTS(SELECT 1 FROM pg_indexes WHERE indexname='idx_inspecoes_data_inicio') THEN
        RAISE NOTICE '  [PASS] indice idx_inspecoes_data_inicio criado';
    ELSE
        RAISE NOTICE '  [FAIL] idx_inspecoes_data_inicio ausente'; v_falhas := v_falhas + 1;
    END IF;

    RAISE NOTICE '';
    IF v_falhas = 0 THEN
        RAISE NOTICE '  RESULTADO: TODAS AS VALIDACOES PASSARAM (OK)';
    ELSE
        RAISE NOTICE '  RESULTADO: % FALHA(S)', v_falhas;
    END IF;
    RAISE NOTICE '======================================================';
END $$;
