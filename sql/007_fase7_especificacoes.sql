-- =====================================================================
-- REVISAO-MOTO :: Migration Fase 7 - Especificacoes tecnicas por modelo
-- =====================================================================
-- Tabela consultiva com specs de torque, capacidades, pressoes,
-- para consulta rapida durante inspecoes.
-- Idempotente.
-- =====================================================================

CREATE TABLE IF NOT EXISTS especificacoes_modelo (
    id            SERIAL PRIMARY KEY,
    modelo_id     INT NOT NULL REFERENCES modelos(id) ON DELETE CASCADE,
    categoria     TEXT NOT NULL,   -- 'Torques', 'Fluidos', 'Pneus', 'Eletrica', 'Geral'
    item          TEXT NOT NULL,   -- 'Parafuso da roda dianteira', 'Pressao pneu dianteiro', etc
    valor         TEXT NOT NULL,   -- '55 Nm', '2.5 bar', '3.1 L', etc
    observacao    TEXT,
    ordem         INT NOT NULL DEFAULT 0,
    UNIQUE(modelo_id, categoria, item)
);

CREATE INDEX IF NOT EXISTS idx_espec_modelo ON especificacoes_modelo(modelo_id, categoria, ordem);

-- Seed generico para todos os modelos ativos (dados representativos - usuario
-- pode refinar por modelo no admin.html futuramente)
INSERT INTO especificacoes_modelo (modelo_id, categoria, item, valor, ordem)
SELECT m.id, x.categoria, x.item, x.valor, x.ordem
FROM modelos m
CROSS JOIN (VALUES
    ('Pneus',    'Pressao pneu dianteiro',      '2.0 bar / 29 psi',  10),
    ('Pneus',    'Pressao pneu traseiro (solo)','2.2 bar / 32 psi',  20),
    ('Pneus',    'Pressao pneu traseiro (garupa)','2.5 bar / 36 psi',30),
    ('Torques',  'Parafuso roda dianteira',     '80 Nm',             40),
    ('Torques',  'Parafuso roda traseira',      '110 Nm',            50),
    ('Torques',  'Vela de ignicao',             '12-15 Nm',          60),
    ('Torques',  'Parafuso dreno oleo motor',   '25 Nm',             70),
    ('Torques',  'Parafuso cabeceira cilindro', '35 Nm',             80),
    ('Fluidos',  'Oleo motor (troca)',          'Ver ficha do modelo',90),
    ('Fluidos',  'Fluido freio dianteiro',      'DOT 4',            100),
    ('Fluidos',  'Fluido freio traseiro',       'DOT 4',            110),
    ('Fluidos',  'Fluido embreagem',            'DOT 4',            120),
    ('Eletrica', 'Bateria',                     '12V',              130),
    ('Eletrica', 'Fusivel principal',           '30A',              140),
    ('Geral',    'Folga cabo embreagem',        '10-15 mm',         150),
    ('Geral',    'Folga corrente transmissao',  '25-35 mm',         160),
    ('Geral',    'Espacamento vela ignicao',    '0.8-0.9 mm',       170)
) AS x(categoria, item, valor, ordem)
WHERE m.ativo = TRUE
ON CONFLICT (modelo_id, categoria, item) DO NOTHING;

-- Especificacoes especificas por plataforma (650 vs 350 vs 450)
-- Volume de oleo
INSERT INTO especificacoes_modelo (modelo_id, categoria, item, valor, ordem)
SELECT m.id, 'Fluidos', 'Oleo motor (capacidade)',
    CASE
        WHEN m.nome LIKE '%650%' THEN '3.1 L (SAE 15W-50, JASO MA2)'
        WHEN m.nome LIKE '%350%' THEN '2.5 L (SAE 15W-50, JASO MA2)'
        WHEN m.nome LIKE '%450%' THEN '2.4 L (SAE 15W-50, JASO MA2)'
        ELSE '2.5 L'
    END,
    95
FROM modelos m
WHERE m.ativo = TRUE
ON CONFLICT (modelo_id, categoria, item) DO NOTHING;

-- View para exibicao ordenada
CREATE OR REPLACE VIEW vw_especificacoes AS
SELECT
    e.id,
    e.modelo_id,
    mo.nome         AS modelo,
    mo.plataforma,
    e.categoria,
    e.item,
    e.valor,
    e.observacao,
    e.ordem
FROM especificacoes_modelo e
JOIN modelos mo ON mo.id = e.modelo_id
ORDER BY mo.nome, e.categoria, e.ordem;

COMMENT ON TABLE especificacoes_modelo IS 'Especificacoes tecnicas de torques, fluidos, pneus para consulta durante inspecoes';
