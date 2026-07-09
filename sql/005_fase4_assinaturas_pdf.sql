-- =====================================================================
-- REVISAO-MOTO :: Migration Fase 4 - Assinaturas e PDF
-- =====================================================================
-- Os campos ja existem no schema original (assinatura_mecanico,
-- assinatura_cliente, nome_cliente_assinou, pdf_url, hash_integridade).
-- Aqui apenas adicionamos view e indice de apoio.
-- Idempotente.
-- =====================================================================

-- Indice para busca de inspecoes com PDF
CREATE INDEX IF NOT EXISTS idx_inspecoes_pdf_url ON inspecoes(pdf_url)
    WHERE pdf_url IS NOT NULL;

-- View: inspecoes finalizadas com dados de PDF/assinaturas
CREATE OR REPLACE VIEW vw_inspecoes_com_pdf AS
SELECT
    i.id,
    i.moto_id,
    m.placa,
    m.proprietario,
    mo.nome                              AS modelo,
    r.km                                 AS revisao_km,
    r.tipo                               AS revisao_tipo,
    i.km_registrado,
    i.data_inicio,
    i.data_fim,
    i.mecanico_nome,
    i.nome_cliente_assinou,
    i.observacoes_gerais,
    i.pdf_url,
    i.hash_integridade,
    CASE WHEN i.assinatura_mecanico IS NOT NULL AND length(i.assinatura_mecanico) > 0
         THEN TRUE ELSE FALSE END        AS tem_assinatura_mecanico,
    CASE WHEN i.assinatura_cliente IS NOT NULL AND length(i.assinatura_cliente) > 0
         THEN TRUE ELSE FALSE END        AS tem_assinatura_cliente,
    CASE WHEN i.pdf_url IS NOT NULL AND length(i.pdf_url) > 0
         THEN TRUE ELSE FALSE END        AS tem_pdf
FROM inspecoes i
JOIN motos m         ON m.id = i.moto_id
JOIN modelos mo      ON mo.id = m.modelo_id
JOIN revisoes r      ON r.id = i.revisao_id
WHERE i.status = 'finalizada';

COMMENT ON VIEW vw_inspecoes_com_pdf IS 'Inspecoes finalizadas com metadados de PDF e assinaturas.';

-- Funcao: verifica se inspecao tem assinaturas completas antes de gerar PDF
CREATE OR REPLACE FUNCTION assinaturas_completas(p_inspecao_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_mec  TEXT;
    v_cli  TEXT;
    v_nome TEXT;
BEGIN
    SELECT assinatura_mecanico, assinatura_cliente, nome_cliente_assinou
    INTO v_mec, v_cli, v_nome
    FROM inspecoes WHERE id = p_inspecao_id;

    RETURN v_mec IS NOT NULL AND length(v_mec) > 100
       AND v_cli IS NOT NULL AND length(v_cli) > 100
       AND v_nome IS NOT NULL AND length(v_nome) > 0;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION assinaturas_completas(UUID) IS 'Retorna TRUE se ambas assinaturas e nome do cliente estao preenchidos.';
