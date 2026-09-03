// =====================================================================
// REVISAO-MOTO :: Dark Mode
// =====================================================================
// Estrategia:
// - Detecta prefers-color-scheme na primeira visita
// - Usuario pode alternar manualmente (toggle)
// - Preferencia salva em localStorage
// - Aplica classe 'dark' no <html> (compativel com Tailwind darkMode:'class')
// =====================================================================

const CHAVE_TEMA = 'rm_tema';

function temaSalvo() {
    return localStorage.getItem(CHAVE_TEMA);  // 'dark' | 'light' | null
}

function temaPreferido() {
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
        ? 'dark' : 'light';
}

function temaAtual() {
    return temaSalvo() || temaPreferido();
}

function aplicarTema(tema) {
    const html = document.documentElement;
    if (tema === 'dark') {
        html.classList.add('dark');
        document.querySelector('meta[name="theme-color"]')?.setAttribute('content', '#1e293b');
    } else {
        html.classList.remove('dark');
        document.querySelector('meta[name="theme-color"]')?.setAttribute('content', '#dc2626');
    }
}

function alternarTema() {
    const novo = temaAtual() === 'dark' ? 'light' : 'dark';
    localStorage.setItem(CHAVE_TEMA, novo);
    aplicarTema(novo);
    atualizarBotao();
    return novo;
}

function definirTema(tema) {
    localStorage.setItem(CHAVE_TEMA, tema);
    aplicarTema(tema);
    atualizarBotao();
}

// Botao flutuante de troca de tema
function criarBotao() {
    if (document.getElementById('btn-dark-toggle')) return;
    const btn = document.createElement('button');
    btn.id = 'btn-dark-toggle';
    btn.title = 'Alternar tema claro/escuro';
    btn.style.cssText = `
        position: fixed;
        bottom: 12px;
        right: 12px;
        z-index: 55;
        width: 42px; height: 42px;
        border-radius: 50%;
        background: rgba(255,255,255,0.95);
        border: 1px solid rgba(0,0,0,0.1);
        box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        cursor: pointer;
        font-size: 18px;
        display: flex; align-items: center; justify-content: center;
    `;
    btn.onclick = alternarTema;
    document.body.appendChild(btn);
    atualizarBotao();
}

function atualizarBotao() {
    const btn = document.getElementById('btn-dark-toggle');
    if (!btn) return;
    const tema = temaAtual();
    btn.textContent = tema === 'dark' ? '☀️' : '🌙';
    btn.style.background = tema === 'dark' ? '#1e293b' : 'rgba(255,255,255,0.95)';
    btn.style.color = tema === 'dark' ? '#fbbf24' : '#334155';
}

// Boot
function iniciar() {
    aplicarTema(temaAtual());

    // Ouve mudanca do SO se usuario nao definiu preferencia manual
    if (window.matchMedia) {
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
            if (!temaSalvo()) aplicarTema(temaPreferido());
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', criarBotao);
    } else {
        criarBotao();
    }
}

iniciar();

window.darkMode = { alternarTema, definirTema, temaAtual };
