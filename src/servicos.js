// =====================================================================
// REVISAO-MOTO :: Revisao rapida vs completa (Fase 10)
// =====================================================================
// Ate aqui a inspecao sempre carregava TODOS os itens da revisao
// prevista pelo km. Mas as vezes o cliente so quer trocar o oleo, e
// abrir um checklist de 22 itens para isso eh atrito puro.
//
// Tres modos:
//   completa - todos os itens da revisao (comportamento de sempre)
//   rapida   - so os itens do servico escolhido
//   avulsa   - so os itens que o mecanico adicionar na mao
// =====================================================================

const TIPOS_EXECUCAO = [
    { valor: 'completa', rotulo: 'Revisao completa',
      descricao: 'Todos os itens da revisao prevista pelo km' },
    { valor: 'rapida',   rotulo: 'Servico rapido',
      descricao: 'So os itens do servico escolhido' },
    { valor: 'avulsa',   rotulo: 'Avulsa',
      descricao: 'So o que voce adicionar na hora' }
];

// ================================================================
// CATALOGO
// ================================================================
async function listarServicos() {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .from('vw_servicos_rapidos').select('*').order('ordem');
    if (error) { console.warn('listarServicos:', error); return []; }
    return data || [];
}

async function obterServico(servicoId) {
    if (!window.sb) return null;
    const { data, error } = await window.sb
        .from('servicos_rapidos').select('*').eq('id', servicoId).single();
    if (error) return null;
    return data;
}

// ================================================================
// ITENS DO SERVICO
// ================================================================
/**
 * Quais itens do checklist entram neste servico.
 * A revisao serve so para dizer de onde tirar os itens - normalmente
 * a mais proxima do km atual da moto.
 */
async function itensDoServico(servicoId, revisaoId) {
    if (!window.sb) return [];
    const { data, error } = await window.sb.rpc('itens_do_servico_rapido', {
        p_servico_id: servicoId,
        p_revisao_id: revisaoId
    });
    if (error) { console.warn('itensDoServico:', error); return []; }
    return data || [];
}

/**
 * Previa de quantos itens o servico traz, para mostrar no card
 * antes do mecanico escolher.
 */
async function contarItens(servicoId, revisaoId) {
    const itens = await itensDoServico(servicoId, revisaoId);
    return {
        total: itens.length,
        obrigatorios: itens.filter(i => i.obrigatorio).length,
        com_foto: itens.filter(i => i.exige_foto).length,
        com_medicao: itens.filter(i => i.exige_medicao).length
    };
}

// ================================================================
// CRIACAO DA INSPECAO
// ================================================================
async function definirTipoExecucao(inspecaoId, tipo, servicoId) {
    if (!window.sb) throw new Error('Sem conexao');
    if (!TIPOS_EXECUCAO.some(t => t.valor === tipo)) {
        throw new Error('Tipo de execucao invalido: ' + tipo);
    }
    if (tipo === 'rapida' && !servicoId) {
        throw new Error('Servico rapido exige escolher qual servico');
    }

    const { error } = await window.sb.from('inspecoes').update({
        tipo_execucao: tipo,
        servico_rapido_id: tipo === 'rapida' ? servicoId : null
    }).eq('id', inspecaoId);
    if (error) throw error;
    return true;
}

// ================================================================
// FINALIZACAO
// ================================================================
/**
 * Pode finalizar? A regra muda com o tipo: uma revisao rapida nunca
 * teria todos os itens da revisao completa, entao a checagem da
 * Fase 3 reprovaria sempre.
 */
async function podeFinalizar(inspecaoId) {
    if (!window.sb) return null;
    const { data, error } = await window.sb
        .rpc('pode_finalizar_por_tipo', { p_inspecao_id: inspecaoId });
    if (error) { console.warn('pode_finalizar_por_tipo:', error); return null; }
    return (data && data.length) ? data[0] : null;
}

// ================================================================
// EXIBICAO
// ================================================================
function rotuloTipo(tipo, servicoNome) {
    const t = TIPOS_EXECUCAO.find(x => x.valor === tipo);
    if (!t) return tipo || '';
    if (tipo === 'rapida' && servicoNome) return `${t.rotulo}: ${servicoNome}`;
    return t.rotulo;
}

function formatarTempo(minutos) {
    const m = Number(minutos) || 0;
    if (m < 60) return `${m} min`;
    const h = Math.floor(m / 60);
    const r = m % 60;
    return r === 0 ? `${h}h` : `${h}h${String(r).padStart(2, '0')}`;
}

window.servicos = {
    TIPOS_EXECUCAO,
    listarServicos,
    obterServico,
    itensDoServico,
    contarItens,
    definirTipoExecucao,
    podeFinalizar,
    rotuloTipo,
    formatarTempo
};
