-- =====================================================================
-- REVISAO-MOTO :: Migration Fase 8 (P1) - Operacao Real
-- =====================================================================
-- 1. Medicao numerica com limites (semaforo + taxa de desgaste)
-- 2. Queixa do cliente + resolucao
-- 3. Itens avulsos fora do checklist
-- 4. Pecas e orcamento (+ assinatura de aprovacao previa)
--
-- Idempotente: pode rodar multiplas vezes sem erro.
-- =====================================================================


-- =====================================================================
-- BLOCO 1 :: MEDICAO NUMERICA COM LIMITES
-- =====================================================================

ALTER TABLE itens_checklist ADD COLUMN IF NOT EXISTS unidade        TEXT;
ALTER TABLE itens_checklist ADD COLUMN IF NOT EXISTS limite_minimo  NUMERIC;
ALTER TABLE itens_checklist ADD COLUMN IF NOT EXISTS limite_maximo  NUMERIC;
ALTER TABLE itens_checklist ADD COLUMN IF NOT EXISTS alerta_em      NUMERIC;
ALTER TABLE itens_checklist ADD COLUMN IF NOT EXISTS chave_medicao  TEXT;

COMMENT ON COLUMN itens_checklist.unidade       IS 'mm, V, bar, Nm, psi, L';
COMMENT ON COLUMN itens_checklist.limite_minimo IS 'Limite de servico (abaixo disso: reprovado)';
COMMENT ON COLUMN itens_checklist.limite_maximo IS 'Valor nominal de fabrica (novo)';
COMMENT ON COLUMN itens_checklist.alerta_em     IS 'Faixa amarela: proximo do limite, planejar troca';
COMMENT ON COLUMN itens_checklist.chave_medicao IS
    'Identificador ESTAVEL do mesmo item fisico entre revisoes diferentes. '
    'Necessario porque a descricao varia: "Inspecao de pastilhas dianteiras" (500km) '
    'vs "Pastilhas dianteiras - espessura" (5000km+). Sem isso a taxa de desgaste nao casa.';

CREATE INDEX IF NOT EXISTS idx_itens_chave_medicao ON itens_checklist(chave_medicao)
    WHERE chave_medicao IS NOT NULL;

ALTER TABLE inspecoes_itens ADD COLUMN IF NOT EXISTS valor_numerico NUMERIC;
COMMENT ON COLUMN inspecoes_itens.valor_numerico IS 'Medicao em formato numerico (paralelo a valor_medido TEXT)';

CREATE INDEX IF NOT EXISTS idx_inspecoes_itens_valor_num
    ON inspecoes_itens(item_id, valor_numerico)
    WHERE valor_numerico IS NOT NULL;


-- ---------------------------------------------------------------------
-- SEED: extrai limites dos valor_referencia textuais existentes
-- ---------------------------------------------------------------------

-- Padrao A: faixa "X-Y mm"  (ex: '10-15 mm', '0,7-0,8 mm', 'Folga 20-30 mm')
UPDATE itens_checklist SET
    unidade       = 'mm',
    limite_minimo = replace((regexp_match(valor_referencia, '(\d+[,.]?\d*)\s*-\s*(\d+[,.]?\d*)\s*mm'))[1], ',', '.')::NUMERIC,
    limite_maximo = replace((regexp_match(valor_referencia, '(\d+[,.]?\d*)\s*-\s*(\d+[,.]?\d*)\s*mm'))[2], ',', '.')::NUMERIC
WHERE valor_referencia ~ '\d+[,.]?\d*\s*-\s*\d+[,.]?\d*\s*mm'
  AND limite_minimo IS NULL;

-- Padrao B: minimo "minima X mm" / "Minimo X mm" / "< X mm"
UPDATE itens_checklist SET
    unidade       = 'mm',
    limite_minimo = replace((regexp_match(valor_referencia, '(?:minim[ao]|<)\s*(\d+[,.]?\d*)\s*mm', 'i'))[1], ',', '.')::NUMERIC,
    alerta_em     = replace((regexp_match(valor_referencia, '(?:minim[ao]|<)\s*(\d+[,.]?\d*)\s*mm', 'i'))[1], ',', '.')::NUMERIC * 1.35
WHERE valor_referencia ~* '(?:minim[ao]|<)\s*\d+[,.]?\d*\s*mm'
  AND limite_minimo IS NULL;

-- Padrao C: tensao "> X V"
UPDATE itens_checklist SET
    unidade       = 'V',
    limite_minimo = replace((regexp_match(valor_referencia, '>\s*(\d+[,.]?\d*)\s*V'))[1], ',', '.')::NUMERIC,
    alerta_em     = replace((regexp_match(valor_referencia, '>\s*(\d+[,.]?\d*)\s*V'))[1], ',', '.')::NUMERIC * 1.02
WHERE valor_referencia ~ '>\s*\d+[,.]?\d*\s*V'
  AND limite_minimo IS NULL;

-- Padrao D: faixa de tensao "X-Y V" (ex: '13,5-14,5 V em 3000 rpm')
UPDATE itens_checklist SET
    unidade       = 'V',
    limite_minimo = replace((regexp_match(valor_referencia, '(\d+[,.]?\d*)\s*-\s*(\d+[,.]?\d*)\s*V'))[1], ',', '.')::NUMERIC,
    limite_maximo = replace((regexp_match(valor_referencia, '(\d+[,.]?\d*)\s*-\s*(\d+[,.]?\d*)\s*V'))[2], ',', '.')::NUMERIC
WHERE valor_referencia ~ '\d+[,.]?\d*\s*-\s*\d+[,.]?\d*\s*V'
  AND limite_minimo IS NULL;

-- Padrao E: pressao em psi (pneus) - faixa ampla, so registra unidade
UPDATE itens_checklist SET
    unidade       = 'psi',
    limite_minimo = 28,
    limite_maximo = 40,
    alerta_em     = 30
WHERE valor_referencia ~* 'psi'
  AND limite_minimo IS NULL;


-- ---------------------------------------------------------------------
-- SEED: chave_medicao (identificador estavel entre revisoes)
-- ---------------------------------------------------------------------
-- A descricao do mesmo item fisico muda de uma revisao para outra.
-- Sem uma chave estavel, taxa_desgaste() nao consegue comparar medicoes
-- de revisoes diferentes - que eh exatamente o caso de uso principal.

UPDATE itens_checklist SET chave_medicao = 'pastilha_dianteira'
WHERE descricao ~* 'pastilhas?\s+dianteiras?' AND chave_medicao IS NULL;

UPDATE itens_checklist SET chave_medicao = 'pastilha_traseira'
WHERE descricao ~* 'pastilhas?\s+traseiras?' AND chave_medicao IS NULL;

UPDATE itens_checklist SET chave_medicao = 'corrente_folga'
WHERE descricao ~* 'corrente' AND unidade = 'mm' AND chave_medicao IS NULL;

UPDATE itens_checklist SET chave_medicao = 'vela_folga'
WHERE descricao ~* 'vela' AND unidade = 'mm' AND chave_medicao IS NULL;

UPDATE itens_checklist SET chave_medicao = 'embreagem_folga'
WHERE descricao ~* 'embreagem' AND unidade = 'mm' AND chave_medicao IS NULL;

UPDATE itens_checklist SET chave_medicao = 'bateria_tensao'
WHERE descricao ~* 'bateria' AND unidade = 'V' AND chave_medicao IS NULL;

UPDATE itens_checklist SET chave_medicao = 'alternador_tensao'
WHERE valor_referencia ~* 'rpm' AND unidade = 'V' AND chave_medicao IS NULL;

UPDATE itens_checklist SET chave_medicao = 'pneu_pressao'
WHERE unidade = 'psi' AND chave_medicao IS NULL;


-- ---------------------------------------------------------------------
-- FUNCAO: avalia uma medicao e devolve o semaforo
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION avaliar_medicao(p_item_id INT, p_valor NUMERIC)
RETURNS TABLE(
    semaforo    TEXT,      -- 'verde' | 'amarelo' | 'vermelho' | 'sem_limite'
    mensagem    TEXT,
    unidade     TEXT,
    lim_min     NUMERIC,
    lim_max     NUMERIC
) AS $$
DECLARE
    v_ic itens_checklist%ROWTYPE;
BEGIN
    SELECT * INTO v_ic FROM itens_checklist WHERE id = p_item_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 'sem_limite'::TEXT, 'Item nao encontrado'::TEXT,
                            NULL::TEXT, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END IF;

    IF v_ic.limite_minimo IS NULL AND v_ic.limite_maximo IS NULL THEN
        RETURN QUERY SELECT 'sem_limite'::TEXT, 'Item sem limite numerico cadastrado'::TEXT,
                            v_ic.unidade, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END IF;

    IF p_valor IS NULL THEN
        RETURN QUERY SELECT 'sem_limite'::TEXT, 'Medicao nao informada'::TEXT,
                            v_ic.unidade, v_ic.limite_minimo, v_ic.limite_maximo;
        RETURN;
    END IF;

    -- Abaixo do limite de servico
    IF v_ic.limite_minimo IS NOT NULL AND p_valor < v_ic.limite_minimo THEN
        RETURN QUERY SELECT 'vermelho'::TEXT,
            format('Abaixo do limite de servico (%s %s)', v_ic.limite_minimo, COALESCE(v_ic.unidade,'')),
            v_ic.unidade, v_ic.limite_minimo, v_ic.limite_maximo;
        RETURN;
    END IF;

    -- Acima do maximo admissivel
    IF v_ic.limite_maximo IS NOT NULL AND p_valor > v_ic.limite_maximo THEN
        RETURN QUERY SELECT 'vermelho'::TEXT,
            format('Acima do maximo admissivel (%s %s)', v_ic.limite_maximo, COALESCE(v_ic.unidade,'')),
            v_ic.unidade, v_ic.limite_minimo, v_ic.limite_maximo;
        RETURN;
    END IF;

    -- Faixa de alerta
    IF v_ic.alerta_em IS NOT NULL AND p_valor <= v_ic.alerta_em THEN
        RETURN QUERY SELECT 'amarelo'::TEXT,
            'Proximo do limite - planejar substituicao'::TEXT,
            v_ic.unidade, v_ic.limite_minimo, v_ic.limite_maximo;
        RETURN;
    END IF;

    RETURN QUERY SELECT 'verde'::TEXT, 'Dentro da especificacao'::TEXT,
                        v_ic.unidade, v_ic.limite_minimo, v_ic.limite_maximo;
END;
$$ LANGUAGE plpgsql STABLE;


-- ---------------------------------------------------------------------
-- FUNCAO: taxa de desgaste de um item para uma moto
-- ---------------------------------------------------------------------
-- Casa medicoes pela chave_medicao (estavel entre revisoes), NAO pela
-- descricao, que muda de uma revisao para outra.
CREATE OR REPLACE FUNCTION taxa_desgaste(p_moto_id INT, p_chave TEXT)
RETURNS TABLE(
    medicao_anterior   NUMERIC,
    km_anterior        INT,
    medicao_atual      NUMERIC,
    km_atual           INT,
    desgaste_por_1000km NUMERIC,
    km_restantes       INT,
    previsao_troca_km  INT,
    unidade            TEXT,
    limite_minimo      NUMERIC
) AS $$
DECLARE
    v_ant RECORD;
    v_atu RECORD;
    v_taxa NUMERIC;
    v_restante NUMERIC;
BEGIN
    -- Medicao mais recente desta chave nesta moto
    SELECT ii.valor_numerico AS valor, i.km_registrado AS km,
           ic.limite_minimo AS lim, ic.unidade AS uni
    INTO v_atu
    FROM inspecoes_itens ii
    JOIN inspecoes i        ON i.id = ii.inspecao_id
    JOIN itens_checklist ic ON ic.id = ii.item_id
    WHERE i.moto_id = p_moto_id
      AND ic.chave_medicao = p_chave
      AND ii.valor_numerico IS NOT NULL
      AND i.status = 'finalizada'
    ORDER BY i.km_registrado DESC
    LIMIT 1;

    IF NOT FOUND THEN RETURN; END IF;

    -- Medicao imediatamente anterior
    SELECT ii.valor_numerico AS valor, i.km_registrado AS km
    INTO v_ant
    FROM inspecoes_itens ii
    JOIN inspecoes i        ON i.id = ii.inspecao_id
    JOIN itens_checklist ic ON ic.id = ii.item_id
    WHERE i.moto_id = p_moto_id
      AND ic.chave_medicao = p_chave
      AND ii.valor_numerico IS NOT NULL
      AND i.status = 'finalizada'
      AND i.km_registrado < v_atu.km
    ORDER BY i.km_registrado DESC
    LIMIT 1;

    IF NOT FOUND OR v_atu.km = v_ant.km THEN RETURN; END IF;

    -- Desgaste por 1000 km (positivo = valor esta diminuindo)
    v_taxa := (v_ant.valor - v_atu.valor) * 1000.0 / (v_atu.km - v_ant.km);

    IF v_taxa > 0 AND v_atu.lim IS NOT NULL THEN
        v_restante := GREATEST(0, ROUND((v_atu.valor - v_atu.lim) * 1000.0 / v_taxa));
    ELSE
        v_restante := NULL;
    END IF;

    RETURN QUERY SELECT
        v_ant.valor,
        v_ant.km::INT,
        v_atu.valor,
        v_atu.km::INT,
        ROUND(v_taxa, 4),
        v_restante::INT,
        CASE WHEN v_restante IS NOT NULL THEN (v_atu.km + v_restante)::INT ELSE NULL END,
        v_atu.uni,
        v_atu.lim;
END;
$$ LANGUAGE plpgsql STABLE;


-- ---------------------------------------------------------------------
-- VIEW: recomendacoes futuras (itens proximos do limite, com previsao)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_recomendacoes_futuras AS
WITH ultima_medicao AS (
    SELECT DISTINCT ON (i.moto_id, ic.chave_medicao)
        i.moto_id,
        ic.chave_medicao,
        ic.descricao,
        ic.unidade,
        ic.limite_minimo,
        ic.alerta_em,
        ii.valor_numerico,
        i.km_registrado
    FROM inspecoes_itens ii
    JOIN inspecoes i        ON i.id = ii.inspecao_id
    JOIN itens_checklist ic ON ic.id = ii.item_id
    WHERE ii.valor_numerico IS NOT NULL
      AND ic.chave_medicao IS NOT NULL
      AND i.status = 'finalizada'
    ORDER BY i.moto_id, ic.chave_medicao, i.km_registrado DESC
)
SELECT
    um.moto_id,
    mo.placa,
    um.chave_medicao,
    um.descricao,
    um.valor_numerico    AS ultima_medicao,
    um.unidade,
    um.limite_minimo,
    um.km_registrado     AS km_da_medicao,
    td.desgaste_por_1000km,
    td.km_restantes,
    td.previsao_troca_km,
    CASE
        WHEN um.limite_minimo IS NOT NULL AND um.valor_numerico < um.limite_minimo THEN 'trocar_agora'
        WHEN um.alerta_em     IS NOT NULL AND um.valor_numerico <= um.alerta_em    THEN 'planejar_troca'
        ELSE 'ok'
    END AS recomendacao
FROM ultima_medicao um
JOIN motos mo ON mo.id = um.moto_id
LEFT JOIN LATERAL taxa_desgaste(um.moto_id, um.chave_medicao) td ON TRUE
WHERE mo.ativo = TRUE;


-- =====================================================================
-- BLOCO 2 :: QUEIXA DO CLIENTE + RESOLUCAO
-- =====================================================================

ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS queixa_cliente    TEXT;
ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS resolucao_queixa  TEXT;

COMMENT ON COLUMN inspecoes.queixa_cliente   IS 'Relato do cliente na abertura (motivo real da visita)';
COMMENT ON COLUMN inspecoes.resolucao_queixa IS 'O que o mecanico encontrou e fez sobre a queixa';


-- =====================================================================
-- BLOCO 3 :: ITENS AVULSOS FORA DO CHECKLIST
-- =====================================================================

ALTER TABLE inspecoes_itens ALTER COLUMN item_id DROP NOT NULL;
ALTER TABLE inspecoes_itens ADD COLUMN IF NOT EXISTS descricao_avulsa TEXT;
ALTER TABLE inspecoes_itens ADD COLUMN IF NOT EXISTS categoria_avulsa TEXT;

COMMENT ON COLUMN inspecoes_itens.descricao_avulsa IS 'Descricao quando item_id IS NULL (achado fora do checklist)';

-- Garante que ou eh item do catalogo, ou eh avulso com descricao
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_item_ou_avulso') THEN
        ALTER TABLE inspecoes_itens ADD CONSTRAINT chk_item_ou_avulso
            CHECK (item_id IS NOT NULL OR (descricao_avulsa IS NOT NULL AND descricao_avulsa <> ''));
    END IF;
END $$;

-- A UNIQUE(inspecao_id, item_id) original ja permite multiplos NULL em Postgres,
-- entao varios avulsos na mesma inspecao convivem sem conflito.


-- =====================================================================
-- BLOCO 4 :: PECAS E ORCAMENTO
-- =====================================================================

CREATE TABLE IF NOT EXISTS pecas (
    id              SERIAL PRIMARY KEY,
    codigo_re       TEXT,
    descricao       TEXT NOT NULL,
    preco_unitario  NUMERIC(10,2) NOT NULL DEFAULT 0,
    modelo_id       INT REFERENCES modelos(id),   -- NULL = serve a todos
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em       TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em   TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE pecas IS 'Catalogo de pecas com preco de referencia';

CREATE INDEX IF NOT EXISTS idx_pecas_modelo   ON pecas(modelo_id) WHERE ativo = TRUE;
CREATE INDEX IF NOT EXISTS idx_pecas_codigo   ON pecas(codigo_re);

CREATE TABLE IF NOT EXISTS inspecao_pecas (
    id              SERIAL PRIMARY KEY,
    inspecao_id     UUID NOT NULL REFERENCES inspecoes(id) ON DELETE CASCADE,
    item_id         INT REFERENCES itens_checklist(id),  -- item que motivou (opcional)
    peca_id         INT REFERENCES pecas(id),
    descricao_livre TEXT,                                -- peca fora do catalogo
    quantidade      NUMERIC(10,2) NOT NULL DEFAULT 1,
    preco_aplicado  NUMERIC(10,2) NOT NULL DEFAULT 0,
    criado_em       TIMESTAMPTZ DEFAULT NOW(),
    CHECK (peca_id IS NOT NULL OR (descricao_livre IS NOT NULL AND descricao_livre <> ''))
);
COMMENT ON TABLE inspecao_pecas IS 'Pecas usadas/orcadas em uma inspecao';

CREATE INDEX IF NOT EXISTS idx_inspecao_pecas_insp ON inspecao_pecas(inspecao_id);

CREATE TABLE IF NOT EXISTS inspecao_servicos (
    id              SERIAL PRIMARY KEY,
    inspecao_id     UUID NOT NULL REFERENCES inspecoes(id) ON DELETE CASCADE,
    descricao       TEXT NOT NULL,
    horas           NUMERIC(6,2) NOT NULL DEFAULT 0,
    valor_hora      NUMERIC(10,2) NOT NULL DEFAULT 0,
    criado_em       TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE inspecao_servicos IS 'Mao de obra orcada/executada em uma inspecao';

CREATE INDEX IF NOT EXISTS idx_inspecao_servicos_insp ON inspecao_servicos(inspecao_id);

-- Assinatura de aprovacao previa do orcamento (CDC art. 40)
ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS assinatura_orcamento    TEXT;
ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS nome_aprovador_orcamento TEXT;
ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS orcamento_aprovado_em   TIMESTAMPTZ;

COMMENT ON COLUMN inspecoes.assinatura_orcamento IS 'Base64 PNG - aprovacao PREVIA do orcamento (distinta da conclusao)';


-- ---------------------------------------------------------------------
-- VIEW: total do orcamento por inspecao
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_orcamento_inspecao AS
SELECT
    i.id                                                  AS inspecao_id,
    COALESCE(p.total_pecas, 0)                            AS total_pecas,
    COALESCE(s.total_servicos, 0)                         AS total_servicos,
    COALESCE(p.total_pecas, 0) + COALESCE(s.total_servicos, 0) AS total_geral,
    COALESCE(p.qtd_itens, 0)                              AS qtd_pecas,
    COALESCE(s.qtd_itens, 0)                              AS qtd_servicos,
    COALESCE(s.total_horas, 0)                            AS total_horas,
    (i.assinatura_orcamento IS NOT NULL
     AND LENGTH(i.assinatura_orcamento) > 100)            AS orcamento_aprovado,
    i.orcamento_aprovado_em,
    i.nome_aprovador_orcamento
FROM inspecoes i
LEFT JOIN (
    SELECT inspecao_id,
           SUM(quantidade * preco_aplicado) AS total_pecas,
           COUNT(*)                         AS qtd_itens
    FROM inspecao_pecas GROUP BY inspecao_id
) p ON p.inspecao_id = i.id
LEFT JOIN (
    SELECT inspecao_id,
           SUM(horas * valor_hora) AS total_servicos,
           SUM(horas)              AS total_horas,
           COUNT(*)                AS qtd_itens
    FROM inspecao_servicos GROUP BY inspecao_id
) s ON s.inspecao_id = i.id;


-- ---------------------------------------------------------------------
-- VIEW: itens da inspecao unificados (catalogo + avulsos + semaforo)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_inspecao_itens_completo AS
SELECT
    ii.id,
    ii.inspecao_id,
    ii.item_id,
    (ii.item_id IS NULL)                                      AS eh_avulso,
    COALESCE(ic.descricao, ii.descricao_avulsa)               AS descricao,
    COALESCE(ic.categoria,  ii.categoria_avulsa, 'Adicional') AS categoria,
    ic.ordem,
    ii.status,
    ii.valor_medido,
    ii.valor_numerico,
    ic.unidade,
    ic.limite_minimo,
    ic.limite_maximo,
    ic.alerta_em,
    CASE
        WHEN ii.valor_numerico IS NULL THEN 'sem_limite'
        WHEN ic.limite_minimo IS NULL AND ic.limite_maximo IS NULL THEN 'sem_limite'
        WHEN ic.limite_minimo IS NOT NULL AND ii.valor_numerico < ic.limite_minimo THEN 'vermelho'
        WHEN ic.limite_maximo IS NOT NULL AND ii.valor_numerico > ic.limite_maximo THEN 'vermelho'
        WHEN ic.alerta_em    IS NOT NULL AND ii.valor_numerico <= ic.alerta_em     THEN 'amarelo'
        ELSE 'verde'
    END                                                        AS semaforo,
    ii.observacao,
    ii.foto_url,
    ii.verificado_em
FROM inspecoes_itens ii
LEFT JOIN itens_checklist ic ON ic.id = ii.item_id;


-- =====================================================================
-- RLS nas novas tabelas
-- =====================================================================
ALTER TABLE pecas             ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspecao_pecas    ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspecao_servicos ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pecas' AND policyname='auth_all_pecas') THEN
        CREATE POLICY auth_all_pecas ON pecas FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='inspecao_pecas' AND policyname='auth_all_insp_pecas') THEN
        CREATE POLICY auth_all_insp_pecas ON inspecao_pecas FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='inspecao_servicos' AND policyname='auth_all_insp_serv') THEN
        CREATE POLICY auth_all_insp_serv ON inspecao_servicos FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;


-- =====================================================================
-- SEED MINIMO DO CATALOGO DE PECAS (consumiveis comuns Royal Enfield)
-- =====================================================================
INSERT INTO pecas (codigo_re, descricao, preco_unitario, modelo_id)
SELECT * FROM (VALUES
    ('1990328', 'Filtro de oleo - linha 650',            89.90,  NULL::INT),
    ('1990329', 'Filtro de oleo - linha 350',            69.90,  NULL::INT),
    ('1990512', 'Filtro de ar',                         149.90,  NULL::INT),
    ('1990744', 'Vela de ignicao (unidade)',             79.90,  NULL::INT),
    ('OLEO15W50', 'Oleo motor 15W-50 JASO MA2 (litro)',  78.00,  NULL::INT),
    ('DOT4-500', 'Fluido de freio DOT 4 (500ml)',        49.90,  NULL::INT),
    ('PAST-D',  'Pastilha de freio dianteira (par)',    239.90,  NULL::INT),
    ('PAST-T',  'Pastilha de freio traseira (par)',     189.90,  NULL::INT),
    ('KIT-REL', 'Kit relacao (coroa, pinhao, corrente)', 890.00, NULL::INT),
    ('BAT-12',  'Bateria 12V',                          490.00,  NULL::INT)
) AS x(codigo_re, descricao, preco_unitario, modelo_id)
WHERE NOT EXISTS (SELECT 1 FROM pecas p WHERE p.codigo_re = x.codigo_re);

-- Trigger de atualizado_em em pecas
DROP TRIGGER IF EXISTS set_atualizado_em_pecas ON pecas;
CREATE TRIGGER set_atualizado_em_pecas
    BEFORE UPDATE ON pecas
    FOR EACH ROW EXECUTE FUNCTION trigger_set_atualizado_em();


-- =====================================================================
-- ATUALIZA vw_checklist_completo para expor os campos da Fase 8
-- =====================================================================
-- Sem isso o front nao recebe unidade/limites/chave_medicao e o
-- semaforo nao tem contra o que comparar.
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
    i.exige_medicao,
    -- Fase 8
    i.unidade,
    i.limite_minimo,
    i.limite_maximo,
    i.alerta_em,
    i.chave_medicao
FROM modelos m
JOIN revisoes r ON r.modelo_id = m.id
JOIN itens_checklist i ON i.revisao_id = r.id
ORDER BY m.nome, r.km, i.ordem;
