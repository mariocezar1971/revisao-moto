-- =====================================================================
-- REVISAO-MOTO :: Migration Fase 2 - Soft delete em motos
-- =====================================================================
-- Adiciona campo 'ativo' para soft delete e atualiza views.
-- Idempotente: pode rodar varias vezes sem efeito colateral.
-- Execute no SQL Editor do Supabase APOS 001_schema.sql + 002_seed.
-- =====================================================================

-- 1. Campo ativo (soft delete)
ALTER TABLE motos ADD COLUMN IF NOT EXISTS ativo BOOLEAN DEFAULT TRUE NOT NULL;

-- 2. Indice para filtros rapidos por ativo
CREATE INDEX IF NOT EXISTS idx_motos_ativo ON motos(ativo);

-- 3. Atualiza vw_motos_status: enriquece colunas + filtra inativas
DROP VIEW IF EXISTS vw_motos_status;
CREATE VIEW vw_motos_status AS
SELECT
    m.id,
    m.placa,
    m.chassi,
    m.renavam,
    m.proprietario,
    m.telefone,
    m.email,
    m.modelo_id,
    mo.nome           AS modelo,
    mo.plataforma,
    m.ano,
    m.cor,
    m.km_atual,
    m.data_compra,
    m.observacoes,
    m.criado_em,
    m.atualizado_em,
    COUNT(i.id)                          AS total_inspecoes,
    MAX(i.data_fim)                      AS ultima_inspecao,
    MAX(i.km_registrado)                 AS km_ultima_inspecao
FROM motos m
LEFT JOIN modelos mo ON mo.id = m.modelo_id
LEFT JOIN inspecoes i ON i.moto_id = m.id AND i.status = 'finalizada'
WHERE m.ativo = TRUE
GROUP BY m.id, mo.nome, mo.plataforma;

-- 4. Nova view: motos arquivadas (soft-deleted)
CREATE OR REPLACE VIEW vw_motos_arquivadas AS
SELECT m.*, mo.nome AS modelo
FROM motos m
LEFT JOIN modelos mo ON mo.id = m.modelo_id
WHERE m.ativo = FALSE;

-- 5. Funcao auxiliar para reativar moto arquivada (caso de erro)
CREATE OR REPLACE FUNCTION reativar_moto(p_placa TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_afetadas INT;
BEGIN
    UPDATE motos SET ativo = TRUE, atualizado_em = NOW()
    WHERE placa = p_placa AND ativo = FALSE;
    GET DIAGNOSTICS v_afetadas = ROW_COUNT;
    RETURN v_afetadas > 0;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION reativar_moto(TEXT) IS 'Reativa moto arquivada por placa. Retorna TRUE se reativou.';
