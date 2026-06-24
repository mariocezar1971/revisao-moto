-- =====================================================================
-- REVISAO-MOTO :: Seed de dados Royal Enfield
-- Popula modelos, revisoes e itens_checklist
-- Execute APOS 001_schema.sql
-- =====================================================================

-- =====================================================================
-- 1. MODELOS
-- =====================================================================

INSERT INTO modelos (nome, plataforma, cilindrada, tipo_oleo, volume_oleo, gap_vela) VALUES
    -- Linha 650 Twin
    ('Shotgun 650',        '650 Twin', 648, '15W-50 semi-sintetico', 3.1, '0,7-0,8 mm'),
    ('Super Meteor 650',   '650 Twin', 648, '15W-50 semi-sintetico', 3.1, '0,7-0,8 mm'),
    ('Interceptor 650',    '650 Twin', 648, '15W-50 semi-sintetico', 3.1, '0,7-0,8 mm'),
    ('Continental GT 650', '650 Twin', 648, '15W-50 semi-sintetico', 3.1, '0,7-0,8 mm'),
    ('Classic 650',        '650 Twin', 648, '15W-50 semi-sintetico', 3.1, '0,7-0,8 mm'),
    ('Bear 650',           '650 Twin', 648, '15W-50 semi-sintetico', 3.1, '0,7-0,8 mm'),
    -- Linha 350 J-platform
    ('Hunter 350',         '350 J',    349, '15W-50 semi-sintetico', 2.5, '0,7-0,8 mm'),
    ('Classic 350',        '350 J',    349, '15W-50 semi-sintetico', 2.5, '0,7-0,8 mm'),
    ('Meteor 350',         '350 J',    349, '15W-50 semi-sintetico', 2.5, '0,7-0,8 mm'),
    -- Himalayan
    ('Himalayan 450',      'Himalayan 450', 452, '10W-40 sintetico',   2.5, '0,8-0,9 mm');

-- =====================================================================
-- 2. REVISOES (mesma estrutura para toda a linha)
-- =====================================================================
-- Geramos as 7 revisoes (500, 5k, 10k, 15k, 20k, 25k, 30k) para cada modelo

INSERT INTO revisoes (modelo_id, km, meses, tipo, descricao)
SELECT id, 500,   1,  'amaciamento',    'Primeira revisao - assentamento do motor' FROM modelos UNION ALL
SELECT id, 5000,  6,  'leve',           'Revisao regular' FROM modelos UNION ALL
SELECT id, 10000, 12, 'intermediaria',  'Revisao intermediaria com folga de valvulas' FROM modelos UNION ALL
SELECT id, 15000, 18, 'leve',           'Revisao regular' FROM modelos UNION ALL
SELECT id, 20000, 24, 'pesada',         'Revisao pesada - trocas de filtros, velas, fluidos' FROM modelos UNION ALL
SELECT id, 25000, 30, 'leve',           'Revisao regular' FROM modelos UNION ALL
SELECT id, 30000, 36, 'intermediaria',  'Revisao intermediaria - fim da garantia' FROM modelos;

-- =====================================================================
-- 3. ITENS DE CHECKLIST
-- =====================================================================
-- Estrategia: usamos uma funcao auxiliar para nao repetir INSERTs
-- Os itens sao agrupados por tipo de revisao e replicados para todos
-- os modelos compativeis.

-- ---------------------------------------------------------------------
-- 500 km - PRIMEIRA REVISAO (amaciamento) - todos os modelos
-- ---------------------------------------------------------------------
INSERT INTO itens_checklist (revisao_id, ordem, categoria, descricao, tipo_verificacao, valor_referencia, exige_foto, exige_medicao)
SELECT r.id, 1,  'Motor',         'Troca de oleo do motor',                      'troca',         m.volume_oleo || ' L ' || m.tipo_oleo, true, false FROM revisoes r JOIN modelos m ON m.id = r.modelo_id WHERE r.km = 500 UNION ALL
SELECT r.id, 2,  'Motor',         'Troca de filtro de oleo',                     'troca',         'Filtro original RE', true, false FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 3,  'Motor',         'Verificacao de folga de valvulas',            'medicao',       'Conforme manual', false, true FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 4,  'Transmissao',   'Limpeza, lubrificacao e ajuste de corrente',  'lubrificacao',  'Folga 20-30 mm', false, true FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 5,  'Freios',        'Inspecao de pastilhas dianteiras',            'visual',        'Espessura minima 1,5 mm', false, true FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 6,  'Freios',        'Inspecao de pastilhas traseiras',             'visual',        'Espessura minima 1,5 mm', false, true FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 7,  'Freios',        'Verificacao de fluido de freio',              'visual',        'DOT 4 - dianteiro e traseiro', false, false FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 8,  'Geral',         'Conferencia de torques de fixacao',           'ajuste',        'Conforme manual', false, false FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 9,  'Eletrica',      'Bateria e terminais',                         'visual',        'Tensao > 12,4 V', false, true FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 10, 'Eletrica',      'Farois, lanterna, setas, luz de freio',       'visual',        'Funcionamento integral', false, false FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 11, 'Lubrificacao',  'Cabos de embreagem e acelerador',             'lubrificacao',  'Sem ressecamento', false, false FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 12, 'Lubrificacao',  'Pedal de cambio e pedal de freio',            'lubrificacao',  'Movimento suave', false, false FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 13, 'Pneus',         'Pressao e desgaste',                          'medicao',       'Diant 32 psi / Tras 36 psi (variavel)', false, true FROM revisoes r WHERE r.km = 500 UNION ALL
SELECT r.id, 14, 'Geral',         'Teste de rodagem',                            'visual',        'Sem ruidos anormais', false, false FROM revisoes r WHERE r.km = 500;

-- ---------------------------------------------------------------------
-- 5000 / 15000 / 25000 km - REVISOES REGULARES (leves)
-- ---------------------------------------------------------------------
INSERT INTO itens_checklist (revisao_id, ordem, categoria, descricao, tipo_verificacao, valor_referencia, exige_foto, exige_medicao)
SELECT r.id, 1,  'Motor',         'Troca de oleo do motor',                      'troca',         m.volume_oleo || ' L ' || m.tipo_oleo, true, false FROM revisoes r JOIN modelos m ON m.id = r.modelo_id WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 2,  'Motor',         'Troca de filtro de oleo',                     'troca',         'Filtro original RE', true, false FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 3,  'Motor',         'Filtro de ar - inspecao',                     'visual',        'Limpar se necessario', false, false FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 4,  'Motor',         'Vela de ignicao - inspecao',                  'medicao',       m.gap_vela, false, true FROM revisoes r JOIN modelos m ON m.id = r.modelo_id WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 5,  'Transmissao',   'Corrente - limpeza, lubrificacao, ajuste',    'lubrificacao',  'Folga 20-30 mm', false, true FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 6,  'Freios',        'Pastilhas dianteiras - espessura',            'medicao',       'Minimo 1,5 mm', false, true FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 7,  'Freios',        'Pastilhas traseiras - espessura',             'medicao',       'Minimo 1,5 mm', false, true FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 8,  'Freios',        'Fluido de freio - nivel e coloracao',         'visual',        'DOT 4 - dianteiro e traseiro', false, false FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 9,  'Transmissao',   'Embreagem - folga da alavanca',               'medicao',       '10-15 mm', false, true FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 10, 'Eletrica',      'Bateria - terminais e tensao',                'medicao',       'Tensao > 12,4 V', false, true FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 11, 'Motor',         'Mangueiras EVAP (emissoes evaporativas)',     'visual',        'Sem rachaduras ou vazamentos', false, false FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 12, 'Suspensao',     'Suspensao dianteira - vazamentos no garfo',   'visual',        'Sem vazamento nos retentores', false, false FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 13, 'Suspensao',     'Suspensao traseira - amortecedores',          'visual',        'Sem vazamento', false, false FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 14, 'Pneus',         'Pressao, desgaste e padrao',                  'medicao',       'Conforme adesivo do chassi', false, true FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 15, 'Eletrica',      'Farois, lanterna, setas, luz de freio',       'visual',        'Funcionamento integral', false, false FROM revisoes r WHERE r.km IN (5000, 15000, 25000) UNION ALL
SELECT r.id, 16, 'Geral',         'Teste de rodagem',                            'visual',        'Sem ruidos anormais', false, false FROM revisoes r WHERE r.km IN (5000, 15000, 25000);

-- ---------------------------------------------------------------------
-- 10000 / 30000 km - REVISOES INTERMEDIARIAS
-- ---------------------------------------------------------------------
INSERT INTO itens_checklist (revisao_id, ordem, categoria, descricao, tipo_verificacao, valor_referencia, exige_foto, exige_medicao)
SELECT r.id, 1,  'Motor',         'Troca de oleo do motor',                      'troca',         m.volume_oleo || ' L ' || m.tipo_oleo, true, false FROM revisoes r JOIN modelos m ON m.id = r.modelo_id WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 2,  'Motor',         'Troca de filtro de oleo',                     'troca',         'Filtro original RE', true, false FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 3,  'Motor',         'Folga de valvulas - inspecao/ajuste',         'ajuste',        'Conforme manual', false, true FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 4,  'Motor',         'Filtro de ar - limpeza',                      'lubrificacao',  'Limpar com ar comprimido baixa pressao', true, false FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 5,  'Motor',         'Vela de ignicao - inspecao/substituicao',     'medicao',       m.gap_vela, false, true FROM revisoes r JOIN modelos m ON m.id = r.modelo_id WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 6,  'Transmissao',   'Corrente - limpeza, lubrificacao, ajuste',    'lubrificacao',  'Folga 20-30 mm', false, true FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 7,  'Transmissao',   'Coroa e pinhao - desgaste',                   'visual',        'Sem desgaste anormal nos dentes', true, false FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 8,  'Transmissao',   'Cush rubbers (cubo traseiro)',                'visual',        'Sem folga ou desgaste', false, false FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 9,  'Freios',        'Pastilhas dianteiras - espessura',            'medicao',       'Minimo 1,5 mm', false, true FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 10, 'Freios',        'Pastilhas traseiras - espessura',             'medicao',       'Minimo 1,5 mm', false, true FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 11, 'Freios',        'Fluido de freio - nivel e coloracao',         'visual',        'DOT 4', false, false FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 12, 'Freios',        'Discos de freio - espessura',                 'medicao',       'Conforme manual', false, true FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 13, 'Transmissao',   'Embreagem - folga da alavanca',               'medicao',       '10-15 mm', false, true FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 14, 'Eletrica',      'Bateria - terminais e tensao',                'medicao',       'Tensao > 12,4 V', false, true FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 15, 'Motor',         'Mangueiras EVAP',                             'visual',        'Sem rachaduras', false, false FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 16, 'Suspensao',     'Suspensao dianteira - vazamentos',            'visual',        'Sem vazamento nos retentores', false, false FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 17, 'Suspensao',     'Rolamentos de direcao',                       'visual',        'Sem folga ao virar guidao', false, false FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 18, 'Suspensao',     'Rolamentos das rodas',                        'visual',        'Sem folga ou ruido', false, false FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 19, 'Pneus',         'Pressao, desgaste e padrao',                  'medicao',       'Conforme adesivo do chassi', false, true FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 20, 'Eletrica',      'Farois, lanterna, setas, luz de freio',       'visual',        'Funcionamento integral', false, false FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 21, 'Geral',         'Conferencia de torques de fixacao',           'ajuste',        'Conforme manual', false, false FROM revisoes r WHERE r.km IN (10000, 30000) UNION ALL
SELECT r.id, 22, 'Geral',         'Teste de rodagem',                            'visual',        'Sem ruidos anormais', false, false FROM revisoes r WHERE r.km IN (10000, 30000);

-- ---------------------------------------------------------------------
-- 20000 km - REVISAO PESADA (major service)
-- ---------------------------------------------------------------------
INSERT INTO itens_checklist (revisao_id, ordem, categoria, descricao, tipo_verificacao, valor_referencia, exige_foto, exige_medicao)
SELECT r.id, 1,  'Motor',         'Troca de oleo do motor',                      'troca',         m.volume_oleo || ' L ' || m.tipo_oleo, true, false FROM revisoes r JOIN modelos m ON m.id = r.modelo_id WHERE r.km = 20000 UNION ALL
SELECT r.id, 2,  'Motor',         'Troca de filtro de oleo',                     'troca',         'Filtro original RE', true, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 3,  'Motor',         'Filtro de ar - SUBSTITUICAO',                 'troca',         'Filtro novo original', true, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 4,  'Motor',         'Velas de ignicao - SUBSTITUICAO (par)',       'troca',         m.gap_vela || ' (novas)', true, true FROM revisoes r JOIN modelos m ON m.id = r.modelo_id WHERE r.km = 20000 UNION ALL
SELECT r.id, 5,  'Motor',         'Ajuste de folga de valvulas',                 'ajuste',        'Conforme manual', false, true FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 6,  'Freios',        'Fluido de freio - SUBSTITUICAO',              'troca',         'DOT 4 novo - dianteiro e traseiro', true, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 7,  'Suspensao',     'Oleo do garfo dianteiro - SUBSTITUICAO',      'troca',         'Conforme manual (viscosidade especifica)', true, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 8,  'Transmissao',   'Cabos embreagem/acelerador - avaliacao',      'visual',        'Substituir se ressecados', false, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 9,  'Motor',         'Mangueiras de combustivel - inspecao',        'visual',        'Sem rachaduras', false, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 10, 'Motor',         'Mangueiras EVAP - inspecao',                  'visual',        'Sem rachaduras', false, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 11, 'Transmissao',   'Kit relacao - corrente, coroa, pinhao',       'visual',        'Substituir se desgaste avancado', true, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 12, 'Transmissao',   'Cush rubbers (cubo traseiro)',                'visual',        'Sem folga', false, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 13, 'Freios',        'Pastilhas dianteiras - espessura',            'medicao',       'Substituir se < 1,5 mm', false, true FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 14, 'Freios',        'Pastilhas traseiras - espessura',             'medicao',       'Substituir se < 1,5 mm', false, true FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 15, 'Freios',        'Discos de freio - espessura',                 'medicao',       'Conforme manual', false, true FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 16, 'Suspensao',     'Rolamentos de direcao',                       'visual',        'Sem folga', false, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 17, 'Suspensao',     'Rolamentos das rodas',                        'visual',        'Sem folga ou ruido', false, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 18, 'Eletrica',      'Bateria - tensao e capacidade',               'medicao',       'Tensao > 12,4 V; substituir se < 12,0 V', false, true FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 19, 'Eletrica',      'Sistema de carga (alternador/regulador)',     'medicao',       '13,5-14,5 V em 3000 rpm', false, true FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 20, 'Eletrica',      'Farois, lanterna, setas, luz de freio',       'visual',        'Funcionamento integral', false, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 21, 'Pneus',         'Pressao, desgaste e padrao',                  'medicao',       'Substituir se TWI atingido', false, true FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 22, 'Geral',         'Conferencia de torques de fixacao',           'ajuste',        'Conforme manual', false, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 23, 'Geral',         'Diagnostico eletronico (scanner OBD)',        'medicao',       'Sem codigos de falha', true, false FROM revisoes r WHERE r.km = 20000 UNION ALL
SELECT r.id, 24, 'Geral',         'Teste de rodagem completo',                   'visual',        'Sem ruidos anormais', false, false FROM revisoes r WHERE r.km = 20000;

-- =====================================================================
-- 4. ESTATISTICAS DE VERIFICACAO (apos executar)
-- =====================================================================
-- Voce pode rodar essas queries para validar:
-- SELECT COUNT(*) FROM modelos;                        -- esperado: 10
-- SELECT COUNT(*) FROM revisoes;                       -- esperado: 70 (10 modelos x 7 revisoes)
-- SELECT COUNT(*) FROM itens_checklist;                -- esperado: 1300 (130 por modelo x 10 modelos)
-- SELECT r.km, COUNT(i.id) FROM revisoes r
--   JOIN itens_checklist i ON i.revisao_id = r.id
--   WHERE r.modelo_id = 1 GROUP BY r.km ORDER BY r.km;
-- Esperado: 500=14, 5000=16, 10000=22, 15000=16, 20000=24, 25000=16, 30000=22
