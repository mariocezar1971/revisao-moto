// =====================================================================
// REVISAO-MOTO :: Itens avulsos fora do checklist (Fase 8)
// =====================================================================
// O checklist eh fixo por revisao (14 a 24 itens). Mas o mecanico
// sempre acha algo que nao esta na lista. Este modulo permite
// registrar esses achados na mesma inspecao.
//
// No banco: inspecoes_itens com item_id NULL + descricao_avulsa
// preenchida. A constraint chk_item_ou_avulso garante que um dos
// dois esteja presente.
// =====================================================================

const CATEGORIAS_SUGERIDAS = [
    'Motor', 'Freios', 'Transmissao', 'Eletrica',
    'Suspensao', 'Pneus', 'Lubrificacao', 'Geral', 'Adicional'
];

/**
 * Adiciona um achado fora do checklist.
 */
async function adicionarAvulso(inspecaoId, { descricao, categoria, status, observacao }) {
    if (!window.sb) throw new Error('Sem conexao');
    if (!descricao || descricao.trim().length < 3) {
        throw new Error('Descreva o item encontrado');
    }

    const registro = {
        inspecao_id: inspecaoId,
        item_id: null,
        descricao_avulsa: descricao.trim(),
        categoria_avulsa: categoria || 'Adicional',
        status: status || 'nao_ok',
        observacao: observacao || null
    };

    const { data, error } = await window.sb
        .from('inspecoes_itens').insert(registro).select().single();
    if (error) throw error;
    return data;
}

async function atualizarAvulso(id, campos) {
    const permitidos = ['status', 'observacao', 'descricao_avulsa',
                        'categoria_avulsa', 'foto_url', 'valor_medido'];
    const update = {};
    for (const k of permitidos) {
        if (k in campos) update[k] = campos[k];
    }
    if (Object.keys(update).length === 0) return null;

    const { data, error } = await window.sb
        .from('inspecoes_itens').update(update).eq('id', id).select().single();
    if (error) throw error;
    return data;
}

async function removerAvulso(id) {
    const { error } = await window.sb
        .from('inspecoes_itens').delete().eq('id', id).is('item_id', null);
    if (error) throw error;
}

async function listarAvulsos(inspecaoId) {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .from('inspecoes_itens').select('*')
        .eq('inspecao_id', inspecaoId)
        .is('item_id', null)
        .order('id');
    if (error) { console.warn('listarAvulsos:', error); return []; }
    return data || [];
}

/**
 * Lista todos os itens da inspecao (catalogo + avulsos) com semaforo,
 * usando a view unificada.
 */
async function listarTodosItens(inspecaoId) {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .from('vw_inspecao_itens_completo').select('*')
        .eq('inspecao_id', inspecaoId)
        .order('categoria')
        .order('ordem', { nullsFirst: false });
    if (error) { console.warn('listarTodosItens:', error); return []; }
    return data || [];
}

/**
 * Conta quantos avulsos existem - util para o badge na UI.
 */
async function contarAvulsos(inspecaoId) {
    if (!window.sb) return 0;
    const { count, error } = await window.sb
        .from('inspecoes_itens')
        .select('id', { count: 'exact', head: true })
        .eq('inspecao_id', inspecaoId)
        .is('item_id', null);
    if (error) return 0;
    return count || 0;
}

window.avulsos = {
    adicionarAvulso,
    atualizarAvulso,
    removerAvulso,
    listarAvulsos,
    listarTodosItens,
    contarAvulsos,
    CATEGORIAS_SUGERIDAS
};
