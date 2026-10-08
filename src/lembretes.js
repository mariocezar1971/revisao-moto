// =====================================================================
// REVISAO-MOTO :: Lembretes ao cliente - Fase 9
// =====================================================================
// As notificacoes da Fase 7 avisam o MECANICO. Este modulo avisa o
// CLIENTE, via link wa.me com mensagem pre-preenchida.
//
// Escolha de projeto: link wa.me em vez da API oficial do WhatsApp
// Business. A API custa por mensagem e exige aprovacao de template;
// o link abre o app com o texto pronto e o mecanico so aperta enviar.
// O custo eh um toque a mais; o ganho eh zero mensalidade e zero
// burocracia de aprovacao.
// =====================================================================

const TEMPLATES = {
    revisao_proxima: (d) =>
        `Olá ${primeiroNome(d.proprietario)}! Aqui é da oficina.\n\n` +
        `Sua ${d.modelo} placa ${d.placa} está chegando na revisão de ` +
        `${fmtKm(d.proxima_km_prevista)} km.\n\n` +
        `Quer agendar? É só responder por aqui.`,

    revisao_atrasada: (d) =>
        `Olá ${primeiroNome(d.proprietario)}! Aqui é da oficina.\n\n` +
        `Sua ${d.modelo} placa ${d.placa} já passou da revisão de ` +
        `${fmtKm(d.proxima_km_prevista)} km.\n\n` +
        `Rodar com a revisão atrasada desgasta mais e pode sair caro depois. ` +
        `Vamos agendar?`,

    recomendacao: (d) =>
        `Olá ${primeiroNome(d.proprietario)}! Aqui é da oficina.\n\n` +
        `Na última revisão da sua ${d.modelo} (placa ${d.placa}) anotamos ` +
        `que ${d.item} vai precisar de atenção por volta dos ` +
        `${fmtKm(d.previsao_km)} km.\n\n` +
        `Quer que eu já separe a peça?`,

    pronta: (d) =>
        `Olá ${primeiroNome(d.proprietario)}! Aqui é da oficina.\n\n` +
        `Sua ${d.modelo} placa ${d.placa} está pronta para retirada.\n` +
        `OS ${d.numero_os}.\n\n` +
        `Qualquer dúvida é só chamar.`
};

function primeiroNome(nome) {
    if (!nome) return '';
    return String(nome).trim().split(/\s+/)[0];
}

function fmtKm(km) {
    return (Number(km) || 0).toLocaleString('pt-BR');
}

/**
 * Normaliza telefone brasileiro para o formato do wa.me (55DDNNNNNNNNN).
 * Aceita "(27) 99988-7766", "27999887766", "+55 27 99988-7766".
 */
function normalizarTelefone(tel) {
    if (!tel) return null;
    let d = String(tel).replace(/\D/g, '');

    if (d.startsWith('55') && (d.length === 12 || d.length === 13)) return d;
    if (d.length === 10 || d.length === 11) return '55' + d;   // DDD + numero
    if (d.length === 8 || d.length === 9) return null;          // sem DDD
    return d.length >= 12 ? d : null;
}

/**
 * Monta o link wa.me com a mensagem ja preenchida.
 * Abrir este link no celular abre o WhatsApp na conversa certa.
 */
function montarLinkWhatsapp(telefone, mensagem) {
    const num = normalizarTelefone(telefone);
    if (!num) return null;
    return `https://wa.me/${num}?text=${encodeURIComponent(mensagem)}`;
}

function montarMensagem(tipo, dados) {
    const t = TEMPLATES[tipo];
    if (!t) return null;
    return t(dados || {});
}

// ================================================================
// FILA DE LEMBRETES
// ================================================================
/**
 * Motos que precisam de lembrete e nao receberam nos ultimos 30 dias.
 */
async function listarPendentes() {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .from('vw_lembretes_pendentes').select('*')
        .order('status_revisao');
    if (error) { console.warn('listarPendentes:', error); return []; }
    return data || [];
}

async function contarPendentes() {
    if (!window.sb) return 0;
    const { count, error } = await window.sb
        .from('vw_lembretes_pendentes')
        .select('moto_id', { count: 'exact', head: true });
    if (error) return 0;
    return count || 0;
}

/**
 * Abre o WhatsApp e registra o envio.
 * O registro so acontece depois que o link abre - se o mecanico
 * desistir no app do WhatsApp, o lembrete ja consta como enviado.
 * Isso eh intencional: melhor nao insistir do que incomodar o cliente.
 */
async function enviarLembrete(item, enviadoPor) {
    const tipo = item.tipo_lembrete || 'revisao_proxima';
    const msg = montarMensagem(tipo, item);
    const link = montarLinkWhatsapp(item.telefone, msg);

    if (!link) {
        throw new Error(`Telefone invalido: ${item.telefone || '(vazio)'}`);
    }

    window.open(link, '_blank');
    await registrarEnvio(item.moto_id, tipo, msg, item.km_atual, enviadoPor);
    return { link, mensagem: msg };
}

async function registrarEnvio(motoId, tipo, mensagem, kmRef, enviadoPor) {
    if (!window.sb) return null;
    const { data, error } = await window.sb.from('lembretes_cliente').insert({
        moto_id: motoId,
        tipo,
        canal: 'whatsapp',
        mensagem,
        km_referencia: kmRef || null,
        enviado_por: enviadoPor || null
    }).select().single();
    if (error) { console.warn('registrarEnvio:', error); return null; }
    return data;
}

async function historicoDaMoto(motoId, limite = 10) {
    if (!window.sb) return [];
    const { data, error } = await window.sb
        .from('lembretes_cliente').select('*')
        .eq('moto_id', motoId)
        .order('enviado_em', { ascending: false })
        .limit(limite);
    if (error) return [];
    return data || [];
}

/**
 * Avisar que a moto esta pronta - usado ao finalizar a inspecao.
 */
function linkMotoPronta({ telefone, proprietario, modelo, placa, numero_os }) {
    const msg = montarMensagem('pronta', { proprietario, modelo, placa, numero_os });
    return montarLinkWhatsapp(telefone, msg);
}

window.lembretes = {
    TEMPLATES,
    normalizarTelefone,
    montarLinkWhatsapp,
    montarMensagem,
    listarPendentes,
    contarPendentes,
    enviarLembrete,
    registrarEnvio,
    historicoDaMoto,
    linkMotoPronta
};
