// =====================================================================
// REVISAO-MOTO :: i18n - Internacionalizacao PT-EN
// =====================================================================
// Uso:
//   t('dashboard.nova_inspecao')           -> "Nova Inspeção"
//   t('notif.revisao_proxima_desc', {placa:'ABC-1234', km:5000})
//   window.i18n.trocarIdioma('en')         -> muda para ingles
//
// Em HTML: <span data-i18n="dashboard.motos">Motos</span>
// Ao chamar window.i18n.aplicarNoDOM(), todos os data-i18n sao traduzidos.
// =====================================================================

const CHAVE_IDIOMA = 'rm_idioma';
const IDIOMAS_DISPONIVEIS = ['pt', 'en'];
let traducoes = {};
let idiomaAtual = 'pt';

// ================================================================
// CARREGAMENTO
// ================================================================
async function carregarIdioma(idioma) {
    if (!IDIOMAS_DISPONIVEIS.includes(idioma)) idioma = 'pt';
    try {
        const resp = await fetch(`./assets/i18n/${idioma}.json`);
        traducoes = await resp.json();
        idiomaAtual = idioma;
        document.documentElement.lang = idioma === 'pt' ? 'pt-BR' : 'en';
        localStorage.setItem(CHAVE_IDIOMA, idioma);
        aplicarNoDOM();
        window.dispatchEvent(new CustomEvent('i18n:trocado', { detail: { idioma } }));
    } catch (e) {
        console.warn('Falha ao carregar idioma:', idioma, e);
    }
}

// ================================================================
// TRADUCAO
// ================================================================
/**
 * t('dashboard.motos') -> string traduzida
 * t('notif.desc', {placa:'X'}) -> substitui {placa} por 'X'
 */
function t(chave, params) {
    // Navega pelo objeto (ex: 'dashboard.motos' -> traducoes.dashboard.motos)
    const partes = chave.split('.');
    let valor = traducoes;
    for (const p of partes) {
        if (valor && typeof valor === 'object' && p in valor) {
            valor = valor[p];
        } else {
            return chave;  // fallback: retorna a propria chave
        }
    }
    if (typeof valor !== 'string') return chave;

    // Substitui placeholders {nome}
    if (params && typeof params === 'object') {
        valor = valor.replace(/\{(\w+)\}/g, (_, k) => params[k] != null ? params[k] : `{${k}}`);
    }
    return valor;
}

// ================================================================
// APLICAR NO DOM
// ================================================================
function aplicarNoDOM() {
    document.querySelectorAll('[data-i18n]').forEach(el => {
        const chave = el.getAttribute('data-i18n');
        el.textContent = t(chave);
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
        el.placeholder = t(el.getAttribute('data-i18n-placeholder'));
    });
    document.querySelectorAll('[data-i18n-title]').forEach(el => {
        el.title = t(el.getAttribute('data-i18n-title'));
    });
}

async function trocarIdioma(novo) {
    await carregarIdioma(novo);
}

function idiomaSalvo() {
    return localStorage.getItem(CHAVE_IDIOMA) ||
           (navigator.language && navigator.language.startsWith('en') ? 'en' : 'pt');
}

// ================================================================
// SELETOR VISUAL (opcional)
// ================================================================
function criarSeletor(alvo) {
    const container = typeof alvo === 'string' ? document.querySelector(alvo) : alvo;
    if (!container) return;
    const sel = document.createElement('select');
    sel.className = 'text-xs bg-transparent border border-slate-300 rounded px-1 py-0.5';
    sel.innerHTML = `
        <option value="pt">🇧🇷 PT</option>
        <option value="en">🇺🇸 EN</option>
    `;
    sel.value = idiomaAtual;
    sel.onchange = () => trocarIdioma(sel.value);
    container.appendChild(sel);
}

// ================================================================
// BOOT
// ================================================================
async function iniciar() {
    await carregarIdioma(idiomaSalvo());
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', iniciar);
} else {
    iniciar();
}

window.i18n = { t, trocarIdioma, aplicarNoDOM, criarSeletor, idiomaAtual: () => idiomaAtual };
window.t = t;  // atalho global
