-- =====================================================================
-- REVISAO-MOTO :: Validacao da Fase 4
-- =====================================================================
DO $$
DECLARE
    v_ok BOOLEAN;
    v_falhas INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '======================================================';
    RAISE NOTICE '  VALIDACAO FASE 4 - Assinaturas e PDF';
    RAISE NOTICE '======================================================';

    -- View vw_inspecoes_com_pdf
    SELECT EXISTS(SELECT 1 FROM information_schema.views
                  WHERE table_schema='public' AND table_name='vw_inspecoes_com_pdf') INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [PASS] view vw_inspecoes_com_pdf criada';
    ELSE RAISE NOTICE '  [FAIL] view vw_inspecoes_com_pdf ausente'; v_falhas := v_falhas + 1;
    END IF;

    -- Funcao assinaturas_completas
    SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='assinaturas_completas') INTO v_ok;
    IF v_ok THEN RAISE NOTICE '  [PASS] funcao assinaturas_completas criada';
    ELSE RAISE NOTICE '  [FAIL] funcao assinaturas_completas ausente'; v_falhas := v_falhas + 1;
    END IF;

    -- Indice pdf_url
    IF EXISTS(SELECT 1 FROM pg_indexes WHERE indexname='idx_inspecoes_pdf_url') THEN
        RAISE NOTICE '  [PASS] indice idx_inspecoes_pdf_url criado';
    ELSE
        RAISE NOTICE '  [FAIL] indice idx_inspecoes_pdf_url ausente'; v_falhas := v_falhas + 1;
    END IF;

    -- Campos obrigatorios na tabela inspecoes
    FOR v_ok IN
        SELECT column_name FROM information_schema.columns
        WHERE table_schema='public' AND table_name='inspecoes'
        AND column_name IN ('assinatura_mecanico','assinatura_cliente','nome_cliente_assinou','pdf_url','hash_integridade')
    LOOP END LOOP;

    IF (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema='public' AND table_name='inspecoes'
        AND column_name IN ('assinatura_mecanico','assinatura_cliente','nome_cliente_assinou','pdf_url','hash_integridade')) = 5 THEN
        RAISE NOTICE '  [PASS] 5 campos de assinatura/PDF presentes em inspecoes';
    ELSE
        RAISE NOTICE '  [FAIL] campos de assinatura/PDF incompletos em inspecoes';
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
