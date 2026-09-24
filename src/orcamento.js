// =====================================================================
// REVISAO-MOTO :: Orcamento - pecas e mao de obra (Fase 8)
// =====================================================================
// Gerencia pecas e servicos de uma inspecao e a aprovacao previa do
// orcamento pelo cliente.
//
// Base legal da aprovacao previa: CDC art. 40 - o fornecedor de servico
// deve entregar orcamento previo, e o servico so pode ser executado
// apos autorizacao expressa do consumidor.
// =====================================================================

const VALOR_HORA_PADRAO = 120.00;

// ================================================================
// CATALOGO DE PECAS
// ================================================================
async function listarPecas(modeloId) {
    if (!window.sb) return [];
    let q = window.sb.from('pecas').select('*').eq('ativo', true).order('descricao');
    if (modeloId) q = q.or(`modelo_id.is.null,modelo_id.eq.${modeloId}`);
    const { data, error } = await q;
    if (error) { console.warn('listarPecas:', error); return []; }
    return data || [];
}

async function buscarPecas(termo, modeloId) {
    if (!window.sb || !termo || termo.length < 2) return [];
    let q = window.sb.from('pecas').select('*').eq('ativo', true)
        .or(`descricao.ilike.%${termo}%,codigo_re.ilike.%${termo}%`)
        .limit(10);
    if (modeloId) q = q.or(`modelo_id.is.null,modelo_id.eq.${modeloId}`);
    const { data, error } = await q;
    if (error) { console.warn('buscarPecas:', error); return []; }
    return data || [];
}

// ================================================================
// PECAS DA INSPECAO
// ================================================================
/**
 * Adiciona peca do catalogo ao orcamento.
 * O preco eh copiado (preco_aplicado) para o orcamento nao mudar
 * se o catalogo for reajustado depois.
 */
async function adicionarPeca(inspecaoId, { pecaId, descricaoLivre, quantidade, precoUnitario, itemId }) {
    if (!window.sb) throw new Error('Sem conexao');

    const registro = {
        inspecao_id: inspecaoId,
        quantidade: Number(quantidade) || 1,
        preco_aplicado: Number(precoUnitario) || 0
    };
    if (pecaId) registro.peca_id = pecaId;
    if (descricaoLivre) registro.descricao_livre = descricaoLivre;
    if (itemId) registro.item_id = itemId;

    const { data, error } = await window.sb
        .from('inspecao_pecas').insert(registro).select().single();
    if (error) throw error;
    return data;
}

async function removerPeca(id) {
    const { error } = await window.sb.from('inspecao_pecas').delete().eq('id', id);
    if (error) throw error;
}

async function listarPecasDaInspecao(inspecaoId) {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .from('inspecao_pecas')
        .select('*, pecas(codigo_re, descricao), itens_checklist(descricao)')
        .eq('inspecao_id', inspecaoId)
        .order('id');
    if (error) { console.warn('listarPecasDaInspecao:', error); return []; }
    return data || [];
}

// ================================================================
// SERVICOS (MAO DE OBRA)
// ================================================================
async function adicionarServico(inspecaoId, { descricao, horas, valorHora }) {
    if (!window.sb) throw new Error('Sem conexao');
    const { data, error } = await window.sb.from('inspecao_servicos').insert({
        inspecao_id: inspecaoId,
        descricao,
        horas: Number(horas) || 0,
        valor_hora: Number(valorHora) || VALOR_HORA_PADRAO
    }).select().single();
    if (error) throw error;
    return data;
}

async function removerServico(id) {
    const { error } = await window.sb.from('inspecao_servicos').delete().eq('id', id);
    if (error) throw error;
}

async function listarServicosDaInspecao(inspecaoId) {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .from('inspecao_servicos').select('*')
        .eq('inspecao_id', inspecaoId).order('id');
    if (error) { console.warn('listarServicosDaInspecao:', error); return []; }
    return data || [];
}

// ================================================================
// TOTAIS
// ================================================================
async function totaisDoOrcamento(inspecaoId) {
    if (!window.sb) return null;
    const { data, error } = await window.sb
        .from('vw_orcamento_inspecao').select('*')
        .eq('inspecao_id', inspecaoId).single();
    if (error) { console.warn('totaisDoOrcamento:', error); return null; }
    return data;
}

/**
 * Calcula totais localmente (para funcionar offline).
 */
function calcularTotaisLocal(pecas, servicos) {
    const totalPecas = (pecas || []).reduce(
        (s, p) => s + (Number(p.quantidade) || 0) * (Number(p.preco_aplicado) || 0), 0);
    const totalServicos = (servicos || []).reduce(
        (s, v) => s + (Number(v.horas) || 0) * (Number(v.valor_hora) || 0), 0);
    const totalHoras = (servicos || []).reduce((s, v) => s + (Number(v.horas) || 0), 0);
    return {
        total_pecas: totalPecas,
        total_servicos: totalServicos,
        total_geral: totalPecas + totalServicos,
        total_horas: totalHoras,
        qtd_pecas: (pecas || []).length,
        qtd_servicos: (servicos || []).length
    };
}

function formatarMoeda(valor) {
    return (Number(valor) || 0).toLocaleString('pt-BR', {
        style: 'currency', currency: 'BRL'
    });
}

// ================================================================
// APROVACAO PREVIA (CDC art. 40)
// ================================================================
/**
 * Grava a assinatura de aprovacao do orcamento.
 * Distinta da assinatura de conclusao: esta autoriza a EXECUCAO.
 */
async function aprovarOrcamento(inspecaoId, assinaturaBase64, nomeAprovador) {
    if (!window.sb) throw new Error('Sem conexao');
    if (!assinaturaBase64 || assinaturaBase64.length < 100) {
        throw new Error('Assinatura invalida');
    }
    if (!nomeAprovador || nomeAprovador.trim().length < 3) {
        throw new Error('Informe o nome de quem aprovou');
    }

    const { error } = await window.sb.from('inspecoes').update({
        assinatura_orcamento: assinaturaBase64,
        nome_aprovador_orcamento: nomeAprovador.trim(),
        orcamento_aprovado_em: new Date().toISOString()
    }).eq('id', inspecaoId);
    if (error) throw error;
    return true;
}

async function orcamentoAprovado(inspecaoId) {
    const t = await totaisDoOrcamento(inspecaoId);
    return !!(t && t.orcamento_aprovado);
}

/**
 * Regra: se ha orcamento com valor, ele precisa estar aprovado
 * antes da inspecao ser finalizada.
 */
async function podeExecutar(inspecaoId) {
    const t = await totaisDoOrcamento(inspecaoId);
    if (!t) return { pode: true, motivo: 'Sem orcamento' };
    if (Number(t.total_geral) === 0) return { pode: true, motivo: 'Orcamento zerado' };
    if (t.orcamento_aprovado) {
        return { pode: true, motivo: `Aprovado por ${t.nome_aprovador_orcamento}` };
    }
    return {
        pode: false,
        motivo: `Orcamento de ${formatarMoeda(t.total_geral)} aguarda aprovacao do cliente`
    };
}

window.orcamento = {
    listarPecas,
    buscarPecas,
    adicionarPeca,
    removerPeca,
    listarPecasDaInspecao,
    adicionarServico,
    removerServico,
    listarServicosDaInspecao,
    totaisDoOrcamento,
    calcularTotaisLocal,
    formatarMoeda,
    aprovarOrcamento,
    orcamentoAprovado,
    podeExecutar,
    VALOR_HORA_PADRAO
};
