// =====================================================================
// REVISAO-MOTO :: Notificacoes locais
// =====================================================================
// Estrategia: notificacoes LOCAIS (nao Web Push com server).
// - Pede permissao ao usuario
// - Ao carregar dashboard, checa condicoes e dispara notificacoes:
//   * Motos com revisao 'proxima' ou 'atrasada'
//   * Inspecoes em andamento ha > 24h
// Requer permissao ativa e Service Worker registrado.
// =====================================================================

async function permissaoNotificacao() {
    if (!('Notification' in window)) return 'unsupported';
    return Notification.permission;
}

async function pedirPermissao() {
    if (!('Notification' in window)) return false;
    if (Notification.permission === 'granted') return true;
    if (Notification.permission === 'denied') return false;
    const p = await Notification.requestPermission();
    return p === 'granted';
}

/**
 * Dispara notificacao imediata via Service Worker (mais confiavel que new Notification()).
 * Fallback para new Notification() se SW nao disponivel.
 */
async function notificar(titulo, opcoes = {}) {
    if (!('Notification' in window) || Notification.permission !== 'granted') return false;

    const config = {
        body: opcoes.body || '',
        icon: opcoes.icon || './assets/icon-192.png',
        badge: opcoes.badge || './assets/icon-192.png',
        tag: opcoes.tag || 'revmoto',
        data: opcoes.data || {},
        vibrate: opcoes.vibrate || [200, 100, 200],
        requireInteraction: !!opcoes.requireInteraction
    };

    try {
        const reg = await navigator.serviceWorker.getRegistration();
        if (reg) {
            await reg.showNotification(titulo, config);
            return true;
        }
    } catch (_) { /* fallback */ }

    try {
        new Notification(titulo, config);
        return true;
    } catch (_) { return false; }
}

// ================================================================
// CHECAGEM DE CONDICOES
// ================================================================
/**
 * Ao carregar dashboard, checa motos e inspecoes e dispara notifs relevantes.
 * Evita spam usando chave 'ultima_notif_YYYY-MM-DD' em localStorage.
 */
async function checarECronizarAlertas() {
    if (!window.sb || !navigator.onLine) return;
    if (Notification.permission !== 'granted') return;

    const hoje = new Date().toISOString().substring(0, 10);

    // === 1. Motos com revisao proxima ou atrasada ===
    const chaveMotos = `rm_notif_motos_${hoje}`;
    if (!localStorage.getItem(chaveMotos)) {
        try {
            const { data } = await window.sb.from('vw_motos_com_status_revisao')
                .select('placa, status_revisao, proxima_km_prevista')
                .in('status_revisao', ['proxima', 'atrasada'])
                .limit(5);
            if (data && data.length > 0) {
                const t = window.t || ((k) => k);
                for (const m of data) {
                    await notificar(
                        t('notif.revisao_proxima'),
                        {
                            body: t('notif.revisao_proxima_desc', {
                                placa: m.placa,
                                km: (m.proxima_km_prevista || 0).toLocaleString('pt-BR')
                            }),
                            tag: `moto-${m.placa}`,
                            data: { url: `./historico.html`, placa: m.placa }
                        }
                    );
                }
                localStorage.setItem(chaveMotos, '1');
            }
        } catch (_) { /* silent */ }
    }

    // === 2. Inspecoes em andamento ha > 24h ===
    const chaveInsp = `rm_notif_insp_${hoje}`;
    if (!localStorage.getItem(chaveInsp)) {
        try {
            const ontem = new Date(Date.now() - 24*60*60*1000).toISOString();
            const { data } = await window.sb.from('inspecoes')
                .select('id, moto_id')
                .eq('status', 'em_andamento')
                .lt('data_inicio', ontem)
                .limit(1);
            if (data && data.length > 0) {
                const t = window.t || ((k) => k);
                await notificar(
                    t('notif.inspecao_pendente'),
                    {
                        body: t('notif.inspecao_pendente_desc'),
                        tag: 'insp-pendente',
                        data: { url: './historico.html' }
                    }
                );
                localStorage.setItem(chaveInsp, '1');
            }
        } catch (_) { /* silent */ }
    }
}

// ================================================================
// BOTAO DE PERMISSAO
// ================================================================
function criarBotaoPermissao(container) {
    if (!('Notification' in window)) return;
    if (Notification.permission === 'granted' || Notification.permission === 'denied') return;

    const btn = document.createElement('button');
    btn.className = 'text-xs px-3 py-1.5 bg-blue-100 hover:bg-blue-200 text-blue-800 rounded';
    btn.textContent = window.t ? window.t('notif.permitir') : 'Permitir notificações';
    btn.onclick = async () => {
        const ok = await pedirPermissao();
        if (ok) {
            btn.remove();
            checarECronizarAlertas();
        }
    };
    container.appendChild(btn);
}

window.notifs = {
    permissaoNotificacao,
    pedirPermissao,
    notificar,
    checarECronizarAlertas,
    criarBotaoPermissao
};
