// =====================================================================
// REVISAO-MOTO :: Menu de sessao (sair de qualquer tela)
// =====================================================================
// O logout existia desde a Fase 0, mas o botao "Sair" so estava no
// dashboard. Quem entrasse numa inspecao, no historico ou na vistoria
// de entrada nao tinha como sair sem voltar ao index - e num celular,
// com o app em modo standalone, nem sempre ha botao de voltar.
//
// Este modulo injeta o mesmo menu em todas as telas autenticadas e,
// antes de encerrar, confere se ha trabalho que ainda nao subiu.
// Sair com a fila offline cheia perde o que foi feito na garagem.
//
// O que NAO eh apagado ao sair: tema, idioma, flag de onboarding e a
// fila offline. Tema e idioma sao preferencias do aparelho, nao da
// pessoa; a fila eh trabalho, e trabalho nao se descarta no logout.
// =====================================================================

// Chaves que sobrevivem ao logout (preferencias do aparelho)
const CHAVES_PRESERVADAS = ['rm_tema', 'rm_idioma', 'rm_onboarding_visto'];

// ================================================================
// ESTADO DA SESSAO
// ================================================================
async function usuarioAtual() {
    if (!window.sb) return null;
    try {
        const { data: { session } } = await window.sb.auth.getSession();
        return session ? session.user : null;
    } catch (e) {
        console.warn('usuarioAtual:', e);
        return null;
    }
}

function nomeExibicao(user) {
    if (!user) return '';
    const meta = user.user_metadata || {};
    if (meta.nome_completo) return String(meta.nome_completo).split(' ')[0];
    return (user.email || '').split('@')[0];
}

function iniciais(user) {
    const n = nomeExibicao(user);
    return n ? n.slice(0, 2).toUpperCase() : '?';
}

// ================================================================
// PENDENCIAS ANTES DE SAIR
// ================================================================
/**
 * O que seria perdido ou esquecido se a pessoa sair agora.
 *
 * fila        - operacoes no IndexedDB que ainda nao subiram.
 *               Este eh o risco real: sair com a fila cheia e
 *               entrar com outro usuario embaralha o dono do
 *               trabalho, e limpar o navegador perde tudo.
 * emAndamento - inspecoes abertas no banco. Nao se perde nada,
 *               mas vale lembrar antes de fechar o app.
 */
async function pendencias() {
    const r = { fila: 0, fotos: 0, emAndamento: 0, offline: !navigator.onLine };

    if (window.offline) {
        try {
            r.fila = await window.offline.contarPendentes();
            const fotos = await window.offline.listarChavesFotoPendente();
            r.fotos = (fotos || []).length;
        } catch (e) {
            console.warn('pendencias/offline:', e);
        }
    }

    if (window.sb && navigator.onLine) {
        try {
            const { count, error } = await window.sb
                .from('inspecoes')
                .select('id', { count: 'exact', head: true })
                .eq('status', 'em_andamento');
            if (!error && typeof count === 'number') r.emAndamento = count;
        } catch (e) {
            console.warn('pendencias/inspecoes:', e);
        }
    }

    return r;
}

function textoPendencias(p) {
    const partes = [];
    if (p.fila > 0)  partes.push(`${p.fila} ${p.fila === 1 ? 'alteração' : 'alterações'} na fila`);
    if (p.fotos > 0) partes.push(`${p.fotos} ${p.fotos === 1 ? 'foto' : 'fotos'} para enviar`);
    if (!partes.length) return '';
    return partes.join(' e ') + (p.offline ? ', e você está offline' : '');
}

// ================================================================
// SAIR
// ================================================================
/**
 * Encerra a sessao. Com trabalho na fila, pede confirmacao -
 * o dado continua no aparelho, mas o proximo login pode ser de
 * outra pessoa, e ai a fila vira dor de cabeca.
 */
async function sair(opcoes = {}) {
    const p = await pendencias();
    const aviso = textoPendencias(p);

    if (aviso && !opcoes.forcar) {
        const ok = confirm(
            `Ainda há ${aviso}.\n\n` +
            `Esse trabalho fica guardado no aparelho e sobe quando houver ` +
            `internet, mas só se você entrar com a mesma conta.\n\n` +
            `Sair mesmo assim?`
        );
        if (!ok) return false;
    }

    // Preferencias do aparelho sobrevivem ao logout
    const guardado = {};
    CHAVES_PRESERVADAS.forEach(k => {
        try {
            const v = localStorage.getItem(k);
            if (v !== null) guardado[k] = v;
        } catch (e) { /* storage bloqueado */ }
    });

    try {
        if (window.offline && window.offline.pararAutoSync) {
            window.offline.pararAutoSync();
        }
    } catch (e) { /* segue */ }

    try {
        if (window.sb) await window.sb.auth.signOut();
    } catch (e) {
        console.warn('signOut:', e);
    }

    CHAVES_PRESERVADAS.forEach(k => {
        if (k in guardado) {
            try { localStorage.setItem(k, guardado[k]); } catch (e) { /* ok */ }
        }
    });

    window.location.href = './index.html';
    return true;
}

// ================================================================
// MENU NO CABECALHO
// ================================================================
function fecharMenu() {
    const m = document.getElementById('sessao-dropdown');
    const b = document.getElementById('sessao-botao');
    if (m) m.classList.add('hidden');
    if (b) b.setAttribute('aria-expanded', 'false');
}

function alternarMenu() {
    const m = document.getElementById('sessao-dropdown');
    const b = document.getElementById('sessao-botao');
    if (!m) return;
    const abrindo = m.classList.contains('hidden');
    m.classList.toggle('hidden');
    if (b) b.setAttribute('aria-expanded', abrindo ? 'true' : 'false');
    if (abrindo) atualizarPendenciasNoMenu();
}

async function atualizarPendenciasNoMenu() {
    const el = document.getElementById('sessao-pendencias');
    if (!el) return;
    const t = textoPendencias(await pendencias());
    if (!t) { el.classList.add('hidden'); return; }
    el.textContent = `Ainda há ${t}.`;
    el.classList.remove('hidden');
}

/**
 * Injeta o menu no <header class="header-app">. Todas as telas
 * autenticadas seguem esse padrao; a ancora eh o primeiro div
 * dentro do header, e o ml-auto empurra para a direita tanto no
 * layout com justify-between quanto no com gap.
 */
async function montarMenu() {
    if (document.getElementById('sessao-botao')) return;   // ja existe

    // O dashboard do index.html ja tem o proprio botao "Sair" no
    // cabecalho. Injetar aqui deixaria duas saidas lado a lado.
    if (document.querySelector('[onclick*="sessao.sair"]')) return;

    const user = await usuarioAtual();
    if (!user) return;                                      // sem sessao, sem menu

    const header = document.querySelector('header.header-app');
    if (!header) return;
    const linha = header.querySelector('div') || header;

    const wrap = document.createElement('div');
    wrap.className = 'relative ml-auto';
    wrap.setAttribute('data-sessao-menu', '1');
    wrap.innerHTML = `
        <button id="sessao-botao" type="button" aria-haspopup="true" aria-expanded="false"
                title="Conta de ${esc(user.email || '')}"
                class="w-9 h-9 rounded-full bg-white/15 hover:bg-white/25 text-white
                       text-xs font-bold flex items-center justify-center transition">
            ${esc(iniciais(user))}
        </button>
        <div id="sessao-dropdown"
             class="hidden absolute right-0 mt-2 w-60 bg-white dark:bg-slate-800 rounded-xl
                    shadow-lg border border-slate-200 dark:border-slate-700 z-50 overflow-hidden">
            <div class="px-4 py-3 border-b border-slate-100 dark:border-slate-700">
                <p class="text-sm font-medium text-slate-900 dark:text-white truncate">
                    ${esc(nomeExibicao(user))}
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400 truncate">
                    ${esc(user.email || '')}
                </p>
            </div>
            <p id="sessao-pendencias"
               class="hidden px-4 py-2 text-xs text-amber-700 dark:text-amber-400
                      bg-amber-50 dark:bg-amber-900/20"></p>
            <button type="button" onclick="window.sessao.sair()"
                    class="w-full text-left px-4 py-3 text-sm text-red-600 dark:text-red-400
                           hover:bg-slate-50 dark:hover:bg-slate-700 transition">
                Sair da conta
            </button>
        </div>`;
    linha.appendChild(wrap);

    document.getElementById('sessao-botao')
            .addEventListener('click', (e) => { e.stopPropagation(); alternarMenu(); });
    document.addEventListener('click', fecharMenu);
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape') fecharMenu(); });
}

function esc(s) {
    if (s == null) return '';
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

// ================================================================
// BOOT
// ================================================================
// O index.html tem o proprio botao Sair no dashboard e controla
// quando mostrar; as demais telas recebem o menu automaticamente.
if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', montarMenu);
    } else {
        montarMenu();
    }
}

window.sessao = {
    usuarioAtual,
    nomeExibicao,
    iniciais,
    pendencias,
    textoPendencias,
    sair,
    montarMenu,
    CHAVES_PRESERVADAS
};
