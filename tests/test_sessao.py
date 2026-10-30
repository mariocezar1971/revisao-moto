#!/usr/bin/env python3
# =====================================================================
# REVISAO-MOTO :: Testes do menu de sessao (logout em toda tela)
# =====================================================================
# Nao eh uma fase: eh a correcao de uma falha que passou despercebida
# por dez fases. O logout existia desde a Fase 0, mas o botao "Sair"
# so estava no dashboard. Quem entrasse em qualquer outra tela ficava
# sem saida visivel - num celular em modo standalone, sem nem a barra
# de endereco para voltar.
#
# Nao requer banco: tudo aqui eh estatico.
#
# Uso: python3 tests/test_sessao.py
# =====================================================================

import os, re, subprocess, sys, tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

VERDE, VERM, AMAR, FIM = '\033[92m', '\033[91m', '\033[93m', '\033[0m'
total = falhou = 0

def cabecalho(t):
    print(f"\n{'=' * 70}\n  {t}\n{'=' * 70}")

def teste(nome, cond, det=''):
    global total, falhou
    total += 1
    if cond:
        print(f"  {VERDE}OK{FIM}   {nome}")
    else:
        falhou += 1
        print(f"  {VERM}FAIL {nome}{FIM}")
    if det:
        print(f"       {det}")

def node_check(c):
    r = subprocess.run(['node', '--check', str(c)], capture_output=True, text=True)
    return r.returncode == 0, r.stderr

def node_eval(js_path, trecho):
    """Carrega um modulo window.* e roda um trecho em cima dele.

    Sem require() e sem 'node -e': require() resolve package.json
    subindo a arvore, e um "type": "module" em qualquer pasta acima
    do projeto quebraria a carga de um CommonJS valido.
    """
    runner = ("const fs = require('fs');\n"
              "global.window = {};\n"
              "global.navigator = { onLine: true };\n"
              "global.document = undefined;\n"
              "eval(fs.readFileSync(process.argv[2], 'utf8'));\n" + trecho)
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as f:
        f.write(runner)
        tmp = f.name
    try:
        r = subprocess.run(['node', tmp, str(js_path)], capture_output=True, text=True)
        return r.stdout.strip(), r.stderr.strip()
    finally:
        os.unlink(tmp)


# Telas que exigem login e portanto precisam de saida
TELAS_AUTENTICADAS = ['admin.html', 'comparacao.html', 'especificacoes.html',
                      'historico.html', 'inspecao.html', 'lembretes.html',
                      'qrcode.html', 'recebimento.html']


def t_modulo():
    cabecalho("1. MODULO src/sessao.js")
    js = RAIZ / 'src' / 'sessao.js'
    teste("Arquivo existe", js.exists())
    if not js.exists():
        return
    ok, err = node_check(js)
    teste("Sintaxe valida", ok, err[:120])

    c = js.read_text()
    for fn in ['usuarioAtual', 'pendencias', 'sair', 'montarMenu',
               'textoPendencias', 'nomeExibicao', 'iniciais']:
        teste(f"Exporta {fn}", fn in c and 'window.sessao' in c)

    teste("Chama signOut do Supabase", 'auth.signOut()' in c)
    teste("Redireciona para o index apos sair", "index.html" in c)
    teste("Para o auto-sync antes de sair", 'pararAutoSync' in c)


def t_preserva_preferencias():
    cabecalho("2. O QUE SOBREVIVE AO LOGOUT")
    js = RAIZ / 'src' / 'sessao.js'
    if not js.exists():
        return
    c = js.read_text()

    # Tema e idioma sao do aparelho, nao da pessoa: quem sai e volta
    # nao deveria reencontrar o app em claro quando escolheu escuro.
    for chave, origem in [('rm_tema', 'darkmode.js'), ('rm_idioma', 'i18n.js'),
                          ('rm_onboarding_visto', 'index.html')]:
        teste(f"Preserva {chave} (de {origem})", f"'{chave}'" in c)

    # A chave tem que ser a mesma que o outro modulo grava, senao
    # preserva uma chave que ninguem usa.
    dm = (RAIZ / 'src' / 'darkmode.js').read_text()
    i18 = (RAIZ / 'src' / 'i18n.js').read_text()
    teste("Chave de tema casa com darkmode.js", "'rm_tema'" in dm)
    teste("Chave de idioma casa com i18n.js", "'rm_idioma'" in i18)

    teste("NAO usa localStorage.clear()", 'localStorage.clear' not in c,
          "clear() levaria junto tema, idioma e onboarding")
    teste("NAO apaga a fila offline",
          'cacheLimpar' not in c and 'removerPendente' not in c,
          "a fila eh trabalho feito na garagem, nao lixo de sessao")


def t_pendencias():
    cabecalho("3. AVISO DE TRABALHO PENDENTE")
    js = RAIZ / 'src' / 'sessao.js'
    if not js.exists():
        return
    c = js.read_text()

    teste("Conta a fila do IndexedDB", 'contarPendentes' in c)
    teste("Conta as fotos pendentes", 'listarChavesFotoPendente' in c)
    teste("Olha inspecoes em andamento", 'em_andamento' in c)
    teste("Pede confirmacao antes de sair com pendencia", 'confirm(' in c)
    teste("Permite sair a forca (opcoes.forcar)", 'forcar' in c)
    teste("Trata o caso offline", 'navigator.onLine' in c)

    # A frase tem que mudar com o numero, senao sai "1 alterações"
    trecho = '''
    const t = window.sessao.textoPendencias;
    const casos = [
      [{fila:0, fotos:0, offline:false}, ""],
      [{fila:1, fotos:0, offline:false}, "1 alteração na fila"],
      [{fila:3, fotos:0, offline:false}, "3 alterações na fila"],
      [{fila:0, fotos:1, offline:false}, "1 foto para enviar"],
      [{fila:2, fotos:2, offline:false}, "2 alterações na fila e 2 fotos para enviar"],
      [{fila:1, fotos:0, offline:true},  "1 alteração na fila, e você está offline"]
    ];
    let ok = 0;
    const erros = [];
    for (const [p, e] of casos) {
      const got = t(p);
      if (got === e) ok++; else erros.push(JSON.stringify(got) + " != " + JSON.stringify(e));
    }
    console.log(ok + "/" + casos.length + (erros.length ? " | " + erros.join("; ") : ""));
    '''
    out, err = node_eval(js, trecho)
    teste("Singular e plural corretos no aviso", out.startswith('6/6'),
          out if out else f"node falhou: {err[:160]}")


def t_cobertura_das_telas():
    cabecalho("4. COBERTURA: TODA TELA AUTENTICADA TEM SAIDA")
    for tela in TELAS_AUTENTICADAS:
        f = RAIZ / tela
        if not f.exists():
            teste(f"{tela} existe", False)
            continue
        c = f.read_text()
        teste(f"{tela} carrega sessao.js", 'src/sessao.js' in c)
        # So faz sentido exigir saida de quem exige entrada
        if 'exigirLogin' in c:
            teste(f"{tela} exige login (e por isso precisa de saida)", True)

    idx = (RAIZ / 'index.html').read_text()
    teste("index.html tem o botao Sair do dashboard", '>Sair' in idx or 'Sair' in idx)
    teste("index.html usa o fluxo com checagem", 'sessao.sair()' in idx)
    teste("index.html nao chama mais o logout cru", 'onclick="logout()"' not in idx)

    # onboarding eh a primeira abertura: nao ha sessao para encerrar
    onb = RAIZ / 'onboarding.html'
    if onb.exists():
        teste("onboarding.html fica de fora (nao exige login)",
              'exigirLogin' not in onb.read_text())


def t_menu_unico():
    cabecalho("5. UM MENU SO")
    js = (RAIZ / 'src' / 'sessao.js').read_text()
    teste("Nao injeta se ja existe o botao", "getElementById('sessao-botao')" in js)
    teste("Nao injeta onde ja ha um 'sessao.sair'", 'onclick*="sessao.sair"' in js)
    teste("Ancora no header.header-app", 'header.header-app' in js)
    teste("Alinha a direita com ml-auto", 'ml-auto' in js)

    # Todas as telas usam a mesma classe de cabecalho que o modulo procura
    for tela in TELAS_AUTENTICADAS:
        f = RAIZ / tela
        if f.exists():
            teste(f"{tela} tem header.header-app", 'class="header-app' in f.read_text())


def t_acessibilidade_e_tema():
    cabecalho("6. ACESSIBILIDADE E DARK MODE")
    c = (RAIZ / 'src' / 'sessao.js').read_text()
    teste("Botao tem aria-haspopup", 'aria-haspopup' in c)
    teste("Botao informa aberto/fechado (aria-expanded)", 'aria-expanded' in c)
    teste("Fecha com Escape", "'Escape'" in c)
    teste("Fecha ao clicar fora", "document.addEventListener('click'" in c)
    teste("Tem variante dark:", 'dark:bg-slate-800' in c)
    teste("Escapa o que vem do usuario", 'function esc(' in c and 'esc(user.email' in c)


def t_service_worker():
    cabecalho("7. SERVICE WORKER")
    sw = (RAIZ / 'service-worker.js').read_text()
    teste("APP_SHELL contem sessao.js", './src/sessao.js' in sw)
    m = re.search(r"CACHE_VERSION\s*=\s*'v(\d+)\.(\d+)", sw)
    ver = (int(m.group(1)), int(m.group(2))) if m else (0, 0)
    teste("Versao do cache subiu para v1.1+", ver >= (1, 1),
          m.group(0).split("'")[-1] if m else '?')


def main():
    print(f"\n{'=' * 70}")
    print("  REVISAO-MOTO :: Testes do menu de sessao (logout)")
    print(f"{'=' * 70}")

    t_modulo()
    t_preserva_preferencias()
    t_pendencias()
    t_cobertura_das_telas()
    t_menu_unico()
    t_acessibilidade_e_tema()
    t_service_worker()

    cabecalho("RESUMO :: SESSAO")
    print(f"  Total : {total}")
    print(f"  Passou: {total - falhou}")
    if falhou:
        print(f"  {VERM}Falhou: {falhou}{FIM}")
    pct = 100.0 * (total - falhou) / total if total else 0
    cor = VERDE if falhou == 0 else (AMAR if pct >= 90 else VERM)
    print(f"\n  {cor}Sucesso: {pct:.1f}%{FIM}\n")
    return 1 if falhou else 0


if __name__ == '__main__':
    sys.exit(main())
