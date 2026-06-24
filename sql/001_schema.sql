-- =====================================================================
-- REVISAO-MOTO :: Schema DDL
-- Projeto: Checklist de revisões Royal Enfield (PWA + Supabase)
-- Autor: Mario Cezar dos Santos Junior
-- Data: 2026
-- =====================================================================
-- Execute este arquivo no SQL Editor do Supabase (uma vez).
-- Depois execute 002_seed_royal_enfield.sql para popular o catálogo.
-- =====================================================================

-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================================
-- 1. CATÁLOGO (dados estáticos: modelos, revisões, itens)
-- =====================================================================

-- Tabela de modelos de motocicletas
DROP TABLE IF EXISTS itens_checklist CASCADE;
DROP TABLE IF EXISTS revisoes CASCADE;
DROP TABLE IF EXISTS inspecoes_itens CASCADE;
DROP TABLE IF EXISTS inspecoes CASCADE;
DROP TABLE IF EXISTS motos CASCADE;
DROP TABLE IF EXISTS modelos CASCADE;

CREATE TABLE modelos (
    id            SERIAL PRIMARY KEY,
    marca         TEXT NOT NULL DEFAULT 'Royal Enfield',
    nome          TEXT NOT NULL,
    plataforma    TEXT,                  -- '650 Twin', '350 J', 'Himalayan 450'
    cilindrada    INT,
    tipo_oleo     TEXT,                  -- '15W-50 semi-sintetico'
    volume_oleo   NUMERIC(3,1),          -- litros
    gap_vela      TEXT,                  -- '0,7-0,8 mm'
    ativo         BOOLEAN DEFAULT TRUE,
    criado_em     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(marca, nome)
);

COMMENT ON TABLE modelos IS 'Catalogo de modelos de motocicletas';

-- Tabela de revisões programadas por modelo
CREATE TABLE revisoes (
    id            SERIAL PRIMARY KEY,
    modelo_id     INT REFERENCES modelos(id) ON DELETE CASCADE,
    km            INT NOT NULL,          -- 500, 5000, 10000, ...
    meses         INT NOT NULL,          -- 1, 6, 12, 18, ...
    tipo          TEXT,                  -- 'amaciamento', 'leve', 'intermediaria', 'pesada'
    descricao     TEXT,                  -- Descricao livre
    UNIQUE(modelo_id, km)
);

COMMENT ON TABLE revisoes IS 'Intervalos de revisao por modelo';

-- Tabela de itens de checklist por revisão
CREATE TABLE itens_checklist (
    id                 SERIAL PRIMARY KEY,
    revisao_id         INT REFERENCES revisoes(id) ON DELETE CASCADE,
    ordem              INT NOT NULL,
    categoria          TEXT,             -- 'Motor', 'Freios', 'Transmissao', 'Eletrica', 'Geral', 'Suspensao', 'Pneus', 'Lubrificacao'
    descricao          TEXT NOT NULL,
    tipo_verificacao   TEXT,             -- 'visual', 'medicao', 'troca', 'lubrificacao', 'ajuste'
    valor_referencia   TEXT,             -- '0,7-0,8 mm', '20-30 mm', '3,1 L', etc.
    obrigatorio        BOOLEAN DEFAULT TRUE,
    exige_foto         BOOLEAN DEFAULT FALSE,
    exige_medicao      BOOLEAN DEFAULT FALSE,
    UNIQUE(revisao_id, ordem)
);

COMMENT ON TABLE itens_checklist IS 'Itens a verificar em cada revisao';

-- =====================================================================
-- 2. OPERACIONAL (motos cadastradas + inspeções executadas)
-- =====================================================================

-- Tabela de motos (uma por placa)
CREATE TABLE motos (
    id              SERIAL PRIMARY KEY,
    placa           TEXT UNIQUE NOT NULL,
    chassi          TEXT,
    renavam         TEXT,
    modelo_id       INT REFERENCES modelos(id),
    ano             INT,
    cor             TEXT,
    proprietario    TEXT,
    telefone        TEXT,
    email           TEXT,
    data_compra     DATE,
    km_atual        INT DEFAULT 0,
    observacoes     TEXT,
    criado_em       TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em   TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE motos IS 'Motocicletas cadastradas na oficina';

-- Inspeções (cabecalho)
CREATE TABLE inspecoes (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moto_id               INT REFERENCES motos(id),
    revisao_id            INT REFERENCES revisoes(id),
    mecanico_id           UUID REFERENCES auth.users(id),
    mecanico_nome         TEXT,                -- snapshot do nome
    data_inicio           TIMESTAMPTZ DEFAULT NOW(),
    data_fim              TIMESTAMPTZ,
    km_registrado         INT NOT NULL,
    status                TEXT DEFAULT 'em_andamento',  -- 'em_andamento', 'finalizada', 'cancelada'
    assinatura_mecanico   TEXT,                -- base64 PNG da assinatura
    assinatura_cliente    TEXT,
    nome_cliente_assinou  TEXT,
    observacoes_gerais    TEXT,
    pdf_url               TEXT,
    hash_integridade      TEXT,                -- SHA-256 do conteudo
    criado_em             TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE inspecoes IS 'Inspecoes/revisoes executadas';

-- Itens verificados em cada inspeção
CREATE TABLE inspecoes_itens (
    id              SERIAL PRIMARY KEY,
    inspecao_id     UUID REFERENCES inspecoes(id) ON DELETE CASCADE,
    item_id         INT REFERENCES itens_checklist(id),
    status          TEXT,                -- 'ok', 'nao_ok', 'na', 'pendente'
    valor_medido    TEXT,                -- valor real medido pelo mecanico
    observacao      TEXT,
    foto_url        TEXT,                -- URL do Storage do Supabase
    verificado_em   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(inspecao_id, item_id)
);

COMMENT ON TABLE inspecoes_itens IS 'Resultado de cada item verificado na inspecao';

-- =====================================================================
-- 3. ÍNDICES
-- =====================================================================

CREATE INDEX idx_revisoes_modelo ON revisoes(modelo_id);
CREATE INDEX idx_itens_revisao ON itens_checklist(revisao_id);
CREATE INDEX idx_motos_placa ON motos(placa);
CREATE INDEX idx_motos_modelo ON motos(modelo_id);
CREATE INDEX idx_inspecoes_moto ON inspecoes(moto_id);
CREATE INDEX idx_inspecoes_status ON inspecoes(status);
CREATE INDEX idx_inspecoes_data ON inspecoes(data_inicio DESC);
CREATE INDEX idx_inspecoes_itens_inspecao ON inspecoes_itens(inspecao_id);

-- =====================================================================
-- 4. TRIGGERS (atualiza atualizado_em automaticamente)
-- =====================================================================

CREATE OR REPLACE FUNCTION trigger_set_atualizado_em()
RETURNS TRIGGER AS $$
BEGIN
    NEW.atualizado_em = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_atualizado_em_motos
    BEFORE UPDATE ON motos
    FOR EACH ROW EXECUTE FUNCTION trigger_set_atualizado_em();

-- =====================================================================
-- 5. VIEWS DE APOIO
-- =====================================================================

-- View completa: para cada revisao, lista todos os itens com info do modelo
CREATE OR REPLACE VIEW vw_checklist_completo AS
SELECT
    m.id               AS modelo_id,
    m.nome             AS modelo_nome,
    m.plataforma,
    r.id               AS revisao_id,
    r.km,
    r.meses,
    r.tipo             AS revisao_tipo,
    i.id               AS item_id,
    i.ordem,
    i.categoria,
    i.descricao,
    i.tipo_verificacao,
    i.valor_referencia,
    i.obrigatorio,
    i.exige_foto,
    i.exige_medicao
FROM modelos m
JOIN revisoes r ON r.modelo_id = m.id
JOIN itens_checklist i ON i.revisao_id = r.id
ORDER BY m.nome, r.km, i.ordem;

-- View resumo: contagem de inspecoes por moto, ultima data, proxima prevista
CREATE OR REPLACE VIEW vw_motos_status AS
SELECT
    m.id,
    m.placa,
    m.proprietario,
    mo.nome AS modelo,
    m.km_atual,
    COUNT(i.id) AS total_inspecoes,
    MAX(i.data_fim) AS ultima_inspecao,
    MAX(i.km_registrado) AS km_ultima_inspecao
FROM motos m
LEFT JOIN modelos mo ON mo.id = m.modelo_id
LEFT JOIN inspecoes i ON i.moto_id = m.id AND i.status = 'finalizada'
GROUP BY m.id, m.placa, m.proprietario, mo.nome, m.km_atual;

-- =====================================================================
-- 6. ROW LEVEL SECURITY (RLS)
-- =====================================================================
-- Para uso interno (voce + mecanicos): qualquer usuario autenticado
-- pode ler/escrever tudo. Se quiser multi-oficina depois, mudar aqui.

ALTER TABLE modelos ENABLE ROW LEVEL SECURITY;
ALTER TABLE revisoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE itens_checklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE motos ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspecoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspecoes_itens ENABLE ROW LEVEL SECURITY;

-- Politica: qualquer usuario autenticado pode ler catalogo
CREATE POLICY "auth_read_modelos" ON modelos FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read_revisoes" ON revisoes FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_read_itens" ON itens_checklist FOR SELECT TO authenticated USING (true);

-- Politica: qualquer usuario autenticado pode CRUD em motos e inspecoes
CREATE POLICY "auth_all_motos" ON motos FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_all_inspecoes" ON inspecoes FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_all_inspecoes_itens" ON inspecoes_itens FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- =====================================================================
-- FIM DO SCHEMA
-- =====================================================================
