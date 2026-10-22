// =====================================================================
// REVISAO-MOTO :: Teste de rodagem estruturado (Fase 10)
// =====================================================================
// Antes: "Teste de rodagem" era um item visual unico do checklist, com
// status OK/N-OK e nada mais. Agora eh um sub-checklist proprio, com
// km percorridos, condicao da pista e quem pilotou.
// =====================================================================

const CONDICOES_PISTA = [
    { valor: 'seca',    rotulo: 'Seca' },
    { valor: 'molhada', rotulo: 'Molhada' },
    { valor: 'mista',   rotulo: 'Mista' }
];

// ================================================================
// CATALOGO
// ================================================================
async function listarItensRodagem() {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .from('rodagem_itens').select('*')
        .eq('ativo', true)
        .order('ordem');
    if (error) { console.warn('listarItensRodagem:', error); return []; }
    return data || [];
}

// ================================================================
// CABECALHO DO TESTE
// ================================================================
/**
 * Cria (ou retoma) o teste de rodagem de uma inspecao.
 * Uma inspecao tem no maximo um teste - o UNIQUE garante isso.
 */
async function iniciarRodagem(inspecaoId, kmInicial, pilotoNome) {
    if (!window.sb) throw new Error('Sem conexao');

    const existente = await obterRodagem(inspecaoId);
    if (existente) return existente;

    const { data, error } = await window.sb.from('inspecao_rodagem').insert({
        inspecao_id: inspecaoId,
        km_inicial: kmInicial || null,
        piloto_nome: pilotoNome || null
    }).select().single();
    if (error) throw error;
    return data;
}

async function obterRodagem(inspecaoId) {
    if (!window.sb) return null;
    const { data, error } = await window.sb
        .from('inspecao_rodagem').select('*')
        .eq('inspecao_id', inspecaoId)
        .limit(1);
    if (error) return null;
    return (data && data.length) ? data[0] : null;
}

async function atualizarRodagem(rodagemId, campos) {
    const permitidos = ['km_inicial', 'km_final', 'condicao_pista',
                        'observacoes', 'piloto_nome', 'finalizado_em'];
    const update = {};
    for (const k of permitidos) if (k in campos) update[k] = campos[k];
    if (Object.keys(update).length === 0) return null;

    const { data, error } = await window.sb
        .from('inspecao_rodagem').update(update).eq('id', rodagemId).select().single();
    if (error) throw error;
    return data;
}

async function finalizarRodagem(rodagemId, kmFinal) {
    return atualizarRodagem(rodagemId, {
        km_final: kmFinal || null,
        finalizado_em: new Date().toISOString()
    });
}

// ================================================================
// ITENS DO TESTE
// ================================================================
async function marcarItem(rodagemId, itemId, status, observacao) {
    if (!window.sb) throw new Error('Sem conexao');
    const { data, error } = await window.sb.from('inspecao_rodagem_itens')
        .upsert({
            rodagem_id: rodagemId,
            item_id: itemId,
            status,
            observacao: observacao || null,
            verificado_em: new Date().toISOString()
        }, { onConflict: 'rodagem_id,item_id' })
        .select().single();
    if (error) throw error;
    return data;
}

async function listarRespostas(rodagemId) {
    if (!window.sb) return {};
    const { data, error } = await window.sb
        .from('inspecao_rodagem_itens').select('*')
        .eq('rodagem_id', rodagemId);
    if (error) { console.warn('listarRespostas:', error); return {}; }

    const porItem = {};
    for (const r of (data || [])) porItem[r.item_id] = r;
    return porItem;
}

// ================================================================
// PROGRESSO
// ================================================================
async function progresso(rodagemId) {
    if (!window.sb) return null;
    const { data, error } = await window.sb
        .rpc('rodagem_completa', { p_rodagem_id: rodagemId });
    if (error) { console.warn('rodagem_completa:', error); return null; }
    return (data && data.length) ? data[0] : null;
}

/**
 * Mesma conta, local, para o contador da tela nao depender do servidor.
 */
function progressoLocal(itens, respostas) {
    const ativos = (itens || []).filter(i => i.ativo !== false);
    const obrig = ativos.filter(i => i.obrigatorio);
    const respondido = (id) => {
        const r = respostas[id];
        return r && ['ok', 'nao_ok', 'na'].includes(r.status);
    };
    const preenchidos = ativos.filter(i => respondido(i.id)).length;
    const pendentes = obrig.filter(i => !respondido(i.id)).length;
    const reprovados = ativos.filter(i => respostas[i.id]?.status === 'nao_ok').length;

    return {
        completo: pendentes === 0,
        total_itens: ativos.length,
        preenchidos,
        obrigatorios_pendentes: pendentes,
        reprovados,
        motivo: pendentes > 0
            ? `${pendentes} item(ns) obrigatorio(s) pendente(s)`
            : (reprovados > 0
                ? `Concluido com ${reprovados} reprovacao(oes)`
                : 'Teste concluido sem reprovacoes')
    };
}

function agruparPorCategoria(itens) {
    const grupos = {};
    for (const i of (itens || [])) {
        const c = i.categoria || 'Geral';
        if (!grupos[c]) grupos[c] = [];
        grupos[c].push(i);
    }
    return grupos;
}

async function rodagemDaInspecao(inspecaoId) {
    if (!window.sb) return null;
    const { data, error } = await window.sb
        .from('vw_rodagem').select('*')
        .eq('inspecao_id', inspecaoId)
        .limit(1);
    if (error) return null;
    return (data && data.length) ? data[0] : null;
}

window.rodagem = {
    CONDICOES_PISTA,
    listarItensRodagem,
    iniciarRodagem,
    obterRodagem,
    atualizarRodagem,
    finalizarRodagem,
    marcarItem,
    listarRespostas,
    progresso,
    progressoLocal,
    agruparPorCategoria,
    rodagemDaInspecao
};
