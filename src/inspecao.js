// =====================================================================
// REVISAO-MOTO :: Inspecao - logica de execucao do checklist
// =====================================================================
// Responsavel por:
// - Buscar motos por placa (autocomplete)
// - Sugerir revisao com base no km/tempo
// - Criar inspecao (em_andamento)
// - Carregar itens da revisao agrupados por categoria
// - Autosave debounced de cada item
// - Progresso agregado
// - Validacao de finalizacao
// =====================================================================

const AUTOSAVE_DELAY_MS = 500;

// Estado central da execucao (uma inspecao ativa por vez)
const estado = {
    moto: null,              // { id, placa, modelo_nome, km_atual, ... }
    revisao: null,           // { id, km, meses, tipo, ... }
    inspecao: null,          // { id, km_registrado, status, ... }
    itens: [],               // [{ id, categoria, descricao, ordem, ... }]
    respostas: {},           // { [item_id]: { status, valor_medido, observacao, foto_path } }
    salvamentoPendente: {},  // { [item_id]: timeout_id }
    progresso: null
};

// ================================================================
// BUSCA DE MOTOS
// ================================================================
async function buscarMotosPorPlaca(termo) {
    if (!termo || termo.length < 2) return [];
    const { data, error } = await window.sb
        .from('vw_motos_status')
        .select('id, placa, modelo, ano, proprietario, km_atual, modelo_id, ultima_inspecao')
        .ilike('placa', `%${termo.toUpperCase()}%`)
        .order('placa')
        .limit(10);
    if (error) { console.error(error); return []; }
    return data || [];
}

async function detalharMoto(motoId) {
    const { data, error } = await window.sb
        .from('vw_motos_status')
        .select('*')
        .eq('id', motoId)
        .single();
    if (error) throw error;
    return data;
}

// ================================================================
// SUGESTAO DE REVISAO (via funcao SQL)
// ================================================================
async function sugerirRevisao(motoId) {
    const { data, error } = await window.sb.rpc('sugerir_revisao', { p_moto_id: motoId });
    if (error) throw error;
    return (data && data[0]) || null;
}

async function listarRevisoesDoModelo(modeloId) {
    const { data, error } = await window.sb
        .from('revisoes')
        .select('id, km, meses, tipo, descricao')
        .eq('modelo_id', modeloId)
        .order('km');
    if (error) throw error;
    return data || [];
}

// ================================================================
// CRIACAO DA INSPECAO
// ================================================================
async function criarInspecao({ moto_id, revisao_id, km_registrado, mecanico_id, mecanico_nome }) {
    const { data, error } = await window.sb
        .from('inspecoes')
        .insert({
            moto_id, revisao_id, km_registrado,
            mecanico_id, mecanico_nome,
            status: 'em_andamento'
        })
        .select()
        .single();
    if (error) throw error;
    return data;
}

async function retomarInspecaoEmAndamento(motoId) {
    const { data, error } = await window.sb
        .from('inspecoes')
        .select('*')
        .eq('moto_id', motoId)
        .eq('status', 'em_andamento')
        .order('data_inicio', { ascending: false })
        .limit(1);
    if (error) throw error;
    return (data && data[0]) || null;
}

// ================================================================
// CARREGAMENTO DE ITENS
// ================================================================
async function carregarItensDaRevisao(revisaoId) {
    const { data, error } = await window.sb
        .from('vw_checklist_completo')
        .select('*')
        .eq('revisao_id', revisaoId)
        .order('ordem');
    if (error) throw error;
    return data || [];
}

async function carregarRespostasSalvas(inspecaoId) {
    const { data, error } = await window.sb
        .from('inspecoes_itens')
        .select('item_id, status, valor_medido, observacao, foto_url')
        .eq('inspecao_id', inspecaoId);
    if (error) throw error;
    const mapa = {};
    (data || []).forEach(r => { mapa[r.item_id] = r; });
    return mapa;
}

function agruparPorCategoria(itens) {
    const grupos = {};
    for (const item of itens) {
        const cat = item.categoria || 'Outros';
        if (!grupos[cat]) grupos[cat] = [];
        grupos[cat].push(item);
    }
    return grupos;
}

// ================================================================
// AUTOSAVE COM DEBOUNCE
// ================================================================
function agendarSalvamento(itemId, dados, callbacks = {}) {
    // Cancela salvamento anterior pendente para este item
    if (estado.salvamentoPendente[itemId]) {
        clearTimeout(estado.salvamentoPendente[itemId]);
    }

    // Atualiza estado local imediatamente
    estado.respostas[itemId] = { ...(estado.respostas[itemId] || {}), ...dados };

    if (callbacks.onPendente) callbacks.onPendente(itemId);

    // Agenda salvamento apos debounce
    estado.salvamentoPendente[itemId] = setTimeout(async () => {
        try {
            await salvarItem(itemId, estado.respostas[itemId]);
            if (callbacks.onSalvo) callbacks.onSalvo(itemId);
        } catch (e) {
            console.error('Erro ao salvar item', itemId, e);
            if (callbacks.onErro) callbacks.onErro(itemId, e);
        }
        delete estado.salvamentoPendente[itemId];
    }, AUTOSAVE_DELAY_MS);
}

async function salvarItem(itemId, dados) {
    if (!estado.inspecao) throw new Error('Sem inspecao ativa');
    const registro = {
        inspecao_id: estado.inspecao.id,
        item_id: itemId,
        status: dados.status || null,
        valor_medido: dados.valor_medido || null,
        observacao: dados.observacao || null,
        foto_url: dados.foto_path || dados.foto_url || null,
        verificado_em: new Date().toISOString()
    };
    const { error } = await window.sb
        .from('inspecoes_itens')
        .upsert(registro, { onConflict: 'inspecao_id,item_id' });
    if (error) throw error;
}

async function flushSalvamentos() {
    // Aguarda todos os salvamentos pendentes concluirem
    const promessas = Object.keys(estado.salvamentoPendente).map(itemId => {
        return new Promise((resolve) => {
            const check = () => {
                if (!estado.salvamentoPendente[itemId]) resolve();
                else setTimeout(check, 100);
            };
            check();
        });
    });
    await Promise.all(promessas);
}

// ================================================================
// PROGRESSO
// ================================================================
async function calcularProgresso(inspecaoId) {
    const { data, error } = await window.sb
        .from('vw_inspecao_progresso')
        .select('*')
        .eq('inspecao_id', inspecaoId)
        .single();
    if (error) { console.warn(error); return null; }
    return data;
}

// Calculo local rapido (para UI reagir sem round-trip)
function calcularProgressoLocal() {
    const total = estado.itens.length;
    if (total === 0) return { total: 0, preenchidos: 0, pct: 0 };
    const preenchidos = estado.itens.filter(i => {
        const r = estado.respostas[i.id];
        return r && ['ok','nao_ok','na'].includes(r.status);
    }).length;
    return { total, preenchidos, pct: Math.round(100 * preenchidos / total) };
}

// ================================================================
// VALIDACAO E FINALIZACAO
// ================================================================
async function podeFinalizarInspecao(inspecaoId) {
    const { data, error } = await window.sb.rpc('pode_finalizar_inspecao', { p_inspecao_id: inspecaoId });
    if (error) throw error;
    return (data && data[0]) || null;
}

async function finalizarInspecao(inspecaoId, observacoesGerais = '') {
    await flushSalvamentos();
    const validacao = await podeFinalizarInspecao(inspecaoId);
    if (!validacao || !validacao.pode_finalizar) {
        throw new Error(validacao ? validacao.motivo : 'Nao pode finalizar');
    }
    const { error } = await window.sb
        .from('inspecoes')
        .update({
            status: 'finalizada',
            data_fim: new Date().toISOString(),
            observacoes_gerais: observacoesGerais || null
        })
        .eq('id', inspecaoId);
    if (error) throw error;
    return true;
}

async function cancelarInspecao(inspecaoId) {
    const { error } = await window.sb
        .from('inspecoes')
        .update({ status: 'cancelada', data_fim: new Date().toISOString() })
        .eq('id', inspecaoId);
    if (error) throw error;
    return true;
}

// Exports globais
window.buscarMotosPorPlaca = buscarMotosPorPlaca;
window.detalharMoto = detalharMoto;
window.sugerirRevisao = sugerirRevisao;
window.listarRevisoesDoModelo = listarRevisoesDoModelo;
window.criarInspecao = criarInspecao;
window.retomarInspecaoEmAndamento = retomarInspecaoEmAndamento;
window.carregarItensDaRevisao = carregarItensDaRevisao;
window.carregarRespostasSalvas = carregarRespostasSalvas;
window.agruparPorCategoria = agruparPorCategoria;
window.agendarSalvamento = agendarSalvamento;
window.salvarItem = salvarItem;
window.flushSalvamentos = flushSalvamentos;
window.calcularProgresso = calcularProgresso;
window.calcularProgressoLocal = calcularProgressoLocal;
window.podeFinalizarInspecao = podeFinalizarInspecao;
window.finalizarInspecao = finalizarInspecao;
window.cancelarInspecao = cancelarInspecao;
window.estadoInspecao = estado;
