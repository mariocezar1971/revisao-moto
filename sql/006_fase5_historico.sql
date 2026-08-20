-- =====================================================================
-- REVISAO-MOTO :: Migration Fase 5 - Historico e Relatorios
-- =====================================================================
-- Views agregadas e funcoes para historico por moto, timeline, filtros,
-- exports CSV e relatorios gerenciais.
-- Idempotente: pode rodar varias vezes.
-- =====================================================================

-- 1. Indices adicionais para queries de agregacao
CREATE INDEX IF NOT EXISTS idx_inspecoes_mecanico_id ON inspecoes(mecanico_id) WHERE mecanico_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_inspecoes_data_inicio ON inspecoes(data_inicio);
CREATE INDEX IF NOT EXISTS idx_inspecoes_status_data ON inspecoes(status, data_fim);

-- 2. Funcao: retorna categoria de status da moto quanto a revisao
--    'em_dia' | 'proxima' (dentro de 500km) | 'atrasada' | 'sem_historico'
CREATE OR REPLACE FUNCTION status_revisao_moto(p_moto_id INT)
RETURNS TEXT AS $$
DECLARE
    v_km_atual  INT;
    v_ultima_km INT;
    v_ultima_dt TIMESTAMPTZ;
    v_prox_km   INT;
    v_km_ate_prox INT;
BEGIN
    SELECT km_atual INTO v_km_atual FROM motos WHERE id = p_moto_id;
    IF NOT FOUND THEN RETURN 'nao_encontrada'; END IF;

    SELECT km_registrado, data_fim INTO v_ultima_km, v_ultima_dt
    FROM inspecoes
    WHERE moto_id = p_moto_id AND status = 'finalizada'
    ORDER BY data_fim DESC NULLS LAST LIMIT 1;

    IF v_ultima_km IS NULL THEN
        RETURN 'sem_historico';
    END IF;

    -- Calcula proxima revisao esperada
    IF v_ultima_km < 500 THEN
        v_prox_km := 500;
    ELSE
        v_prox_km := ((v_ultima_km / 5000) + 1) * 5000;
    END IF;

    v_km_ate_prox := v_prox_km - v_km_atual;

    -- 6 meses desde ultima
    IF v_ultima_dt < NOW() - INTERVAL '6 months' THEN
        RETURN 'atrasada';
    END IF;

    IF v_km_ate_prox <= 0 THEN
        RETURN 'atrasada';
    ELSIF v_km_ate_prox <= 500 THEN
        RETURN 'proxima';
    ELSE
        RETURN 'em_dia';
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION status_revisao_moto(INT) IS 'Retorna: em_dia | proxima | atrasada | sem_historico | nao_encontrada';

-- 3. View: motos com status de revisao (para lista principal)
CREATE OR REPLACE VIEW vw_motos_com_status_revisao AS
SELECT
    m.id,
    m.placa,
    m.proprietario,
    mo.nome                                  AS modelo,
    m.km_atual,
    (SELECT MAX(data_fim) FROM inspecoes
     WHERE moto_id = m.id AND status = 'finalizada')          AS ultima_inspecao,
    (SELECT km_registrado FROM inspecoes
     WHERE moto_id = m.id AND status = 'finalizada'
     ORDER BY data_fim DESC NULLS LAST LIMIT 1)               AS km_ultima_inspecao,
    (SELECT COUNT(*) FROM inspecoes
     WHERE moto_id = m.id AND status = 'finalizada')          AS total_inspecoes,
    status_revisao_moto(m.id)                                 AS status_revisao,
    -- Proxima km prevista
    CASE
        WHEN (SELECT MAX(km_registrado) FROM inspecoes
              WHERE moto_id = m.id AND status = 'finalizada') IS NULL THEN 500
        WHEN (SELECT MAX(km_registrado) FROM inspecoes
              WHERE moto_id = m.id AND status = 'finalizada') < 500 THEN 500
        ELSE (((SELECT MAX(km_registrado) FROM inspecoes
                WHERE moto_id = m.id AND status = 'finalizada') / 5000) + 1) * 5000
    END                                                       AS proxima_km_prevista
FROM motos m
JOIN modelos mo ON mo.id = m.modelo_id
WHERE m.ativo = TRUE;

-- 4. View: timeline de inspecoes de uma moto (para tela de detalhe)
CREATE OR REPLACE VIEW vw_timeline_inspecoes AS
SELECT
    i.id,
    i.moto_id,
    m.placa,
    i.revisao_id,
    r.km                                     AS revisao_km,
    r.tipo                                   AS revisao_tipo,
    i.km_registrado,
    i.status,
    i.mecanico_nome,
    i.nome_cliente_assinou,
    i.data_inicio,
    i.data_fim,
    i.pdf_url,
    i.hash_integridade,
    -- Duracao em minutos
    CASE WHEN i.data_fim IS NOT NULL AND i.data_inicio IS NOT NULL
         THEN EXTRACT(EPOCH FROM (i.data_fim - i.data_inicio))/60
         ELSE NULL END                       AS duracao_minutos,
    -- Contadores da vw_inspecao_progresso
    p.total_itens,
    p.ok_count,
    p.nao_ok_count,
    p.na_count,
    p.preenchidos
FROM inspecoes i
JOIN motos m         ON m.id = i.moto_id
JOIN revisoes r      ON r.id = i.revisao_id
LEFT JOIN vw_inspecao_progresso p ON p.inspecao_id = i.id;

-- 5. View: agregado por mecanico e mes/ano
CREATE OR REPLACE VIEW vw_inspecoes_por_mecanico_mes AS
SELECT
    mecanico_nome,
    DATE_TRUNC('month', data_inicio)::DATE   AS mes,
    COUNT(*)                                 AS total,
    COUNT(*) FILTER (WHERE status = 'finalizada')   AS finalizadas,
    COUNT(*) FILTER (WHERE status = 'em_andamento') AS em_andamento,
    COUNT(*) FILTER (WHERE status = 'cancelada')    AS canceladas,
    AVG(EXTRACT(EPOCH FROM (data_fim - data_inicio))/60)
        FILTER (WHERE status = 'finalizada' AND data_fim IS NOT NULL)  AS duracao_media_min
FROM inspecoes
WHERE mecanico_nome IS NOT NULL
GROUP BY mecanico_nome, DATE_TRUNC('month', data_inicio);

-- 6. View: itens mais reprovados (top problemas)
CREATE OR REPLACE VIEW vw_itens_mais_reprovados AS
SELECT
    ic.categoria,
    ic.descricao,
    mo.nome                                  AS modelo,
    COUNT(*)                                 AS reprovacoes,
    COUNT(DISTINCT ii.inspecao_id)           AS inspecoes_afetadas,
    MAX(i.data_fim)                          AS ultima_ocorrencia
FROM inspecoes_itens ii
JOIN itens_checklist ic ON ic.id = ii.item_id
JOIN revisoes r         ON r.id = ic.revisao_id
JOIN modelos mo         ON mo.id = r.modelo_id
JOIN inspecoes i        ON i.id = ii.inspecao_id
WHERE ii.status = 'nao_ok'
  AND i.status = 'finalizada'
GROUP BY ic.categoria, ic.descricao, mo.nome
ORDER BY reprovacoes DESC;

-- 7. Funcao: estatisticas gerais (para dashboard de relatorios)
CREATE OR REPLACE FUNCTION estatisticas_gerais()
RETURNS TABLE(
    total_motos            BIGINT,
    total_inspecoes        BIGINT,
    inspecoes_finalizadas  BIGINT,
    inspecoes_em_andamento BIGINT,
    motos_atrasadas        BIGINT,
    motos_proximas         BIGINT,
    duracao_media_min      NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM motos WHERE ativo = TRUE),
        (SELECT COUNT(*) FROM inspecoes),
        (SELECT COUNT(*) FROM inspecoes WHERE status = 'finalizada'),
        (SELECT COUNT(*) FROM inspecoes WHERE status = 'em_andamento'),
        (SELECT COUNT(*) FROM vw_motos_com_status_revisao WHERE status_revisao = 'atrasada'),
        (SELECT COUNT(*) FROM vw_motos_com_status_revisao WHERE status_revisao = 'proxima'),
        (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (data_fim - data_inicio))/60)::NUMERIC, 1)
         FROM inspecoes
         WHERE status = 'finalizada' AND data_fim IS NOT NULL);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION estatisticas_gerais() IS 'Dashboard de estatisticas gerais do sistema';
