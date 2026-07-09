-- =====================================================================
-- REVISAO-MOTO :: Migration Fase 3 - Execucao de Checklist
-- =====================================================================
-- Adiciona funcao de sugestao de revisao, view de progresso e trigger
-- de atualizacao de km da moto ao finalizar inspecao.
-- Idempotente.
-- =====================================================================

-- 1. Indices adicionais para performance de queries de execucao
CREATE INDEX IF NOT EXISTS idx_inspecoes_data_fim ON inspecoes(data_fim);
CREATE INDEX IF NOT EXISTS idx_inspecoes_itens_item ON inspecoes_itens(item_id);

-- 2. Funcao: sugere proxima revisao baseada no km da moto e historico
CREATE OR REPLACE FUNCTION sugerir_revisao(p_moto_id INT)
RETURNS TABLE(
    revisao_id       INT,
    km_revisao       INT,
    meses            INT,
    tipo             TEXT,
    motivo           TEXT,
    km_atual_moto    INT,
    ultima_km        INT,
    ultima_data      TIMESTAMPTZ
) AS $$
DECLARE
    v_km_moto   INT;
    v_modelo_id INT;
    v_ultima_km INT;
    v_ultima_dt TIMESTAMPTZ;
    v_prox_km   INT;
BEGIN
    -- Dados da moto
    SELECT km_atual, modelo_id INTO v_km_moto, v_modelo_id
    FROM motos WHERE id = p_moto_id AND ativo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Moto % nao encontrada ou inativa', p_moto_id;
    END IF;

    -- Ultima inspecao finalizada
    SELECT km_registrado, data_fim INTO v_ultima_km, v_ultima_dt
    FROM inspecoes
    WHERE moto_id = p_moto_id AND status = 'finalizada'
    ORDER BY data_fim DESC LIMIT 1;

    -- Calcula proxima revisao
    IF v_ultima_km IS NULL THEN
        -- Nunca fez revisao: se km >= 500 sugere 500 km; senao 500 tambem (pre-amaciamento)
        v_prox_km := 500;
    ELSE
        -- Proxima revisao a partir do ultimo servico
        -- Se km atual ja passou de 500 e nao tem 500 registrada, ainda sugere 500
        IF v_ultima_km < 500 THEN
            v_prox_km := 500;
        ELSE
            -- Proximo multiplo de 5000 apos o ultimo servico
            v_prox_km := ((v_ultima_km / 5000) + 1) * 5000;
        END IF;
    END IF;

    -- Limita a 30000 (fim da garantia)
    IF v_prox_km > 30000 THEN
        v_prox_km := 30000 + (((v_km_moto - 30000) / 5000) + 1) * 5000;
    END IF;

    -- Retorna revisao sugerida
    RETURN QUERY
    SELECT
        r.id,
        r.km,
        r.meses,
        r.tipo,
        CASE
            WHEN v_ultima_km IS NULL THEN 'Primeira inspecao registrada'
            WHEN v_km_moto >= r.km THEN 'Km atingido para esta revisao'
            WHEN v_ultima_dt < NOW() - (r.meses || ' months')::INTERVAL THEN 'Prazo em meses atingido'
            ELSE 'Proxima revisao programada'
        END,
        v_km_moto,
        v_ultima_km,
        v_ultima_dt
    FROM revisoes r
    WHERE r.modelo_id = v_modelo_id
      AND r.km = LEAST(v_prox_km, 30000)
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION sugerir_revisao(INT) IS 'Sugere proxima revisao com base no km atual e historico.';

-- 3. View: progresso de uma inspecao (X de Y itens, obrigatorios pendentes)
-- CASCADE derruba vw_inspecoes_lista tambem (recriada no fim)
DROP VIEW IF EXISTS vw_inspecoes_lista;
DROP VIEW IF EXISTS vw_inspecao_progresso CASCADE;
CREATE VIEW vw_inspecao_progresso AS
SELECT
    i.id AS inspecao_id,
    i.status,
    COUNT(DISTINCT ic.id)                                                                                    AS total_itens,
    COUNT(DISTINCT ii.id) FILTER (WHERE ii.status IN ('ok','nao_ok','na'))                                  AS preenchidos,
    COUNT(DISTINCT ii.id) FILTER (WHERE ii.status = 'ok')                                                    AS ok_count,
    COUNT(DISTINCT ii.id) FILTER (WHERE ii.status = 'nao_ok')                                               AS nao_ok_count,
    COUNT(DISTINCT ii.id) FILTER (WHERE ii.status = 'na')                                                    AS na_count,
    COUNT(DISTINCT ic.id) FILTER (WHERE ic.obrigatorio = TRUE)                                              AS obrigatorios,
    COUNT(DISTINCT ii.id) FILTER (WHERE ii.status IN ('ok','nao_ok','na') AND ic.obrigatorio = TRUE)         AS obrigatorios_preenchidos,
    COUNT(DISTINCT ic.id) FILTER (WHERE ic.exige_foto = TRUE)                                               AS itens_exigem_foto,
    COUNT(DISTINCT ii.id) FILTER (WHERE ii.foto_url IS NOT NULL AND ii.foto_url <> '')                       AS fotos_capturadas,
    COUNT(DISTINCT ic.id) FILTER (WHERE ic.exige_medicao = TRUE)                                            AS itens_exigem_medicao,
    COUNT(DISTINCT ii.id) FILTER (WHERE ii.valor_medido IS NOT NULL AND ii.valor_medido <> '')              AS medicoes_registradas
FROM inspecoes i
JOIN itens_checklist ic ON ic.revisao_id = i.revisao_id
LEFT JOIN inspecoes_itens ii ON ii.inspecao_id = i.id AND ii.item_id = ic.id
GROUP BY i.id, i.status;

-- 4. Funcao: verifica se inspecao pode ser finalizada
CREATE OR REPLACE FUNCTION pode_finalizar_inspecao(p_inspecao_id UUID)
RETURNS TABLE(
    pode_finalizar     BOOLEAN,
    faltam_obrigatorios INT,
    faltam_fotos       INT,
    faltam_medicoes    INT,
    motivo             TEXT
) AS $$
DECLARE
    v_p vw_inspecao_progresso%ROWTYPE;
    v_faltam_fotos INT;
    v_faltam_medicoes INT;
    v_faltam_obrig INT;
BEGIN
    SELECT * INTO v_p FROM vw_inspecao_progresso WHERE inspecao_id = p_inspecao_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 0, 0, 0, 'Inspecao nao encontrada';
        RETURN;
    END IF;

    v_faltam_obrig := v_p.obrigatorios - v_p.obrigatorios_preenchidos;

    -- Conta itens que exigem foto mas nao tem foto (apenas para itens com status preenchido != 'na')
    SELECT COUNT(*) INTO v_faltam_fotos
    FROM itens_checklist ic
    LEFT JOIN inspecoes_itens ii ON ii.inspecao_id = p_inspecao_id AND ii.item_id = ic.id
    JOIN inspecoes i ON i.id = p_inspecao_id AND i.revisao_id = ic.revisao_id
    WHERE ic.exige_foto = TRUE
      AND (ii.status IS NULL OR ii.status = 'ok' OR ii.status = 'nao_ok')
      AND (ii.foto_url IS NULL OR ii.foto_url = '');

    -- Conta itens que exigem medicao mas nao tem valor
    SELECT COUNT(*) INTO v_faltam_medicoes
    FROM itens_checklist ic
    LEFT JOIN inspecoes_itens ii ON ii.inspecao_id = p_inspecao_id AND ii.item_id = ic.id
    JOIN inspecoes i ON i.id = p_inspecao_id AND i.revisao_id = ic.revisao_id
    WHERE ic.exige_medicao = TRUE
      AND (ii.status IS NULL OR ii.status = 'ok' OR ii.status = 'nao_ok')
      AND (ii.valor_medido IS NULL OR ii.valor_medido = '');

    IF v_faltam_obrig > 0 THEN
        RETURN QUERY SELECT FALSE, v_faltam_obrig::INT, v_faltam_fotos::INT, v_faltam_medicoes::INT,
                     format('%s item(s) obrigatorio(s) sem preenchimento', v_faltam_obrig);
    ELSIF v_faltam_fotos > 0 THEN
        RETURN QUERY SELECT FALSE, 0, v_faltam_fotos::INT, v_faltam_medicoes::INT,
                     format('%s foto(s) exigida(s) pendente(s)', v_faltam_fotos);
    ELSIF v_faltam_medicoes > 0 THEN
        RETURN QUERY SELECT FALSE, 0, v_faltam_fotos::INT, v_faltam_medicoes::INT,
                     format('%s medicao(oes) exigida(s) pendente(s)', v_faltam_medicoes);
    ELSE
        RETURN QUERY SELECT TRUE, 0, 0, 0, 'Pronto para finalizar';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 5. Trigger: atualiza km_atual da moto ao finalizar inspecao
CREATE OR REPLACE FUNCTION trigger_atualizar_km_moto()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'finalizada' AND (OLD.status IS NULL OR OLD.status <> 'finalizada') THEN
        UPDATE motos
        SET km_atual = GREATEST(km_atual, NEW.km_registrado),
            atualizado_em = NOW()
        WHERE id = NEW.moto_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_km_moto_ao_finalizar ON inspecoes;
CREATE TRIGGER set_km_moto_ao_finalizar
    AFTER INSERT OR UPDATE ON inspecoes
    FOR EACH ROW EXECUTE FUNCTION trigger_atualizar_km_moto();

-- 6. View: lista inspecoes com dados agregados para historico
CREATE OR REPLACE VIEW vw_inspecoes_lista AS
SELECT
    i.id,
    i.moto_id,
    m.placa,
    m.proprietario,
    mo.nome                              AS modelo,
    r.km                                 AS revisao_km,
    i.km_registrado,
    i.status,
    i.mecanico_nome,
    i.data_inicio,
    i.data_fim,
    p.total_itens,
    p.preenchidos,
    p.ok_count,
    p.nao_ok_count,
    ROUND(100.0 * p.preenchidos / NULLIF(p.total_itens, 0), 0) AS pct_completo
FROM inspecoes i
JOIN motos m         ON m.id = i.moto_id
JOIN modelos mo      ON mo.id = m.modelo_id
JOIN revisoes r      ON r.id = i.revisao_id
LEFT JOIN vw_inspecao_progresso p ON p.inspecao_id = i.id;
