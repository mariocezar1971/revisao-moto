// =====================================================================
// REVISAO-MOTO :: Medicoes numericas com limites (Fase 8)
// =====================================================================
// Avalia medicoes contra os limites cadastrados no item e calcula
// taxa de desgaste comparando com inspecoes anteriores da mesma moto.
//
// Chave de projeto: a comparacao entre revisoes usa chave_medicao,
// NAO a descricao - a descricao do mesmo item fisico muda entre
// revisoes ("Inspecao de pastilhas dianteiras" no 500km virou
// "Pastilhas dianteiras - espessura" no 5000km+).
// =====================================================================

const CORES_SEMAFORO = {
    verde:      { bg: '#dcfce7', borda: '#16a34a', texto: '#15803d', icone: '✓' },
    amarelo:    { bg: '#fef9c3', borda: '#ca8a04', texto: '#a16207', icone: '!' },
    vermelho:   { bg: '#fee2e2', borda: '#dc2626', texto: '#b91c1c', icone: '✕' },
    sem_limite: { bg: '#f1f5f9', borda: '#94a3b8', texto: '#475569', icone: '–' }
};

// ================================================================
// AVALIACAO LOCAL (sem ida ao servidor)
// ================================================================
/**
 * Avalia uma medicao contra os limites do item.
 * Faz o mesmo calculo da funcao SQL avaliar_medicao(), mas no cliente,
 * para dar feedback imediato enquanto o mecanico digita.
 *
 * @param {number|string} valor - medicao informada
 * @param {object} item - { unidade, limite_minimo, limite_maximo, alerta_em }
 * @returns {{semaforo:string, mensagem:string, valor:number|null}}
 */
function avaliarLocal(valor, item) {
    const v = normalizarNumero(valor);

    if (v === null) {
        return { semaforo: 'sem_limite', mensagem: 'Medicao nao informada', valor: null };
    }
    if (!item || (item.limite_minimo == null && item.limite_maximo == null)) {
        return { semaforo: 'sem_limite', mensagem: 'Sem limite cadastrado', valor: v };
    }

    const uni = item.unidade || '';

    if (item.limite_minimo != null && v < Number(item.limite_minimo)) {
        return {
            semaforo: 'vermelho',
            mensagem: `Abaixo do limite de servico (${item.limite_minimo} ${uni})`,
            valor: v
        };
    }
    if (item.limite_maximo != null && v > Number(item.limite_maximo)) {
        return {
            semaforo: 'vermelho',
            mensagem: `Acima do maximo admissivel (${item.limite_maximo} ${uni})`,
            valor: v
        };
    }
    if (item.alerta_em != null && v <= Number(item.alerta_em)) {
        return {
            semaforo: 'amarelo',
            mensagem: 'Proximo do limite - planejar substituicao',
            valor: v
        };
    }
    return { semaforo: 'verde', mensagem: 'Dentro da especificacao', valor: v };
}

/**
 * Aceita "2,8", "2.8", "2,8 mm", " 2.8mm " e devolve 2.8.
 * Devolve null se nao houver numero reconhecivel.
 */
function normalizarNumero(valor) {
    if (valor === null || valor === undefined || valor === '') return null;
    if (typeof valor === 'number') return isNaN(valor) ? null : valor;

    const limpo = String(valor)
        .trim()
        .replace(',', '.')
        .replace(/[^\d.\-]/g, '');

    if (limpo === '' || limpo === '.' || limpo === '-') return null;
    const n = parseFloat(limpo);
    return isNaN(n) ? null : n;
}

// ================================================================
// APLICAR NO DOM
// ================================================================
/**
 * Pinta um input de medicao conforme o semaforo e escreve a mensagem
 * no elemento de feedback ao lado.
 */
function aplicarSemaforo(inputEl, item, feedbackEl) {
    const res = avaliarLocal(inputEl.value, item);
    const cor = CORES_SEMAFORO[res.semaforo];

    inputEl.style.backgroundColor = cor.bg;
    inputEl.style.borderColor = cor.borda;
    inputEl.style.color = cor.texto;
    inputEl.style.fontWeight = res.semaforo === 'verde' ? '400' : '600';

    if (feedbackEl) {
        if (res.semaforo === 'sem_limite' && res.valor === null) {
            feedbackEl.textContent = '';
        } else {
            feedbackEl.textContent = `${cor.icone} ${res.mensagem}`;
            feedbackEl.style.color = cor.texto;
        }
    }
    return res;
}

/**
 * Monta o texto de referencia que aparece abaixo do campo.
 * Ex: "min 1.5 mm · alerta em 2.03 mm"
 */
function textoReferencia(item) {
    if (!item) return '';
    const partes = [];
    const uni = item.unidade || '';
    if (item.limite_minimo != null) partes.push(`min ${item.limite_minimo} ${uni}`);
    if (item.limite_maximo != null) partes.push(`max ${item.limite_maximo} ${uni}`);
    if (item.alerta_em != null)     partes.push(`alerta em ${Number(item.alerta_em).toFixed(2)} ${uni}`);
    return partes.join(' · ');
}

// ================================================================
// DESGASTE (consulta ao servidor)
// ================================================================
/**
 * Busca a taxa de desgaste de um item para uma moto.
 * Retorna null se nao houver 2 medicoes finalizadas para comparar.
 */
async function buscarDesgaste(motoId, chaveMedicao) {
    if (!window.sb || !navigator.onLine) return null;
    try {
        const { data, error } = await window.sb.rpc('taxa_desgaste', {
            p_moto_id: motoId,
            p_chave: chaveMedicao
        });
        if (error) throw error;
        return (data && data.length > 0) ? data[0] : null;
    } catch (e) {
        console.warn('taxa_desgaste falhou:', e);
        return null;
    }
}

/**
 * Formata a previsao para exibicao.
 * Ex: "Desgaste 0,24 mm/1000km · troca prevista em ~15.400 km"
 */
function formatarPrevisao(d) {
    if (!d || d.desgaste_por_1000km == null) return '';
    const taxa = Number(d.desgaste_por_1000km);
    if (taxa <= 0) return 'Sem desgaste medido desde a ultima revisao';

    const uni = d.unidade || '';
    let txt = `Desgaste ${taxa.toFixed(2).replace('.', ',')} ${uni}/1000km`;

    if (d.previsao_troca_km != null) {
        const prev = Math.round(d.previsao_troca_km / 100) * 100;
        txt += ` · troca prevista em ~${prev.toLocaleString('pt-BR')} km`;
    }
    return txt;
}

/**
 * Lista as recomendacoes futuras de uma moto (itens no amarelo/vermelho).
 */
async function recomendacoesDaMoto(motoId) {
    if (!window.sb || !navigator.onLine) return [];
    try {
        const { data, error } = await window.sb
            .from('vw_recomendacoes_futuras')
            .select('*')
            .eq('moto_id', motoId)
            .neq('recomendacao', 'ok');
        if (error) throw error;
        return data || [];
    } catch (e) {
        console.warn('recomendacoes falhou:', e);
        return [];
    }
}

window.medicoes = {
    avaliarLocal,
    normalizarNumero,
    aplicarSemaforo,
    textoReferencia,
    buscarDesgaste,
    formatarPrevisao,
    recomendacoesDaMoto,
    CORES_SEMAFORO
};
