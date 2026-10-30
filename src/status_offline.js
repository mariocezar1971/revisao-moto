// =====================================================================
// REVISAO-MOTO :: Status Offline - indicador visual reutilizavel
// =====================================================================
// Widget flutuante no canto INFERIOR ESQUERDO que mostra:
// - Bolinha colorida: verde (online), amarela (sincronizando), vermelha (offline)
// - Contador de pendencias na fila (quando > 0)
// - Ao clicar: forca sincronizacao
//
// Por que inferior esquerdo, e nao superior direito como nasceu:
// no canto superior direito ele ficava exatamente sobre o botao "Sair"
// do cabecalho, com z-index 60 - e um botao coberto por um widget
// opaco simplesmente nao existe para quem usa. O app passou semanas
// parecendo nao ter logout por causa disso.
//
// Os quatro cantos hoje: este (inferior esquerdo), o dark mode
// (inferior direito), o menu de conta (dentro do cabecalho, a direita)
// e nada no superior esquerdo, que e da seta de voltar.
// Antes de mover qualquer um deles, confira se nao vai cobrir outro.
// =====================================================================

let statusEl = null;
let statusAtual = 'online';   // online | offline | sync | erro
let contadorPendentes = 0;

function criarBadge() {
    if (statusEl) return statusEl;
    statusEl = document.createElement('div');
    statusEl.id = 'status-offline-badge';
    statusEl.style.cssText = `
        position: fixed;
        bottom: 12px;
        left: 12px;
        z-index: 45;
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 6px 10px;
        border-radius: 999px;
        background: rgba(255,255,255,0.95);
        box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        font-size: 12px;
        font-weight: 600;
        cursor: pointer;
        transition: all .2s;
    `;
    statusEl.onclick = onClickBadge;
    document.body.appendChild(statusEl);
    return statusEl;
}

function renderBadge() {
    if (!statusEl) criarBadge();

    let cor, texto, corTexto;
    switch (statusAtual) {
        case 'online':
            cor = '#22c55e';
            corTexto = '#166534';
            texto = contadorPendentes > 0
                ? `${contadorPendentes} pendente${contadorPendentes > 1 ? 's' : ''}`
                : 'Online';
            break;
        case 'sync':
            cor = '#f59e0b';
            corTexto = '#92400e';
            texto = 'Sincronizando…';
            break;
        case 'offline':
            cor = '#dc2626';
            corTexto = '#991b1b';
            texto = contadorPendentes > 0
                ? `Offline · ${contadorPendentes} na fila`
                : 'Offline';
            break;
        case 'erro':
            cor = '#dc2626';
            corTexto = '#991b1b';
            texto = 'Falha ao sincronizar';
            break;
    }

    statusEl.innerHTML = `
        <span style="width:8px;height:8px;border-radius:50%;background:${cor};display:inline-block;${
            statusAtual === 'sync' ? 'animation: pulse 1s infinite;' : ''
        }"></span>
        <span style="color:${corTexto}">${texto}</span>
    `;
}

async function atualizarContador() {
    if (window.offline) {
        try { contadorPendentes = await window.offline.contarPendentes(); }
        catch(_) { contadorPendentes = 0; }
    }
}

async function atualizar() {
    await atualizarContador();
    if (statusAtual === 'sync') { renderBadge(); return; }
    statusAtual = navigator.onLine ? 'online' : 'offline';
    renderBadge();
}

function onClickBadge() {
    if (!navigator.onLine) {
        alert('Sem conexão. As mudanças ficarão salvas localmente e sincronizarão quando voltar online.');
        return;
    }
    if (window.offline && contadorPendentes > 0) {
        window.offline.sincronizar();
    }
}

// Injetar CSS de animacao
function injetarCss() {
    if (document.getElementById('status-offline-css')) return;
    const style = document.createElement('style');
    style.id = 'status-offline-css';
    style.textContent = `
        @keyframes pulse {
            0%,100% { opacity: 1; transform: scale(1); }
            50%     { opacity: .5; transform: scale(1.3); }
        }
    `;
    document.head.appendChild(style);
}

// ================================================================
// BOOT
// ================================================================
function iniciarStatusOffline() {
    injetarCss();
    criarBadge();
    atualizar();

    // Ouvir mudancas de conectividade
    window.addEventListener('online',  atualizar);
    window.addEventListener('offline', atualizar);

    // Ouvir eventos do modulo offline
    window.addEventListener('offline:sync-inicio', () => {
        statusAtual = 'sync'; renderBadge();
    });
    window.addEventListener('offline:sync-fim', (e) => {
        statusAtual = navigator.onLine ? 'online' : 'offline';
        contadorPendentes = e.detail.restam || 0;
        renderBadge();
        if (e.detail.falhas > 0 && e.detail.sucessos === 0) {
            statusAtual = 'erro'; renderBadge();
            setTimeout(atualizar, 3000);
        }
    });
    window.addEventListener('offline:offline', atualizar);

    // Refresh periodico do contador
    setInterval(atualizarContador, 5000);
}

// Auto-init
if (typeof window !== 'undefined') {
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', iniciarStatusOffline);
    } else {
        iniciarStatusOffline();
    }
}

window.statusOffline = { atualizar, iniciar: iniciarStatusOffline };
