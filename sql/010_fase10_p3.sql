-- =====================================================================
-- REVISAO-MOTO :: Migration Fase 10 (P3) - Media prioridade
-- =====================================================================
-- 10. Comparacao entre revisoes
-- 11. Teste de rodagem estruturado
-- 12. Garantia
-- 13. Torque efetivamente aplicado
-- 14. Revisao rapida vs completa
--
-- Idempotente.
-- =====================================================================


-- =====================================================================
-- BLOCO 10 :: COMPARACAO ENTRE REVISOES
-- =====================================================================
-- A Fase 8 criou taxa_desgaste(), que compara as DUAS ultimas medicoes
-- de um item. Aqui o objetivo eh outro: por uma inspecao inteira lado a
-- lado com a anterior, e ver a serie historica completa de um item.

-- ---------------------------------------------------------------------
-- FUNCAO: compara duas inspecoes da mesma moto, item a item
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION comparar_inspecoes(p_inspecao_a UUID, p_inspecao_b UUID)
RETURNS TABLE(
    chave_medicao   TEXT,
    descricao       TEXT,
    categoria       TEXT,
    unidade         TEXT,
    valor_a         NUMERIC,
    valor_b         NUMERIC,
    delta           NUMERIC,
    delta_pct       NUMERIC,
    tendencia       TEXT,       -- 'piorou' | 'melhorou' | 'estavel' | 'novo'
    limite_minimo   NUMERIC,
    semaforo_b      TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH a AS (
        SELECT ic.chave_medicao AS ch, ii.valor_numerico AS v
        FROM inspecoes_itens ii
        JOIN itens_checklist ic ON ic.id = ii.item_id
        WHERE ii.inspecao_id = p_inspecao_a
          AND ii.valor_numerico IS NOT NULL
          AND ic.chave_medicao IS NOT NULL
    ),
    b AS (
        SELECT ic.chave_medicao AS ch, ii.valor_numerico AS v,
               ic.descricao AS d, ic.categoria AS c, ic.unidade AS u,
               ic.limite_minimo AS lmin, ic.limite_maximo AS lmax, ic.alerta_em AS al
        FROM inspecoes_itens ii
        JOIN itens_checklist ic ON ic.id = ii.item_id
        WHERE ii.inspecao_id = p_inspecao_b
          AND ii.valor_numerico IS NOT NULL
          AND ic.chave_medicao IS NOT NULL
    )
    SELECT
        b.ch,
        b.d,
        b.c,
        b.u,
        a.v,
        b.v,
        CASE WHEN a.v IS NULL THEN NULL ELSE ROUND(b.v - a.v, 4) END,
        CASE WHEN a.v IS NULL OR a.v = 0 THEN NULL
             ELSE ROUND((b.v - a.v) * 100.0 / ABS(a.v), 1) END,
        CASE
            WHEN a.v IS NULL            THEN 'novo'
            WHEN ABS(b.v - a.v) < 0.001 THEN 'estavel'

            -- Item de FAIXA (tem min e max): o bom eh estar no meio.
            -- Ex: folga de corrente 20-30mm. Sair de 25 para 28 nao eh
            -- "melhorar", eh se afastar do centro.
            WHEN b.lmin IS NOT NULL AND b.lmax IS NOT NULL THEN
                CASE
                    WHEN ABS(b.v - (b.lmin + b.lmax)/2) > ABS(a.v - (b.lmin + b.lmax)/2)
                        THEN 'piorou'
                    ELSE 'melhorou'
                END

            -- Item de DESGASTE (so min): cair eh piorar.
            -- Ex: pastilha com minimo de 1,5mm.
            WHEN b.lmin IS NOT NULL THEN
                CASE WHEN b.v < a.v THEN 'piorou' ELSE 'melhorou' END

            -- Item de TETO (so max): subir eh piorar.
            WHEN b.lmax IS NOT NULL THEN
                CASE WHEN b.v > a.v THEN 'piorou' ELSE 'melhorou' END

            ELSE 'estavel'
        END,
        b.lmin,
        CASE
            WHEN b.lmin IS NULL AND b.lmax IS NULL        THEN 'sem_limite'
            WHEN b.lmin IS NOT NULL AND b.v < b.lmin      THEN 'vermelho'
            WHEN b.lmax IS NOT NULL AND b.v > b.lmax      THEN 'vermelho'
            WHEN b.al   IS NOT NULL AND b.v <= b.al       THEN 'amarelo'
            ELSE 'verde'
        END
    FROM b
    LEFT JOIN a ON a.ch = b.ch
    ORDER BY b.c, b.d;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION comparar_inspecoes IS
    'Compara duas inspecoes item a item pela chave_medicao. '
    'A inspecao B eh a mais recente; delta positivo = valor subiu.';


-- ---------------------------------------------------------------------
-- FUNCAO: serie historica de um item para uma moto (alimenta o grafico)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION historico_medicao(p_moto_id INT, p_chave TEXT)
RETURNS TABLE(
    inspecao_id     UUID,
    numero_os       TEXT,
    data_fim        TIMESTAMPTZ,
    km_registrado   INT,
    valor           NUMERIC,
    unidade         TEXT,
    limite_minimo   NUMERIC,
    semaforo        TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        i.id,
        i.numero_os,
        i.data_fim,
        i.km_registrado,
        ii.valor_numerico,
        ic.unidade,
        ic.limite_minimo,
        CASE
            WHEN ic.limite_minimo IS NULL AND ic.limite_maximo IS NULL     THEN 'sem_limite'
            WHEN ic.limite_minimo IS NOT NULL
                 AND ii.valor_numerico < ic.limite_minimo                  THEN 'vermelho'
            WHEN ic.limite_maximo IS NOT NULL
                 AND ii.valor_numerico > ic.limite_maximo                  THEN 'vermelho'
            WHEN ic.alerta_em IS NOT NULL
                 AND ii.valor_numerico <= ic.alerta_em                     THEN 'amarelo'
            ELSE 'verde'
        END
    FROM inspecoes_itens ii
    JOIN inspecoes i        ON i.id  = ii.inspecao_id
    JOIN itens_checklist ic ON ic.id = ii.item_id
    WHERE i.moto_id = p_moto_id
      AND ic.chave_medicao = p_chave
      AND ii.valor_numerico IS NOT NULL
      AND i.status = 'finalizada'
    ORDER BY i.km_registrado;
END;
$$ LANGUAGE plpgsql STABLE;


-- ---------------------------------------------------------------------
-- VIEW: pares de inspecoes consecutivas (quem comparar com quem)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_inspecoes_comparaveis AS
SELECT
    i.moto_id,
    mo.placa,
    i.id                AS inspecao_atual,
    i.numero_os         AS os_atual,
    i.km_registrado     AS km_atual,
    i.data_fim          AS data_atual,
    LAG(i.id)            OVER w AS inspecao_anterior,
    LAG(i.numero_os)     OVER w AS os_anterior,
    LAG(i.km_registrado) OVER w AS km_anterior,
    LAG(i.data_fim)      OVER w AS data_anterior
FROM inspecoes i
JOIN motos mo ON mo.id = i.moto_id
WHERE i.status = 'finalizada'
WINDOW w AS (PARTITION BY i.moto_id ORDER BY i.km_registrado);


-- =====================================================================
-- BLOCO 11 :: TESTE DE RODAGEM ESTRUTURADO
-- =====================================================================
-- Hoje "Teste de rodagem" eh um item visual unico no seed. Vira um
-- sub-checklist proprio, com condicoes do teste e km percorridos.

CREATE TABLE IF NOT EXISTS rodagem_itens (
    id          SERIAL PRIMARY KEY,
    ordem       INT NOT NULL,
    categoria   TEXT NOT NULL,       -- 'Freios', 'Transmissao', 'Motor', ...
    descricao   TEXT NOT NULL,
    ajuda       TEXT,                -- o que observar
    obrigatorio BOOLEAN NOT NULL DEFAULT TRUE,
    ativo       BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(descricao)
);

COMMENT ON TABLE rodagem_itens IS 'Catalogo de verificacoes do teste de rodagem';

CREATE TABLE IF NOT EXISTS inspecao_rodagem (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inspecao_id        UUID NOT NULL REFERENCES inspecoes(id) ON DELETE CASCADE,
    km_inicial         INT,
    km_final           INT,
    condicao_pista     TEXT,          -- 'seca' | 'molhada' | 'mista'
    observacoes        TEXT,
    piloto_nome        TEXT,
    iniciado_em        TIMESTAMPTZ DEFAULT NOW(),
    finalizado_em      TIMESTAMPTZ,
    UNIQUE(inspecao_id),
    CHECK (condicao_pista IS NULL OR condicao_pista IN ('seca','molhada','mista'))
);

COMMENT ON TABLE inspecao_rodagem IS 'Cabecalho do teste de rodagem de uma inspecao';

CREATE TABLE IF NOT EXISTS inspecao_rodagem_itens (
    id            SERIAL PRIMARY KEY,
    rodagem_id    UUID NOT NULL REFERENCES inspecao_rodagem(id) ON DELETE CASCADE,
    item_id       INT  NOT NULL REFERENCES rodagem_itens(id),
    status        TEXT,              -- 'ok' | 'nao_ok' | 'na'
    observacao    TEXT,
    verificado_em TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(rodagem_id, item_id),
    CHECK (status IS NULL OR status IN ('ok','nao_ok','na'))
);

CREATE INDEX IF NOT EXISTS idx_rodagem_inspecao ON inspecao_rodagem(inspecao_id);
CREATE INDEX IF NOT EXISTS idx_rodagem_itens    ON inspecao_rodagem_itens(rodagem_id);

ALTER TABLE rodagem_itens          ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspecao_rodagem       ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspecao_rodagem_itens ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='rodagem_itens' AND policyname='auth_all_rod_cat') THEN
        CREATE POLICY auth_all_rod_cat ON rodagem_itens FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='inspecao_rodagem' AND policyname='auth_all_rod') THEN
        CREATE POLICY auth_all_rod ON inspecao_rodagem FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='inspecao_rodagem_itens' AND policyname='auth_all_rod_it') THEN
        CREATE POLICY auth_all_rod_it ON inspecao_rodagem_itens FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- Seed do catalogo de rodagem
INSERT INTO rodagem_itens (ordem, categoria, descricao, ajuda, obrigatorio)
SELECT * FROM (VALUES
    (10,  'Freios',      'Frenagem dianteira',            'Firme, sem trepidacao no manete',        TRUE),
    (20,  'Freios',      'Frenagem traseira',             'Sem travar, sem ruido metalico',         TRUE),
    (30,  'Freios',      'Frenagem combinada',            'Moto para reto, sem puxar para um lado', TRUE),
    (40,  'Transmissao', 'Trocas de marcha (subindo)',    'Engate limpo em todas as marchas',       TRUE),
    (50,  'Transmissao', 'Trocas de marcha (reduzindo)',  'Sem pulos ou falsos neutros',            TRUE),
    (60,  'Transmissao', 'Embreagem',                     'Sem patinar em aceleracao forte',        TRUE),
    (70,  'Motor',       'Resposta do acelerador',        'Sem falhas ou hesitacao',                TRUE),
    (80,  'Motor',       'Ruidos anormais',               'Batidas, assobios, estalos',             TRUE),
    (90,  'Motor',       'Temperatura em marcha lenta',   'Ventoinha liga e desliga normalmente',   FALSE),
    (100, 'Eletrica',    'Luzes de advertencia no painel','Nenhuma acesa apos a partida',           TRUE),
    (110, 'Eletrica',    'Indicador de marcha e setas',   'Mostram a marcha certa, setas desligam', FALSE),
    (120, 'Suspensao',   'Comportamento em irregularidade','Sem batida seca ou retorno lento',      TRUE),
    (130, 'Direcao',     'Alinhamento e guidao',          'Moto segue reta com guidao solto',       TRUE),
    (140, 'Geral',       'Vazamentos apos o teste',       'Olhar o chao onde a moto parou',         TRUE)
) AS x(ordem, categoria, descricao, ajuda, obrigatorio)
WHERE NOT EXISTS (SELECT 1 FROM rodagem_itens r WHERE r.descricao = x.descricao);

-- ---------------------------------------------------------------------
-- FUNCAO: progresso e aprovacao do teste de rodagem
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rodagem_completa(p_rodagem_id UUID)
RETURNS TABLE(
    completo        BOOLEAN,
    total_itens     INT,
    preenchidos     INT,
    obrigatorios_pendentes INT,
    reprovados      INT,
    km_percorridos  INT,
    motivo          TEXT
) AS $$
DECLARE
    v_total INT; v_preench INT; v_obrig_pend INT; v_reprov INT; v_km INT;
BEGIN
    SELECT COUNT(*) INTO v_total FROM rodagem_itens WHERE ativo = TRUE;

    SELECT COUNT(*) INTO v_preench
    FROM inspecao_rodagem_itens
    WHERE rodagem_id = p_rodagem_id AND status IN ('ok','nao_ok','na');

    SELECT COUNT(*) INTO v_obrig_pend
    FROM rodagem_itens ri
    LEFT JOIN inspecao_rodagem_itens iri
           ON iri.item_id = ri.id AND iri.rodagem_id = p_rodagem_id
    WHERE ri.ativo = TRUE AND ri.obrigatorio = TRUE
      AND (iri.status IS NULL OR iri.status NOT IN ('ok','nao_ok','na'));

    SELECT COUNT(*) INTO v_reprov
    FROM inspecao_rodagem_itens
    WHERE rodagem_id = p_rodagem_id AND status = 'nao_ok';

    SELECT GREATEST(0, COALESCE(km_final,0) - COALESCE(km_inicial,0)) INTO v_km
    FROM inspecao_rodagem WHERE id = p_rodagem_id;

    RETURN QUERY SELECT
        (v_obrig_pend = 0),
        v_total, v_preench::INT, v_obrig_pend::INT, v_reprov::INT, COALESCE(v_km,0),
        CASE
            WHEN v_obrig_pend > 0 THEN format('%s item(ns) obrigatorio(s) pendente(s)', v_obrig_pend)
            WHEN v_reprov > 0     THEN format('Concluido com %s reprovacao(oes)', v_reprov)
            ELSE 'Teste concluido sem reprovacoes'
        END;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE VIEW vw_rodagem AS
SELECT
    r.id,
    r.inspecao_id,
    i.numero_os,
    i.moto_id,
    mo.placa,
    r.km_inicial,
    r.km_final,
    GREATEST(0, COALESCE(r.km_final,0) - COALESCE(r.km_inicial,0)) AS km_percorridos,
    r.condicao_pista,
    r.piloto_nome,
    r.observacoes,
    r.iniciado_em,
    r.finalizado_em,
    COUNT(iri.id) FILTER (WHERE iri.status IN ('ok','nao_ok','na')) AS preenchidos,
    COUNT(iri.id) FILTER (WHERE iri.status = 'nao_ok')              AS reprovados
FROM inspecao_rodagem r
JOIN inspecoes i ON i.id = r.inspecao_id
JOIN motos mo    ON mo.id = i.moto_id
LEFT JOIN inspecao_rodagem_itens iri ON iri.rodagem_id = r.id
GROUP BY r.id, i.numero_os, i.moto_id, mo.placa;


-- =====================================================================
-- BLOCO 12 :: GARANTIA
-- =====================================================================
-- Quem paga: fabrica, a propria oficina, ou o cliente.
-- Base legal da garantia da oficina: CDC art. 26, II - 90 dias para
-- servico durave, contados da entrega.

ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS tipo_cobranca   TEXT NOT NULL DEFAULT 'pago';
ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS garantia_ate    DATE;
ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS garantia_obs    TEXT;
ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS inspecao_origem UUID REFERENCES inspecoes(id);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_tipo_cobranca') THEN
        ALTER TABLE inspecoes ADD CONSTRAINT chk_tipo_cobranca
            CHECK (tipo_cobranca IN ('pago','garantia_fabrica','garantia_oficina','cortesia'));
    END IF;
END $$;

COMMENT ON COLUMN inspecoes.tipo_cobranca   IS 'pago | garantia_fabrica | garantia_oficina | cortesia';
COMMENT ON COLUMN inspecoes.garantia_ate    IS 'Fim da garantia do servico (CDC art. 26: 90 dias da entrega)';
COMMENT ON COLUMN inspecoes.inspecao_origem IS 'Quando eh retorno em garantia, aponta o servico original';

CREATE INDEX IF NOT EXISTS idx_inspecoes_garantia
    ON inspecoes(moto_id, garantia_ate) WHERE garantia_ate IS NOT NULL;

-- Trigger: ao finalizar um servico pago, abre a garantia de 90 dias
CREATE OR REPLACE FUNCTION trigger_definir_garantia()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'finalizada'
       AND (OLD.status IS DISTINCT FROM 'finalizada')
       AND NEW.garantia_ate IS NULL
       AND NEW.tipo_cobranca IN ('pago','garantia_fabrica') THEN
        NEW.garantia_ate := (COALESCE(NEW.data_fim, NOW())::DATE + INTERVAL '90 days')::DATE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_garantia_ao_finalizar ON inspecoes;
CREATE TRIGGER set_garantia_ao_finalizar
    BEFORE UPDATE ON inspecoes
    FOR EACH ROW EXECUTE FUNCTION trigger_definir_garantia();

-- ---------------------------------------------------------------------
-- FUNCAO: a moto tem servico em garantia vigente?
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION garantia_vigente(p_moto_id INT)
RETURNS TABLE(
    tem_garantia   BOOLEAN,
    inspecao_id    UUID,
    numero_os      TEXT,
    data_servico   TIMESTAMPTZ,
    garantia_ate   DATE,
    dias_restantes INT,
    km_do_servico  INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        TRUE,
        i.id,
        i.numero_os,
        i.data_fim,
        i.garantia_ate,
        (i.garantia_ate - CURRENT_DATE)::INT,
        i.km_registrado
    FROM inspecoes i
    WHERE i.moto_id = p_moto_id
      AND i.status = 'finalizada'
      AND i.garantia_ate IS NOT NULL
      AND i.garantia_ate >= CURRENT_DATE
    ORDER BY i.garantia_ate DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE VIEW vw_garantias_vigentes AS
SELECT
    i.id            AS inspecao_id,
    i.numero_os,
    i.moto_id,
    mo.placa,
    md.nome         AS modelo,
    mo.proprietario,
    mo.telefone,
    i.data_fim      AS data_servico,
    i.km_registrado AS km_servico,
    i.tipo_cobranca,
    i.garantia_ate,
    (i.garantia_ate - CURRENT_DATE)::INT AS dias_restantes,
    mo.km_atual,
    (mo.km_atual - i.km_registrado)      AS km_rodados_desde
FROM inspecoes i
JOIN motos mo   ON mo.id = i.moto_id
JOIN modelos md ON md.id = mo.modelo_id
WHERE i.status = 'finalizada'
  AND i.garantia_ate IS NOT NULL
  AND i.garantia_ate >= CURRENT_DATE
  AND mo.ativo = TRUE
ORDER BY i.garantia_ate;


-- =====================================================================
-- BLOCO 13 :: TORQUE EFETIVAMENTE APLICADO
-- =====================================================================
-- A Fase 7 cadastrou os torques nominais em especificacoes_modelo.
-- Aqui registramos o torque REAL aplicado em cada fixador critico.
-- Blindagem juridica: fica quem apertou, quando, e com que valor.

CREATE TABLE IF NOT EXISTS inspecao_torques (
    id              SERIAL PRIMARY KEY,
    inspecao_id     UUID NOT NULL REFERENCES inspecoes(id) ON DELETE CASCADE,
    fixador         TEXT NOT NULL,          -- casa com especificacoes_modelo.item
    torque_nominal  NUMERIC(6,2),           -- copiado da spec no momento do aperto
    torque_aplicado NUMERIC(6,2) NOT NULL,
    unidade         TEXT NOT NULL DEFAULT 'Nm',
    tolerancia_pct  NUMERIC(4,1) NOT NULL DEFAULT 10.0,
    aplicado_por    TEXT,
    aplicado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    observacao      TEXT,
    UNIQUE(inspecao_id, fixador),
    CHECK (torque_aplicado > 0)
);

COMMENT ON TABLE inspecao_torques IS
    'Torque real aplicado em fixadores criticos. torque_nominal eh COPIADO '
    'da spec no momento do aperto, para o registro nao mudar se a spec for corrigida.';

CREATE INDEX IF NOT EXISTS idx_torques_inspecao ON inspecao_torques(inspecao_id);

ALTER TABLE inspecao_torques ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='inspecao_torques' AND policyname='auth_all_torques') THEN
        CREATE POLICY auth_all_torques ON inspecao_torques FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- FUNCAO: torques nominais de um modelo (le especificacoes_modelo)
-- ---------------------------------------------------------------------
-- O valor na spec eh texto ('80 Nm', '12-15 Nm'). Extrai o numero;
-- quando eh faixa, usa o ponto medio como nominal.
CREATE OR REPLACE FUNCTION torques_do_modelo(p_modelo_id INT)
RETURNS TABLE(
    fixador  TEXT,
    nominal  NUMERIC,
    unidade  TEXT,
    texto    TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.item,
        CASE
            -- faixa "12-15 Nm" -> ponto medio
            WHEN e.valor ~ '(\d+[,.]?\d*)\s*-\s*(\d+[,.]?\d*)' THEN
                ROUND((
                    replace((regexp_match(e.valor, '(\d+[,.]?\d*)\s*-\s*(\d+[,.]?\d*)'))[1], ',', '.')::NUMERIC +
                    replace((regexp_match(e.valor, '(\d+[,.]?\d*)\s*-\s*(\d+[,.]?\d*)'))[2], ',', '.')::NUMERIC
                ) / 2, 2)
            -- valor unico "80 Nm"
            WHEN e.valor ~ '(\d+[,.]?\d*)' THEN
                replace((regexp_match(e.valor, '(\d+[,.]?\d*)'))[1], ',', '.')::NUMERIC
            ELSE NULL
        END,
        'Nm'::TEXT,
        e.valor
    FROM especificacoes_modelo e
    WHERE e.modelo_id = p_modelo_id
      AND e.categoria = 'Torques'
    ORDER BY e.ordem;
END;
$$ LANGUAGE plpgsql STABLE;

-- ---------------------------------------------------------------------
-- FUNCAO: o torque aplicado esta dentro da tolerancia?
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION avaliar_torque(
    p_nominal NUMERIC, p_aplicado NUMERIC, p_tolerancia_pct NUMERIC DEFAULT 10.0)
RETURNS TABLE(
    dentro_spec BOOLEAN,
    desvio_pct  NUMERIC,
    faixa_min   NUMERIC,
    faixa_max   NUMERIC,
    situacao    TEXT    -- 'ok' | 'frouxo' | 'apertado' | 'sem_spec'
) AS $$
DECLARE
    v_min NUMERIC; v_max NUMERIC; v_desvio NUMERIC;
BEGIN
    IF p_nominal IS NULL OR p_nominal = 0 THEN
        RETURN QUERY SELECT NULL::BOOLEAN, NULL::NUMERIC, NULL::NUMERIC, NULL::NUMERIC, 'sem_spec'::TEXT;
        RETURN;
    END IF;

    v_min := ROUND(p_nominal * (1 - p_tolerancia_pct / 100.0), 2);
    v_max := ROUND(p_nominal * (1 + p_tolerancia_pct / 100.0), 2);
    v_desvio := ROUND((p_aplicado - p_nominal) * 100.0 / p_nominal, 1);

    RETURN QUERY SELECT
        (p_aplicado >= v_min AND p_aplicado <= v_max),
        v_desvio,
        v_min,
        v_max,
        CASE
            WHEN p_aplicado < v_min THEN 'frouxo'
            WHEN p_aplicado > v_max THEN 'apertado'
            ELSE 'ok'
        END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE VIEW vw_torques_inspecao AS
SELECT
    t.id,
    t.inspecao_id,
    i.numero_os,
    mo.placa,
    t.fixador,
    t.torque_nominal,
    t.torque_aplicado,
    t.unidade,
    t.tolerancia_pct,
    ROUND(t.torque_nominal * (1 - t.tolerancia_pct/100.0), 2) AS faixa_min,
    ROUND(t.torque_nominal * (1 + t.tolerancia_pct/100.0), 2) AS faixa_max,
    CASE WHEN t.torque_nominal IS NULL OR t.torque_nominal = 0 THEN NULL
         ELSE ROUND((t.torque_aplicado - t.torque_nominal) * 100.0 / t.torque_nominal, 1)
    END AS desvio_pct,
    CASE
        WHEN t.torque_nominal IS NULL OR t.torque_nominal = 0 THEN 'sem_spec'
        WHEN t.torque_aplicado < t.torque_nominal * (1 - t.tolerancia_pct/100.0) THEN 'frouxo'
        WHEN t.torque_aplicado > t.torque_nominal * (1 + t.tolerancia_pct/100.0) THEN 'apertado'
        ELSE 'ok'
    END AS situacao,
    t.aplicado_por,
    t.aplicado_em,
    t.observacao
FROM inspecao_torques t
JOIN inspecoes i ON i.id = t.inspecao_id
JOIN motos mo    ON mo.id = i.moto_id
ORDER BY t.inspecao_id, t.id;


-- =====================================================================
-- BLOCO 14 :: REVISAO RAPIDA VS COMPLETA
-- =====================================================================
-- Hoje a inspecao carrega SEMPRE todos os itens da revisao. Mas as vezes
-- o cliente so quer troca de oleo, nao o checklist de 22 itens.

ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS tipo_execucao     TEXT NOT NULL DEFAULT 'completa';
ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS servico_rapido_id INT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_tipo_execucao') THEN
        ALTER TABLE inspecoes ADD CONSTRAINT chk_tipo_execucao
            CHECK (tipo_execucao IN ('completa','rapida','avulsa'));
    END IF;
END $$;

COMMENT ON COLUMN inspecoes.tipo_execucao IS
    'completa = todos os itens da revisao | rapida = so os itens do servico | avulsa = so itens escolhidos';

CREATE TABLE IF NOT EXISTS servicos_rapidos (
    id             SERIAL PRIMARY KEY,
    nome           TEXT NOT NULL UNIQUE,
    descricao      TEXT,
    icone          TEXT,
    tempo_min      INT,                -- duracao tipica em minutos
    categorias     TEXT[] NOT NULL,    -- categorias do checklist que entram
    palavras_chave TEXT[],             -- filtro extra por descricao do item
    ativo          BOOLEAN NOT NULL DEFAULT TRUE,
    ordem          INT NOT NULL DEFAULT 0
);

COMMENT ON TABLE servicos_rapidos IS
    'Servicos avulsos que puxam um subconjunto do checklist em vez da revisao inteira';

ALTER TABLE servicos_rapidos ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='servicos_rapidos' AND policyname='auth_all_serv_rap') THEN
        CREATE POLICY auth_all_serv_rap ON servicos_rapidos FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_inspecoes_servico_rapido') THEN
        ALTER TABLE inspecoes ADD CONSTRAINT fk_inspecoes_servico_rapido
            FOREIGN KEY (servico_rapido_id) REFERENCES servicos_rapidos(id);
    END IF;
END $$;

-- Seed dos servicos rapidos
INSERT INTO servicos_rapidos (nome, descricao, icone, tempo_min, categorias, palavras_chave, ordem)
SELECT * FROM (VALUES
    -- As palavras-chave sao propositalmente estreitas. 'filtro' sozinho
    -- puxaria o filtro de AR para dentro de uma troca de oleo; 'folga'
    -- puxaria a folga da embreagem para dentro de um ajuste de corrente.
    ('Troca de oleo',
     'Oleo do motor e filtro de oleo, mais conferencia de nivel dos fluidos',
     'oleo', 40,
     ARRAY['Motor','Fluidos'],
     ARRAY['oleo','dreno'],
     10),
    ('Troca de pastilhas',
     'Pastilhas de freio e sangria do sistema',
     'freio', 60,
     ARRAY['Freios'],
     ARRAY['pastilha','fluido','disco'],
     20),
    ('Ajuste de corrente',
     'Limpeza, lubrificacao e tensionamento da transmissao',
     'corrente', 30,
     ARRAY['Transmissao'],
     ARRAY['corrente','coroa','pinhao','relacao'],
     30),
    ('Pneus',
     'Calibragem, inspecao de desgaste e balanceamento',
     'pneu', 30,
     ARRAY['Pneus'],
     ARRAY['pneu','pressao','desgaste','roda'],
     40),
    ('Bateria e eletrica',
     'Tensao da bateria, terminais, luzes e fusiveis',
     'eletrica', 30,
     ARRAY['Eletrica'],
     ARRAY['bateria','tensao','farol','luz','fusivel'],
     50),
    ('Vela e filtro de ar',
     'Vela de ignicao e elemento filtrante',
     'motor', 45,
     ARRAY['Motor'],
     ARRAY['vela','filtro de ar','ignicao'],
     60)
) AS x(nome, descricao, icone, tempo_min, categorias, palavras_chave, ordem)
WHERE NOT EXISTS (SELECT 1 FROM servicos_rapidos s WHERE s.nome = x.nome);

-- ---------------------------------------------------------------------
-- FUNCAO: quais itens do checklist entram num servico rapido
-- ---------------------------------------------------------------------
-- Regra: categoria E palavra-chave, nao categoria OU palavra-chave.
--
-- O "ou" parecia natural, mas na pratica a categoria eh ampla demais:
-- 'Motor' na revisao de 5.000 km traz oleo, filtro de ar, vela e
-- mangueiras EVAP. Numa troca de oleo, vela e EVAP nao tem o que fazer
-- ali. Com o "e", a categoria delimita o campo e a palavra-chave
-- escolhe o item.
--
-- Servico sem palavras_chave cai no comportamento antigo (so categoria).
-- A revisao serve apenas para dizer DE ONDE tirar os itens.
CREATE OR REPLACE FUNCTION itens_do_servico_rapido(p_servico_id INT, p_revisao_id INT)
RETURNS TABLE(
    item_id          INT,
    ordem            INT,
    categoria        TEXT,
    descricao        TEXT,
    tipo_verificacao TEXT,
    valor_referencia TEXT,
    obrigatorio      BOOLEAN,
    exige_foto       BOOLEAN,
    exige_medicao    BOOLEAN,
    unidade          TEXT,
    limite_minimo    NUMERIC,
    limite_maximo    NUMERIC,
    alerta_em        NUMERIC,
    chave_medicao    TEXT
) AS $$
DECLARE
    v_cats  TEXT[];
    v_chave TEXT[];
BEGIN
    SELECT categorias, COALESCE(palavras_chave, ARRAY[]::TEXT[])
    INTO v_cats, v_chave
    FROM servicos_rapidos WHERE id = p_servico_id AND ativo = TRUE;

    IF NOT FOUND THEN RETURN; END IF;

    RETURN QUERY
    SELECT
        ic.id, ic.ordem, ic.categoria, ic.descricao, ic.tipo_verificacao,
        ic.valor_referencia, ic.obrigatorio, ic.exige_foto, ic.exige_medicao,
        ic.unidade, ic.limite_minimo, ic.limite_maximo, ic.alerta_em, ic.chave_medicao
    FROM itens_checklist ic
    WHERE ic.revisao_id = p_revisao_id
      AND ic.categoria = ANY(v_cats)
      AND (
            -- sem palavras-chave: a categoria sozinha delimita
            cardinality(v_chave) = 0
            OR EXISTS (
                SELECT 1 FROM unnest(v_chave) k
                WHERE ic.descricao ILIKE '%' || k || '%'
            )
          )
    ORDER BY ic.ordem;
END;
$$ LANGUAGE plpgsql STABLE;

-- ---------------------------------------------------------------------
-- FUNCAO: pode_finalizar adaptada ao tipo de execucao
-- ---------------------------------------------------------------------
-- A pode_finalizar_inspecao() da Fase 3 exige TODOS os itens da revisao.
-- Numa revisao rapida isso nunca eh satisfeito. Esta versao conta apenas
-- os itens que a inspecao realmente carregou.
CREATE OR REPLACE FUNCTION pode_finalizar_por_tipo(p_inspecao_id UUID)
RETURNS TABLE(
    pode_finalizar  BOOLEAN,
    tipo_execucao   TEXT,
    esperados       INT,
    preenchidos     INT,
    faltam          INT,
    motivo          TEXT
) AS $$
DECLARE
    v_tipo TEXT; v_rev INT; v_serv INT;
    v_esperados INT; v_preench INT;
BEGIN
    SELECT i.tipo_execucao, i.revisao_id, i.servico_rapido_id
    INTO v_tipo, v_rev, v_serv
    FROM inspecoes i WHERE i.id = p_inspecao_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::TEXT, 0, 0, 0, 'Inspecao nao encontrada'::TEXT;
        RETURN;
    END IF;

    -- Quantos itens essa inspecao deveria ter
    IF v_tipo = 'completa' THEN
        SELECT COUNT(*) INTO v_esperados
        FROM itens_checklist WHERE revisao_id = v_rev AND obrigatorio = TRUE;
    ELSIF v_tipo = 'rapida' AND v_serv IS NOT NULL THEN
        SELECT COUNT(*) INTO v_esperados
        FROM itens_do_servico_rapido(v_serv, v_rev) WHERE obrigatorio = TRUE;
    ELSE
        -- avulsa: o esperado eh o que ja foi lancado
        SELECT COUNT(*) INTO v_esperados
        FROM inspecoes_itens WHERE inspecao_id = p_inspecao_id;
    END IF;

    SELECT COUNT(*) INTO v_preench
    FROM inspecoes_itens ii
    LEFT JOIN itens_checklist ic ON ic.id = ii.item_id
    WHERE ii.inspecao_id = p_inspecao_id
      AND ii.status IN ('ok','nao_ok','na')
      AND (ii.item_id IS NULL OR ic.obrigatorio = TRUE OR v_tipo = 'avulsa');

    RETURN QUERY SELECT
        (v_preench >= v_esperados AND v_esperados > 0),
        v_tipo,
        v_esperados,
        v_preench::INT,
        GREATEST(0, v_esperados - v_preench)::INT,
        CASE
            WHEN v_esperados = 0 THEN 'Nenhum item lancado nesta inspecao'
            WHEN v_preench >= v_esperados THEN format('Pronto para finalizar (%s itens)', v_preench)
            ELSE format('%s item(ns) obrigatorio(s) pendente(s)', v_esperados - v_preench)
        END;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE VIEW vw_servicos_rapidos AS
SELECT
    s.id, s.nome, s.descricao, s.icone, s.tempo_min,
    s.categorias, s.palavras_chave, s.ordem,
    COUNT(i.id) AS vezes_executado
FROM servicos_rapidos s
LEFT JOIN inspecoes i ON i.servico_rapido_id = s.id AND i.status = 'finalizada'
WHERE s.ativo = TRUE
GROUP BY s.id
ORDER BY s.ordem;
