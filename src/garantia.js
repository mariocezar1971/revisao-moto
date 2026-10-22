// =====================================================================
// REVISAO-MOTO :: Garantia (Fase 10)
// =====================================================================
// Quem paga este servico: a fabrica, a propria oficina, ou o cliente.
//
// Base legal da garantia da oficina: CDC art. 26, II - o prazo para
// reclamar de vicio em servico duravel eh de 90 dias, contados da
// entrega. O trigger no banco abre essa janela ao finalizar um servico
// pago; um retorno EM garantia nao abre janela nova, senao a garantia
// se renovaria para sempre.
// =====================================================================

const TIPOS_COBRANCA = [
    { valor: 'pago',             rotulo: 'Pago pelo cliente', cobra: true,
      descricao: 'Servico normal, cliente paga' },
    { valor: 'garantia_fabrica', rotulo: 'Garantia de fabrica', cobra: false,
      descricao: 'Royal Enfield cobre - nao cobrar do cliente' },
    { valor: 'garantia_oficina', rotulo: 'Garantia da oficina', cobra: false,
      descricao: 'Retorno de servico nosso dentro dos 90 dias' },
    { valor: 'cortesia',         rotulo: 'Cortesia', cobra: false,
      descricao: 'Sem cobranca, por decisao da oficina' }
];

const DIAS_GARANTIA_OFICINA = 90;

function infoTipo(tipo) {
    return TIPOS_COBRANCA.find(t => t.valor === tipo) || TIPOS_COBRANCA[0];
}

function cobraDoCliente(tipo) {
    return infoTipo(tipo).cobra;
}

// ================================================================
// CONSULTA
// ================================================================
/**
 * A moto tem servico nosso ainda dentro da garantia?
 * Retorna null quando nao ha.
 */
async function garantiaVigente(motoId) {
    if (!window.sb) return null;
    const { data, error } = await window.sb
        .rpc('garantia_vigente', { p_moto_id: motoId });
    if (error) { console.warn('garantiaVigente:', error); return null; }
    return (data && data.length) ? data[0] : null;
}

async function listarGarantias(filtros = {}) {
    if (!window.sb) return [];
    let q = window.sb.from('vw_garantias_vigentes').select('*');
    if (filtros.motoId) q = q.eq('moto_id', filtros.motoId);
    if (filtros.ateDias != null) {
        const limite = new Date();
        limite.setDate(limite.getDate() + Number(filtros.ateDias));
        q = q.lte('garantia_ate', limite.toISOString().substring(0, 10));
    }
    const { data, error } = await q;
    if (error) { console.warn('listarGarantias:', error); return []; }
    return data || [];
}

// ================================================================
// APLICAR NA INSPECAO
// ================================================================
async function definirTipoCobranca(inspecaoId, tipo, observacao, inspecaoOrigem) {
    if (!window.sb) throw new Error('Sem conexao');
    if (!TIPOS_COBRANCA.some(t => t.valor === tipo)) {
        throw new Error('Tipo de cobranca invalido: ' + tipo);
    }

    const update = { tipo_cobranca: tipo };
    if (observacao !== undefined) update.garantia_obs = observacao || null;
    if (inspecaoOrigem) update.inspecao_origem = inspecaoOrigem;

    const { error } = await window.sb
        .from('inspecoes').update(update).eq('id', inspecaoId);
    if (error) throw error;
    return true;
}

/**
 * Ao abrir uma inspecao, checa se a moto tem garantia vigente e
 * sugere o tipo de cobranca. Quem decide eh o mecanico - a funcao
 * so levanta a mao.
 */
async function sugerirCobranca(motoId) {
    const g = await garantiaVigente(motoId);
    if (!g || !g.tem_garantia) {
        return { sugestao: 'pago', motivo: 'Sem garantia vigente', garantia: null };
    }
    return {
        sugestao: 'garantia_oficina',
        motivo: `OS ${g.numero_os} ainda em garantia por ${g.dias_restantes} dia(s)`,
        garantia: g
    };
}

// ================================================================
// FORMATACAO
// ================================================================
function formatarPrazo(garantia) {
    if (!garantia || !garantia.garantia_ate) return '';
    const dias = Number(garantia.dias_restantes);
    const data = new Date(garantia.garantia_ate + 'T12:00:00')
        .toLocaleDateString('pt-BR');

    if (dias < 0)  return `Garantia vencida em ${data}`;
    if (dias === 0) return `Garantia vence hoje (${data})`;
    if (dias === 1) return `Garantia vence amanha (${data})`;
    return `Garantia ate ${data} (${dias} dias)`;
}

/**
 * Quando o servico eh coberto, o orcamento nao deve ser cobrado.
 * Devolve o texto que aparece no lugar do total.
 */
function textoOrcamento(tipo, totalGeral) {
    const brl = (v) => (Number(v) || 0).toLocaleString('pt-BR',
        { style: 'currency', currency: 'BRL' });

    if (cobraDoCliente(tipo)) return brl(totalGeral);

    const info = infoTipo(tipo);
    return `${brl(0)} - ${info.rotulo} (valor de referencia ${brl(totalGeral)})`;
}

window.garantia = {
    TIPOS_COBRANCA,
    DIAS_GARANTIA_OFICINA,
    infoTipo,
    cobraDoCliente,
    garantiaVigente,
    listarGarantias,
    definirTipoCobranca,
    sugerirCobranca,
    formatarPrazo,
    textoOrcamento
};
