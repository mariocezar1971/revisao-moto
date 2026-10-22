// =====================================================================
// REVISAO-MOTO :: Comparacao entre revisoes (Fase 10)
// =====================================================================
// A Fase 8 ja calculava a taxa de desgaste entre as duas ultimas
// medicoes de um item. Aqui o recorte eh outro: por duas inspecoes
// inteiras lado a lado, e ver a serie historica completa de um item.
// =====================================================================

const CORES_TENDENCIA = {
    piorou:   { bg: '#fee2e2', texto: '#b91c1c', seta: '↓', rotulo: 'piorou' },
    melhorou: { bg: '#dcfce7', texto: '#15803d', seta: '↑', rotulo: 'melhorou' },
    estavel:  { bg: '#f1f5f9', texto: '#475569', seta: '→', rotulo: 'estavel' },
    novo:     { bg: '#dbeafe', texto: '#1d4ed8', seta: '✦', rotulo: 'primeira medicao' }
};

// ================================================================
// PARES COMPARAVEIS
// ================================================================
/**
 * Inspecoes finalizadas de uma moto, cada uma ja apontando para a
 * anterior. A mais antiga vem com inspecao_anterior nulo.
 */
async function inspecoesComparaveis(motoId) {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .from('vw_inspecoes_comparaveis')
        .select('*')
        .eq('moto_id', motoId)
        .order('km_atual', { ascending: false });
    if (error) { console.warn('inspecoesComparaveis:', error); return []; }
    return data || [];
}

// ================================================================
// COMPARACAO
// ================================================================
/**
 * Compara duas inspecoes item a item.
 * B eh a mais recente; delta positivo significa que o valor subiu.
 */
async function compararInspecoes(inspecaoA, inspecaoB) {
    if (!window.sb) return [];
    const { data, error } = await window.sb.rpc('comparar_inspecoes', {
        p_inspecao_a: inspecaoA,
        p_inspecao_b: inspecaoB
    });
    if (error) { console.warn('compararInspecoes:', error); return []; }
    return data || [];
}

/**
 * Formata uma linha da comparacao para exibicao.
 */
function formatarLinha(linha) {
    const t = CORES_TENDENCIA[linha.tendencia] || CORES_TENDENCIA.estavel;
    const uni = linha.unidade || '';
    const num = (v) => v == null ? '—' : Number(v).toFixed(2).replace('.', ',');

    let variacao = '—';
    if (linha.delta != null) {
        const sinal = Number(linha.delta) > 0 ? '+' : '';
        variacao = `${sinal}${num(linha.delta)} ${uni}`;
        if (linha.delta_pct != null) {
            variacao += ` (${sinal}${Number(linha.delta_pct).toFixed(1).replace('.', ',')}%)`;
        }
    }

    return {
        descricao: linha.descricao,
        categoria: linha.categoria,
        anterior: linha.valor_a == null ? '—' : `${num(linha.valor_a)} ${uni}`,
        atual: `${num(linha.valor_b)} ${uni}`,
        variacao,
        tendencia: linha.tendencia,
        seta: t.seta,
        cor: t,
        semaforo: linha.semaforo_b
    };
}

/**
 * Agrupa a comparacao por categoria, do jeito que a tela mostra.
 */
function agruparPorCategoria(linhas) {
    const grupos = {};
    for (const l of linhas) {
        const cat = l.categoria || 'Geral';
        if (!grupos[cat]) grupos[cat] = [];
        grupos[cat].push(formatarLinha(l));
    }
    return grupos;
}

/**
 * Resumo de uma comparacao: quantos pioraram, melhoraram, etc.
 */
function resumir(linhas) {
    const r = { total: linhas.length, piorou: 0, melhorou: 0, estavel: 0, novo: 0,
                vermelho: 0, amarelo: 0, verde: 0 };
    for (const l of linhas) {
        if (l.tendencia in r) r[l.tendencia]++;
        if (l.semaforo_b in r) r[l.semaforo_b]++;
    }
    return r;
}

// ================================================================
// SERIE HISTORICA
// ================================================================
/**
 * Todas as medicoes de um item para uma moto, em ordem de km.
 * Alimenta o grafico de evolucao.
 */
async function historicoMedicao(motoId, chaveMedicao) {
    if (!window.sb) return [];
    const { data, error } = await window.sb.rpc('historico_medicao', {
        p_moto_id: motoId,
        p_chave: chaveMedicao
    });
    if (error) { console.warn('historicoMedicao:', error); return []; }
    return data || [];
}

/**
 * Quais itens dessa moto tem serie historica (2+ medicoes).
 */
async function chavesComHistorico(motoId) {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .from('inspecoes_itens')
        .select('itens_checklist!inner(chave_medicao, descricao, unidade), inspecoes!inner(moto_id, status)')
        .eq('inspecoes.moto_id', motoId)
        .eq('inspecoes.status', 'finalizada')
        .not('valor_numerico', 'is', null)
        .not('itens_checklist.chave_medicao', 'is', null);
    if (error) { console.warn('chavesComHistorico:', error); return []; }

    // Conta medicoes por chave e devolve so as que tem 2 ou mais
    const porChave = {};
    for (const r of (data || [])) {
        const ic = r.itens_checklist;
        if (!ic || !ic.chave_medicao) continue;
        if (!porChave[ic.chave_medicao]) {
            porChave[ic.chave_medicao] = {
                chave: ic.chave_medicao,
                descricao: ic.descricao,
                unidade: ic.unidade,
                medicoes: 0
            };
        }
        porChave[ic.chave_medicao].medicoes++;
    }
    return Object.values(porChave).filter(c => c.medicoes >= 2);
}

// ================================================================
// GRAFICO SVG
// ================================================================
/**
 * Desenha a evolucao de uma medicao como SVG inline.
 * Sem biblioteca: sao poucos pontos e o SVG fica leve no celular.
 */
function graficoEvolucao(serie, opcoes = {}) {
    if (!serie || serie.length < 2) {
        return '<p class="text-sm text-slate-500">Sem medicoes suficientes para o grafico</p>';
    }

    const L = opcoes.largura || 320;
    const A = opcoes.altura || 160;
    const M = { t: 12, r: 12, b: 28, l: 38 };
    const iw = L - M.l - M.r;
    const ih = A - M.t - M.b;

    const kms = serie.map(p => Number(p.km_registrado));
    const vals = serie.map(p => Number(p.valor));
    const limite = serie[0].limite_minimo != null ? Number(serie[0].limite_minimo) : null;

    const kmMin = Math.min(...kms), kmMax = Math.max(...kms);
    let vMin = Math.min(...vals), vMax = Math.max(...vals);
    if (limite != null) { vMin = Math.min(vMin, limite); }
    const span = (vMax - vMin) || 1;
    vMin -= span * 0.15;
    vMax += span * 0.15;

    const x = (km) => M.l + ((km - kmMin) / ((kmMax - kmMin) || 1)) * iw;
    const y = (v)  => M.t + ih - ((v - vMin) / ((vMax - vMin) || 1)) * ih;

    const pontos = serie.map(p => `${x(p.km_registrado)},${y(p.valor)}`).join(' ');

    const corPonto = { verde: '#16a34a', amarelo: '#ca8a04',
                       vermelho: '#dc2626', sem_limite: '#64748b' };

    let svg = `<svg viewBox="0 0 ${L} ${A}" class="w-full" style="max-height:${A}px">`;

    // Linha do limite de servico
    if (limite != null) {
        svg += `<line x1="${M.l}" y1="${y(limite)}" x2="${L - M.r}" y2="${y(limite)}"
                 stroke="#dc2626" stroke-width="1" stroke-dasharray="4 3" opacity="0.6"/>`;
        svg += `<text x="${L - M.r}" y="${y(limite) - 4}" text-anchor="end"
                 font-size="9" fill="#dc2626">limite ${limite}</text>`;
    }

    // Eixos
    svg += `<line x1="${M.l}" y1="${M.t}" x2="${M.l}" y2="${M.t + ih}" stroke="#cbd5e1"/>`;
    svg += `<line x1="${M.l}" y1="${M.t + ih}" x2="${L - M.r}" y2="${M.t + ih}" stroke="#cbd5e1"/>`;

    // Serie
    svg += `<polyline points="${pontos}" fill="none" stroke="#dc2626" stroke-width="2"
             stroke-linejoin="round" stroke-linecap="round"/>`;

    serie.forEach(p => {
        const c = corPonto[p.semaforo] || '#64748b';
        svg += `<circle cx="${x(p.km_registrado)}" cy="${y(p.valor)}" r="4"
                 fill="${c}" stroke="#fff" stroke-width="1.5"/>`;
    });

    // Rotulos de km (primeiro e ultimo)
    svg += `<text x="${M.l}" y="${A - 8}" font-size="9" fill="#64748b">
             ${(kmMin / 1000).toFixed(0)}k</text>`;
    svg += `<text x="${L - M.r}" y="${A - 8}" text-anchor="end" font-size="9" fill="#64748b">
             ${(kmMax / 1000).toFixed(0)}k</text>`;

    // Rotulos de valor
    svg += `<text x="${M.l - 4}" y="${M.t + 4}" text-anchor="end" font-size="9" fill="#64748b">
             ${vMax.toFixed(1)}</text>`;
    svg += `<text x="${M.l - 4}" y="${M.t + ih}" text-anchor="end" font-size="9" fill="#64748b">
             ${vMin.toFixed(1)}</text>`;

    svg += '</svg>';
    return svg;
}

window.comparacao = {
    CORES_TENDENCIA,
    inspecoesComparaveis,
    compararInspecoes,
    formatarLinha,
    agruparPorCategoria,
    resumir,
    historicoMedicao,
    chavesComHistorico,
    graficoEvolucao
};
