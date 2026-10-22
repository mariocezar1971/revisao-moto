// =====================================================================
// REVISAO-MOTO :: Torque efetivamente aplicado (Fase 10)
// =====================================================================
// A Fase 7 cadastrou os torques NOMINAIS em especificacoes_modelo.
// Aqui registramos o torque REAL aplicado em cada fixador critico.
//
// Para que serve: se uma roda se soltar depois da revisao, o registro
// mostra com que valor ela foi apertada, por quem e quando. O nominal
// eh copiado no momento do aperto, entao corrigir a spec depois nao
// reescreve o historico.
// =====================================================================

const TOLERANCIA_PADRAO = 10.0;   // +/- 10% do nominal

const CORES_SITUACAO = {
    ok:        { bg: '#dcfce7', borda: '#16a34a', texto: '#15803d', icone: '✓' },
    frouxo:    { bg: '#fef9c3', borda: '#ca8a04', texto: '#a16207', icone: '↓' },
    apertado:  { bg: '#fee2e2', borda: '#dc2626', texto: '#b91c1c', icone: '↑' },
    sem_spec:  { bg: '#f1f5f9', borda: '#94a3b8', texto: '#475569', icone: '–' }
};

// ================================================================
// SPECS DO MODELO
// ================================================================
/**
 * Torques nominais do modelo, lidos de especificacoes_modelo.
 * Quando a spec eh faixa ('12-15 Nm'), o nominal vira o ponto medio.
 */
async function torquesDoModelo(modeloId) {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .rpc('torques_do_modelo', { p_modelo_id: modeloId });
    if (error) { console.warn('torquesDoModelo:', error); return []; }
    return data || [];
}

// ================================================================
// AVALIACAO
// ================================================================
/**
 * Avalia local, sem ida ao servidor, para o campo reagir enquanto
 * o mecanico digita. Mesma regra da funcao SQL avaliar_torque().
 */
function avaliarLocal(nominal, aplicado, toleranciaPct) {
    const n = Number(nominal);
    const a = normalizarNumero(aplicado);
    const tol = Number(toleranciaPct) || TOLERANCIA_PADRAO;

    if (!n || a == null) {
        return { situacao: 'sem_spec', dentro_spec: null, desvio_pct: null,
                 faixa_min: null, faixa_max: null, valor: a };
    }

    const min = Math.round(n * (1 - tol / 100) * 100) / 100;
    const max = Math.round(n * (1 + tol / 100) * 100) / 100;
    const desvio = Math.round((a - n) * 1000 / n) / 10;

    let situacao = 'ok';
    if (a < min) situacao = 'frouxo';
    else if (a > max) situacao = 'apertado';

    return {
        situacao,
        dentro_spec: situacao === 'ok',
        desvio_pct: desvio,
        faixa_min: min,
        faixa_max: max,
        valor: a
    };
}

/** Aceita "79", "79,5", "79.5 Nm" e devolve 79.5. */
function normalizarNumero(valor) {
    if (valor === null || valor === undefined || valor === '') return null;
    if (typeof valor === 'number') return isNaN(valor) ? null : valor;
    const limpo = String(valor).trim().replace(',', '.').replace(/[^\d.\-]/g, '');
    if (limpo === '' || limpo === '.' || limpo === '-') return null;
    const n = parseFloat(limpo);
    return isNaN(n) ? null : n;
}

function textoFaixa(nominal, toleranciaPct) {
    const n = Number(nominal);
    if (!n) return '';
    const tol = Number(toleranciaPct) || TOLERANCIA_PADRAO;
    const min = (n * (1 - tol / 100)).toFixed(1).replace('.', ',');
    const max = (n * (1 + tol / 100)).toFixed(1).replace('.', ',');
    return `${min} a ${max} Nm`;
}

/**
 * Pinta o campo conforme a situacao e escreve o feedback ao lado.
 */
function aplicarCor(inputEl, nominal, toleranciaPct, feedbackEl) {
    const res = avaliarLocal(nominal, inputEl.value, toleranciaPct);
    const c = CORES_SITUACAO[res.situacao];

    inputEl.style.backgroundColor = c.bg;
    inputEl.style.borderColor = c.borda;
    inputEl.style.color = c.texto;
    inputEl.style.fontWeight = res.situacao === 'ok' ? '400' : '600';

    if (feedbackEl) {
        if (res.valor == null) {
            feedbackEl.textContent = '';
        } else if (res.situacao === 'sem_spec') {
            feedbackEl.textContent = 'Sem torque de referencia para este fixador';
            feedbackEl.style.color = c.texto;
        } else {
            const sinal = res.desvio_pct > 0 ? '+' : '';
            feedbackEl.textContent =
                `${c.icone} ${res.situacao} (${sinal}${res.desvio_pct}%)`;
            feedbackEl.style.color = c.texto;
        }
    }
    return res;
}

// ================================================================
// REGISTRO
// ================================================================
async function registrarTorque(inspecaoId, { fixador, nominal, aplicado,
                                             toleranciaPct, aplicadoPor, observacao }) {
    if (!window.sb) throw new Error('Sem conexao');

    const valor = normalizarNumero(aplicado);
    if (valor == null || valor <= 0) throw new Error('Informe o torque aplicado');
    if (!fixador) throw new Error('Informe o fixador');

    const { data, error } = await window.sb.from('inspecao_torques').upsert({
        inspecao_id: inspecaoId,
        fixador,
        torque_nominal: nominal != null ? Number(nominal) : null,
        torque_aplicado: valor,
        tolerancia_pct: Number(toleranciaPct) || TOLERANCIA_PADRAO,
        aplicado_por: aplicadoPor || null,
        observacao: observacao || null,
        aplicado_em: new Date().toISOString()
    }, { onConflict: 'inspecao_id,fixador' }).select().single();
    if (error) throw error;
    return data;
}

async function removerTorque(id) {
    const { error } = await window.sb.from('inspecao_torques').delete().eq('id', id);
    if (error) throw error;
}

async function listarTorques(inspecaoId) {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .from('vw_torques_inspecao').select('*')
        .eq('inspecao_id', inspecaoId);
    if (error) { console.warn('listarTorques:', error); return []; }
    return data || [];
}

/**
 * Resumo para o rodape da secao: quantos fora de spec.
 */
function resumir(torques) {
    const r = { total: (torques || []).length, ok: 0, frouxo: 0, apertado: 0, sem_spec: 0 };
    for (const t of (torques || [])) {
        if (t.situacao in r) r[t.situacao]++;
    }
    r.fora_spec = r.frouxo + r.apertado;
    return r;
}

window.torque = {
    TOLERANCIA_PADRAO,
    CORES_SITUACAO,
    torquesDoModelo,
    avaliarLocal,
    normalizarNumero,
    textoFaixa,
    aplicarCor,
    registrarTorque,
    removerTorque,
    listarTorques,
    resumir
};
