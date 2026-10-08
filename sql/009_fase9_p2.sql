-- =====================================================================
-- REVISAO-MOTO :: Migration Fase 9 (P2) - Alta prioridade
-- =====================================================================
-- 5. Checklist de recebimento (avarias)
-- 6. Recomendacoes futuras (UI sobre a view da Fase 8)
-- 7. Fotos antes/depois
-- 8. Lembrete automatico ao CLIENTE
-- 9. Numero de OS (ordem de servico)
--
-- Idempotente.
-- =====================================================================


-- =====================================================================
-- BLOCO 9 :: NUMERO DE OS  (primeiro, porque o recebimento referencia)
-- =====================================================================
-- Hoje a inspecao so tem UUID, que ninguem consegue ditar no telefone.
-- Formato: AAAA-NNNN (2026-0001), sequencial reiniciado por ano.

CREATE TABLE IF NOT EXISTS os_contador (
    ano          INT PRIMARY KEY,
    ultimo_numero INT NOT NULL DEFAULT 0
);

ALTER TABLE inspecoes ADD COLUMN IF NOT EXISTS numero_os TEXT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname='idx_inspecoes_numero_os') THEN
        CREATE UNIQUE INDEX idx_inspecoes_numero_os ON inspecoes(numero_os)
            WHERE numero_os IS NOT NULL;
    END IF;
END $$;

COMMENT ON COLUMN inspecoes.numero_os IS 'AAAA-NNNN sequencial por ano. Referencia ditavel por telefone/WhatsApp.';

CREATE OR REPLACE FUNCTION proximo_numero_os()
RETURNS TEXT AS $$
DECLARE
    v_ano INT := EXTRACT(YEAR FROM NOW())::INT;
    v_num INT;
BEGIN
    -- UPSERT atomico: incrementa e devolve na mesma operacao
    INSERT INTO os_contador (ano, ultimo_numero)
    VALUES (v_ano, 1)
    ON CONFLICT (ano) DO UPDATE SET ultimo_numero = os_contador.ultimo_numero + 1
    RETURNING ultimo_numero INTO v_num;

    RETURN v_ano::TEXT || '-' || LPAD(v_num::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Trigger: toda inspecao nasce com numero de OS
CREATE OR REPLACE FUNCTION trigger_gerar_numero_os()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.numero_os IS NULL THEN
        NEW.numero_os := proximo_numero_os();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_numero_os ON inspecoes;
CREATE TRIGGER set_numero_os
    BEFORE INSERT ON inspecoes
    FOR EACH ROW EXECUTE FUNCTION trigger_gerar_numero_os();

-- Backfill das inspecoes que ja existem (ordem cronologica)
DO $$
DECLARE
    r RECORD;
    v_ano INT;
    v_seq INT;
    v_ano_atual INT := -1;
BEGIN
    FOR r IN
        SELECT id, EXTRACT(YEAR FROM data_inicio)::INT AS ano
        FROM inspecoes
        WHERE numero_os IS NULL
        ORDER BY data_inicio
    LOOP
        IF r.ano <> v_ano_atual THEN
            v_ano_atual := r.ano;
            SELECT COALESCE(ultimo_numero, 0) INTO v_seq FROM os_contador WHERE ano = r.ano;
            IF v_seq IS NULL THEN v_seq := 0; END IF;
        END IF;
        v_seq := v_seq + 1;
        UPDATE inspecoes SET numero_os = r.ano::TEXT || '-' || LPAD(v_seq::TEXT, 4, '0')
        WHERE id = r.id;

        INSERT INTO os_contador (ano, ultimo_numero) VALUES (r.ano, v_seq)
        ON CONFLICT (ano) DO UPDATE SET ultimo_numero = GREATEST(os_contador.ultimo_numero, v_seq);
    END LOOP;
END $$;


-- =====================================================================
-- BLOCO 5 :: CHECKLIST DE RECEBIMENTO (AVARIAS)
-- =====================================================================
-- Protege a oficina de "minha moto nao tinha esse risco no tanque".
-- Fotografado e assinado pelo cliente NA ENTRADA, antes do servico.

CREATE TABLE IF NOT EXISTS recebimentos (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inspecao_id         UUID REFERENCES inspecoes(id) ON DELETE CASCADE,
    moto_id             INT NOT NULL REFERENCES motos(id),
    km_entrada          INT,

    -- 4 fotos obrigatorias (paths no Storage)
    foto_frente         TEXT,
    foto_tras           TEXT,
    foto_lado_esq       TEXT,
    foto_lado_dir       TEXT,

    -- Inventario de avarias
    avarias_texto       TEXT,
    avarias_marcacoes   JSONB DEFAULT '[]'::jsonb,  -- [{x,y,lado,nota}]

    -- Combustivel: 0=vazio, 1=1/4, 2=1/2, 3=3/4, 4=cheio
    nivel_combustivel   INT CHECK (nivel_combustivel BETWEEN 0 AND 4),

    -- Acessorios presentes
    tem_bau             BOOLEAN NOT NULL DEFAULT FALSE,
    tem_capacete        BOOLEAN NOT NULL DEFAULT FALSE,
    tem_documentos      BOOLEAN NOT NULL DEFAULT FALSE,
    outros_acessorios   TEXT,

    -- Assinatura do cliente na entrada
    assinatura_cliente  TEXT,
    nome_cliente        TEXT,
    recebido_por        TEXT,
    recebido_em         TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    criado_em           TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE recebimentos IS
    'Vistoria de entrada: estado da moto ao chegar na oficina, assinado pelo cliente';
COMMENT ON COLUMN recebimentos.nivel_combustivel IS '0=vazio 1=1/4 2=1/2 3=3/4 4=cheio';
COMMENT ON COLUMN recebimentos.avarias_marcacoes IS
    'Marcacoes sobre o diagrama da moto: [{"x":0.3,"y":0.5,"lado":"esq","nota":"risco"}]';

CREATE INDEX IF NOT EXISTS idx_recebimentos_moto     ON recebimentos(moto_id, recebido_em DESC);
CREATE INDEX IF NOT EXISTS idx_recebimentos_inspecao ON recebimentos(inspecao_id);

ALTER TABLE recebimentos ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='recebimentos' AND policyname='auth_all_receb') THEN
        CREATE POLICY auth_all_receb ON recebimentos FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- Completude do recebimento: 4 fotos + assinatura + nome
CREATE OR REPLACE FUNCTION recebimento_completo(p_recebimento_id UUID)
RETURNS TABLE(
    completo         BOOLEAN,
    fotos_faltando   INT,
    tem_assinatura   BOOLEAN,
    motivo           TEXT
) AS $$
DECLARE
    r recebimentos%ROWTYPE;
    v_faltam INT := 0;
    v_assin  BOOLEAN;
BEGIN
    SELECT * INTO r FROM recebimentos WHERE id = p_recebimento_id;
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 4, FALSE, 'Recebimento nao encontrado'::TEXT;
        RETURN;
    END IF;

    IF r.foto_frente   IS NULL OR r.foto_frente   = '' THEN v_faltam := v_faltam + 1; END IF;
    IF r.foto_tras     IS NULL OR r.foto_tras     = '' THEN v_faltam := v_faltam + 1; END IF;
    IF r.foto_lado_esq IS NULL OR r.foto_lado_esq = '' THEN v_faltam := v_faltam + 1; END IF;
    IF r.foto_lado_dir IS NULL OR r.foto_lado_dir = '' THEN v_faltam := v_faltam + 1; END IF;

    v_assin := (r.assinatura_cliente IS NOT NULL
                AND LENGTH(r.assinatura_cliente) > 100
                AND r.nome_cliente IS NOT NULL
                AND LENGTH(TRIM(r.nome_cliente)) >= 3);

    RETURN QUERY SELECT
        (v_faltam = 0 AND v_assin),
        v_faltam,
        v_assin,
        CASE
            WHEN v_faltam > 0 AND NOT v_assin THEN
                format('Faltam %s foto(s) e a assinatura do cliente', v_faltam)
            WHEN v_faltam > 0 THEN format('Faltam %s foto(s)', v_faltam)
            WHEN NOT v_assin THEN 'Falta a assinatura do cliente'::TEXT
            ELSE 'Completo'::TEXT
        END;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE VIEW vw_recebimentos AS
SELECT
    r.id,
    r.inspecao_id,
    i.numero_os,
    r.moto_id,
    mo.placa,
    md.nome                AS modelo,
    mo.proprietario,
    mo.telefone,
    r.km_entrada,
    r.nivel_combustivel,
    CASE r.nivel_combustivel
        WHEN 0 THEN 'Vazio' WHEN 1 THEN '1/4' WHEN 2 THEN '1/2'
        WHEN 3 THEN '3/4'   WHEN 4 THEN 'Cheio' ELSE '-'
    END                    AS combustivel_texto,
    r.avarias_texto,
    jsonb_array_length(COALESCE(r.avarias_marcacoes, '[]'::jsonb)) AS qtd_marcacoes,
    r.tem_bau, r.tem_capacete, r.tem_documentos, r.outros_acessorios,
    (CASE WHEN r.foto_frente   IS NOT NULL AND r.foto_frente   <> '' THEN 1 ELSE 0 END +
     CASE WHEN r.foto_tras     IS NOT NULL AND r.foto_tras     <> '' THEN 1 ELSE 0 END +
     CASE WHEN r.foto_lado_esq IS NOT NULL AND r.foto_lado_esq <> '' THEN 1 ELSE 0 END +
     CASE WHEN r.foto_lado_dir IS NOT NULL AND r.foto_lado_dir <> '' THEN 1 ELSE 0 END
    )                      AS fotos_tiradas,
    (r.assinatura_cliente IS NOT NULL AND LENGTH(r.assinatura_cliente) > 100) AS tem_assinatura,
    r.nome_cliente,
    r.recebido_por,
    r.recebido_em
FROM recebimentos r
JOIN motos mo   ON mo.id = r.moto_id
JOIN modelos md ON md.id = mo.modelo_id
LEFT JOIN inspecoes i ON i.id = r.inspecao_id;


-- =====================================================================
-- BLOCO 7 :: FOTOS ANTES/DEPOIS
-- =====================================================================
-- Hoje eh 1 foto por item (foto_url). Duas provam o servico feito.
-- Mantem foto_url para retrocompatibilidade: vira "antes" por padrao.

ALTER TABLE inspecoes_itens ADD COLUMN IF NOT EXISTS foto_antes_url  TEXT;
ALTER TABLE inspecoes_itens ADD COLUMN IF NOT EXISTS foto_depois_url TEXT;

COMMENT ON COLUMN inspecoes_itens.foto_antes_url  IS 'Estado encontrado';
COMMENT ON COLUMN inspecoes_itens.foto_depois_url IS 'Estado apos o servico - prova a execucao';

-- Migra o que ja existe: foto_url vira foto_antes_url
UPDATE inspecoes_itens
SET foto_antes_url = foto_url
WHERE foto_url IS NOT NULL AND foto_antes_url IS NULL;


-- =====================================================================
-- BLOCO 8 :: LEMBRETE AUTOMATICO AO CLIENTE
-- =====================================================================
-- As notificacoes da Fase 7 avisam o MECANICO. Esta tabela registra
-- o que ja foi enviado ao CLIENTE, para nao mandar duas vezes.

CREATE TABLE IF NOT EXISTS lembretes_cliente (
    id            SERIAL PRIMARY KEY,
    moto_id       INT NOT NULL REFERENCES motos(id) ON DELETE CASCADE,
    tipo          TEXT NOT NULL,   -- 'revisao_proxima' | 'revisao_atrasada' | 'recomendacao'
    canal         TEXT NOT NULL DEFAULT 'whatsapp',
    mensagem      TEXT,
    km_referencia INT,
    enviado_em    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    enviado_por   TEXT
);

COMMENT ON TABLE lembretes_cliente IS
    'Log de lembretes enviados ao cliente. Evita reenvio e serve de historico.';

CREATE INDEX IF NOT EXISTS idx_lembretes_moto ON lembretes_cliente(moto_id, tipo, enviado_em DESC);

ALTER TABLE lembretes_cliente ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='lembretes_cliente' AND policyname='auth_all_lembretes') THEN
        CREATE POLICY auth_all_lembretes ON lembretes_cliente FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- Motos que precisam de lembrete e ainda nao receberam nos ultimos 30 dias
-- Nota: vw_motos_com_status_revisao expoe a moto como 'id' e nao traz
-- telefone, entao o JOIN com motos e necessario.
CREATE OR REPLACE VIEW vw_lembretes_pendentes AS
SELECT
    v.id                 AS moto_id,
    v.placa,
    v.modelo,
    v.proprietario,
    mo.telefone,
    v.km_atual,
    v.status_revisao,
    v.proxima_km_prevista,
    CASE v.status_revisao
        WHEN 'atrasada' THEN 'revisao_atrasada'
        WHEN 'proxima'  THEN 'revisao_proxima'
    END AS tipo_lembrete,
    ul.enviado_em AS ultimo_envio
FROM vw_motos_com_status_revisao v
JOIN motos mo ON mo.id = v.id
LEFT JOIN LATERAL (
    SELECT enviado_em FROM lembretes_cliente l
    WHERE l.moto_id = v.id
      AND l.tipo IN ('revisao_proxima','revisao_atrasada')
    ORDER BY enviado_em DESC LIMIT 1
) ul ON TRUE
WHERE v.status_revisao IN ('proxima','atrasada')
  AND mo.telefone IS NOT NULL
  AND mo.telefone <> ''
  AND (ul.enviado_em IS NULL OR ul.enviado_em < NOW() - INTERVAL '30 days');


-- =====================================================================
-- BLOCO 6 :: RECOMENDACOES FUTURAS
-- =====================================================================
-- A view vw_recomendacoes_futuras ja existe (Fase 8). Aqui so adicionamos
-- a persistencia da recomendacao no fechamento da inspecao, para que ela
-- apareca no PDF e vire lead rastreavel.

CREATE TABLE IF NOT EXISTS recomendacoes (
    id             SERIAL PRIMARY KEY,
    inspecao_id    UUID NOT NULL REFERENCES inspecoes(id) ON DELETE CASCADE,
    moto_id        INT NOT NULL REFERENCES motos(id),
    descricao      TEXT NOT NULL,
    chave_medicao  TEXT,
    medicao_atual  NUMERIC,
    unidade        TEXT,
    previsao_km    INT,
    prioridade     TEXT NOT NULL DEFAULT 'planejar',  -- 'urgente' | 'planejar' | 'observar'
    criado_em      TIMESTAMPTZ DEFAULT NOW(),
    CHECK (prioridade IN ('urgente','planejar','observar'))
);

COMMENT ON TABLE recomendacoes IS
    'Recomendacoes congeladas no fechamento da inspecao. Saem no PDF e viram lead de venda.';

CREATE INDEX IF NOT EXISTS idx_recomendacoes_insp ON recomendacoes(inspecao_id);
CREATE INDEX IF NOT EXISTS idx_recomendacoes_moto ON recomendacoes(moto_id, criado_em DESC);

ALTER TABLE recomendacoes ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='recomendacoes' AND policyname='auth_all_recom') THEN
        CREATE POLICY auth_all_recom ON recomendacoes FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- Gera as recomendacoes de uma inspecao a partir das medicoes dela
CREATE OR REPLACE FUNCTION gerar_recomendacoes(p_inspecao_id UUID)
RETURNS INT AS $$
DECLARE
    v_moto INT;
    v_count INT := 0;
    r RECORD;
BEGIN
    SELECT moto_id INTO v_moto FROM inspecoes WHERE id = p_inspecao_id;
    IF NOT FOUND THEN RETURN 0; END IF;

    DELETE FROM recomendacoes WHERE inspecao_id = p_inspecao_id;

    FOR r IN
        SELECT ic.descricao, ic.chave_medicao, ii.valor_numerico, ic.unidade,
               ic.limite_minimo, ic.alerta_em
        FROM inspecoes_itens ii
        JOIN itens_checklist ic ON ic.id = ii.item_id
        WHERE ii.inspecao_id = p_inspecao_id
          AND ii.valor_numerico IS NOT NULL
          AND ic.chave_medicao IS NOT NULL
          AND (
            (ic.limite_minimo IS NOT NULL AND ii.valor_numerico < ic.limite_minimo)
            OR
            (ic.alerta_em IS NOT NULL AND ii.valor_numerico <= ic.alerta_em)
          )
    LOOP
        INSERT INTO recomendacoes
            (inspecao_id, moto_id, descricao, chave_medicao, medicao_atual, unidade,
             previsao_km, prioridade)
        SELECT
            p_inspecao_id, v_moto, r.descricao, r.chave_medicao, r.valor_numerico, r.unidade,
            (SELECT previsao_troca_km FROM taxa_desgaste(v_moto, r.chave_medicao) LIMIT 1),
            CASE WHEN r.limite_minimo IS NOT NULL AND r.valor_numerico < r.limite_minimo
                 THEN 'urgente' ELSE 'planejar' END;
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;
