// =====================================================================
// REVISAO-MOTO :: Recebimento (vistoria de entrada) - Fase 9
// =====================================================================
// Registra o estado da moto ao chegar na oficina, com 4 fotos
// obrigatorias e assinatura do cliente ANTES do servico comecar.
//
// Protege de "minha moto nao tinha esse risco no tanque".
// =====================================================================

const ANGULOS = [
    { campo: 'foto_frente',   rotulo: 'Frente',       icone: '🏍️' },
    { campo: 'foto_tras',     rotulo: 'Traseira',     icone: '🔙' },
    { campo: 'foto_lado_esq', rotulo: 'Lado esquerdo', icone: '⬅️' },
    { campo: 'foto_lado_dir', rotulo: 'Lado direito',  icone: '➡️' }
];

const NIVEIS_COMBUSTIVEL = [
    { valor: 0, rotulo: 'Vazio' },
    { valor: 1, rotulo: '1/4' },
    { valor: 2, rotulo: '1/2' },
    { valor: 3, rotulo: '3/4' },
    { valor: 4, rotulo: 'Cheio' }
];

// ================================================================
// CRUD
// ================================================================
async function criarRecebimento(motoId, kmEntrada) {
    if (!window.sb) throw new Error('Sem conexao');
    const { data, error } = await window.sb.from('recebimentos').insert({
        moto_id: motoId,
        km_entrada: kmEntrada || null
    }).select().single();
    if (error) throw error;
    return data;
}

async function atualizarRecebimento(id, campos) {
    const permitidos = [
        'inspecao_id', 'km_entrada',
        'foto_frente', 'foto_tras', 'foto_lado_esq', 'foto_lado_dir',
        'avarias_texto', 'avarias_marcacoes', 'nivel_combustivel',
        'tem_bau', 'tem_capacete', 'tem_documentos', 'outros_acessorios',
        'assinatura_cliente', 'nome_cliente', 'recebido_por'
    ];
    const update = {};
    for (const k of permitidos) if (k in campos) update[k] = campos[k];
    if (Object.keys(update).length === 0) return null;

    const { data, error } = await window.sb
        .from('recebimentos').update(update).eq('id', id).select().single();
    if (error) throw error;
    return data;
}

async function obterRecebimento(id) {
    const { data, error } = await window.sb
        .from('recebimentos').select('*').eq('id', id).single();
    if (error) throw error;
    return data;
}

/**
 * Recebimento aberto desta moto (sem inspecao vinculada ainda).
 * Permite retomar uma vistoria interrompida.
 */
async function recebimentoAbertoDaMoto(motoId) {
    const { data, error } = await window.sb
        .from('recebimentos').select('*')
        .eq('moto_id', motoId)
        .is('inspecao_id', null)
        .order('recebido_em', { ascending: false })
        .limit(1);
    if (error) return null;
    return (data && data.length) ? data[0] : null;
}

async function listarRecebimentos(filtros = {}) {
    let q = window.sb.from('vw_recebimentos').select('*')
        .order('recebido_em', { ascending: false });
    if (filtros.placa)   q = q.ilike('placa', `%${filtros.placa}%`);
    if (filtros.motoId)  q = q.eq('moto_id', filtros.motoId);
    if (filtros.limite)  q = q.limit(filtros.limite);
    const { data, error } = await q;
    if (error) { console.warn('listarRecebimentos:', error); return []; }
    return data || [];
}

// ================================================================
// FOTOS
// ================================================================
/**
 * Captura e envia uma das 4 fotos obrigatorias.
 * Reutiliza o modulo camera.js da Fase 3.
 */
async function capturarFotoAngulo(recebimentoId, campo, callbacks = {}) {
    if (!ANGULOS.some(a => a.campo === campo)) {
        throw new Error('Angulo invalido: ' + campo);
    }
    const { onProgresso } = callbacks;
    const onp = (m) => onProgresso && onProgresso(m);

    onp('Abrindo camera...');
    const arquivo = await window.tirarFoto();
    if (!arquivo) return null;

    onp('Comprimindo...');
    const blob = await window.comprimirImagem(arquivo);

    onp('Enviando...');
    const path = `recebimentos/${recebimentoId}/${campo}.jpg`;
    const url = await window.uploadFotoSupabase(blob, path);

    await atualizarRecebimento(recebimentoId, { [campo]: path });
    onp('Pronto');
    return { path, url };
}

// ================================================================
// VALIDACAO
// ================================================================
/**
 * Checa no servidor se o recebimento esta completo (4 fotos + assinatura).
 */
async function estaCompleto(recebimentoId) {
    const { data, error } = await window.sb
        .rpc('recebimento_completo', { p_recebimento_id: recebimentoId });
    if (error) { console.warn('recebimento_completo:', error); return null; }
    return (data && data.length) ? data[0] : null;
}

/**
 * Mesma validacao, local, para dar feedback sem ida ao servidor.
 */
function validarLocal(rec) {
    if (!rec) return { completo: false, fotos_faltando: 4, motivo: 'Sem recebimento' };

    const faltam = ANGULOS.filter(a => !rec[a.campo]).length;
    const temAssin = !!(rec.assinatura_cliente
        && rec.assinatura_cliente.length > 100
        && rec.nome_cliente
        && rec.nome_cliente.trim().length >= 3);

    let motivo = 'Completo';
    if (faltam > 0 && !temAssin) motivo = `Faltam ${faltam} foto(s) e a assinatura do cliente`;
    else if (faltam > 0)         motivo = `Faltam ${faltam} foto(s)`;
    else if (!temAssin)          motivo = 'Falta a assinatura do cliente';

    return { completo: faltam === 0 && temAssin, fotos_faltando: faltam,
             tem_assinatura: temAssin, motivo };
}

// ================================================================
// ASSINATURA DE ENTRADA
// ================================================================
async function assinarEntrada(recebimentoId, assinaturaBase64, nomeCliente, recebidoPor) {
    if (!assinaturaBase64 || assinaturaBase64.length < 100) {
        throw new Error('Assinatura invalida');
    }
    if (!nomeCliente || nomeCliente.trim().length < 3) {
        throw new Error('Informe o nome do cliente');
    }
    return atualizarRecebimento(recebimentoId, {
        assinatura_cliente: assinaturaBase64,
        nome_cliente: nomeCliente.trim(),
        recebido_por: recebidoPor || null
    });
}

/**
 * Vincula o recebimento a inspecao que acabou de ser criada.
 */
async function vincularInspecao(recebimentoId, inspecaoId) {
    return atualizarRecebimento(recebimentoId, { inspecao_id: inspecaoId });
}

// ================================================================
// MARCACOES DE AVARIA
// ================================================================
/**
 * Adiciona uma marcacao sobre o diagrama da moto.
 * x e y sao relativos (0 a 1) para funcionar em qualquer tamanho de tela.
 */
function adicionarMarcacao(marcacoes, { x, y, lado, nota }) {
    const lista = Array.isArray(marcacoes) ? marcacoes.slice() : [];
    lista.push({
        x: Math.max(0, Math.min(1, Number(x) || 0)),
        y: Math.max(0, Math.min(1, Number(y) || 0)),
        lado: lado || 'esq',
        nota: (nota || '').trim()
    });
    return lista;
}

function removerMarcacao(marcacoes, indice) {
    const lista = Array.isArray(marcacoes) ? marcacoes.slice() : [];
    lista.splice(indice, 1);
    return lista;
}

function textoNivelCombustivel(nivel) {
    const n = NIVEIS_COMBUSTIVEL.find(x => x.valor === Number(nivel));
    return n ? n.rotulo : '-';
}

window.recebimento = {
    ANGULOS,
    NIVEIS_COMBUSTIVEL,
    criarRecebimento,
    atualizarRecebimento,
    obterRecebimento,
    recebimentoAbertoDaMoto,
    listarRecebimentos,
    capturarFotoAngulo,
    estaCompleto,
    validarLocal,
    assinarEntrada,
    vincularInspecao,
    adicionarMarcacao,
    removerMarcacao,
    textoNivelCombustivel
};
