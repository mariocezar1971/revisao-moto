#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Suite de testes da Fase 4
========================================================================
Valida assinaturas e geracao de PDF:
  - Migration (view, funcao, indice)
  - Persistencia de assinaturas e pdf_url
  - Funcao assinaturas_completas
  - View vw_inspecoes_com_pdf
  - Modulos JS: assinatura.js, pdf.js
  - Integracao no inspecao.html
========================================================================
"""

import os
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).parent.parent.resolve()

class Cor:
    VERDE = '\033[92m'; VERMELHO = '\033[91m'; AMARELO = '\033[93m'
    AZUL = '\033[94m'; NEGRITO = '\033[1m'; RESET = '\033[0m'

testes_total = 0; testes_passou = 0; testes_falhou = 0; falhas = []

def cabecalho(titulo):
    print(f"\n{Cor.AZUL}{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")
    print(f"{Cor.AZUL}{Cor.NEGRITO}  {titulo}{Cor.RESET}")
    print(f"{Cor.AZUL}{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")

def teste(descricao, condicao, detalhe=''):
    global testes_total, testes_passou, testes_falhou
    testes_total += 1
    if condicao:
        testes_passou += 1
        print(f"  {Cor.VERDE}OK{Cor.RESET}   {descricao}")
        if detalhe: print(f"       {Cor.AMARELO}{detalhe}{Cor.RESET}")
    else:
        testes_falhou += 1
        falhas.append(descricao)
        print(f"  {Cor.VERMELHO}FAIL {descricao}{Cor.RESET}")
        if detalhe: print(f"       {Cor.VERMELHO}{detalhe}{Cor.RESET}")

def psql(sql, db=None):
    cmd = ['psql', '-h', os.environ.get('PGHOST', '/tmp'),
           '-p', os.environ.get('PGPORT', '5433'),
           '-U', os.environ.get('PGUSER', 'postgres'),
           '-d', db or os.environ.get('PGDATABASE', 'revisao_moto_test'),
           '-t', '-A', '-c', sql]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"psql falhou: {res.stderr}")
    return res.stdout.strip()

def psql_arquivo(arquivo):
    cmd = ['psql', '-h', os.environ.get('PGHOST', '/tmp'),
           '-p', os.environ.get('PGPORT', '5433'),
           '-U', os.environ.get('PGUSER', 'postgres'),
           '-d', os.environ.get('PGDATABASE', 'revisao_moto_test'),
           '-f', str(arquivo), '-v', 'ON_ERROR_STOP=1']
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout, res.stderr

def limpar():
    psql("""
        DELETE FROM inspecoes WHERE moto_id IN (SELECT id FROM motos WHERE placa LIKE 'TST-%');
        DELETE FROM motos WHERE placa LIKE 'TST-%';
    """)

# ============================================================
# 1. MIGRATION
# ============================================================
def testar_migration():
    cabecalho("1. MIGRATION (005_fase4_assinaturas_pdf.sql)")
    arquivo = RAIZ / 'sql' / '005_fase4_assinaturas_pdf.sql'
    teste("Arquivo migration existe", arquivo.exists())
    if not arquivo.exists(): return False

    codigo, _, stderr = psql_arquivo(arquivo)
    teste("Migration executa", codigo == 0, stderr if codigo != 0 else 'OK')
    if codigo != 0: return False

    codigo2, _, stderr2 = psql_arquivo(arquivo)
    teste("Migration eh idempotente (2x)", codigo2 == 0, stderr2 if codigo2 != 0 else 'OK')
    return True

# ============================================================
# 2. ESTRUTURA
# ============================================================
def testar_estrutura():
    cabecalho("2. ESTRUTURA POS-MIGRATION")

    # Campos existentes em inspecoes
    campos = ['assinatura_mecanico', 'assinatura_cliente', 'nome_cliente_assinou',
              'pdf_url', 'hash_integridade']
    for c in campos:
        existe = psql(f"""
            SELECT EXISTS(SELECT 1 FROM information_schema.columns
            WHERE table_schema='public' AND table_name='inspecoes' AND column_name='{c}');
        """) == 't'
        teste(f"Campo inspecoes.{c} existe", existe)

    # View
    existe_view = psql("""
        SELECT EXISTS(SELECT 1 FROM information_schema.views
        WHERE table_schema='public' AND table_name='vw_inspecoes_com_pdf');
    """) == 't'
    teste("View vw_inspecoes_com_pdf criada", existe_view)

    # Funcao
    existe_func = psql("SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='assinaturas_completas');") == 't'
    teste("Funcao assinaturas_completas criada", existe_func)

    # Indice
    existe_idx = psql("SELECT EXISTS(SELECT 1 FROM pg_indexes WHERE indexname='idx_inspecoes_pdf_url');") == 't'
    teste("Indice idx_inspecoes_pdf_url criado", existe_idx)

# ============================================================
# 3. FUNCAO assinaturas_completas
# ============================================================
def testar_assinaturas_completas():
    cabecalho("3. FUNCAO assinaturas_completas")
    limpar()

    # Cria moto e inspecao de teste
    psql("""
        INSERT INTO motos (placa, modelo_id, km_atual, proprietario)
        SELECT 'TST-4001', m.id, 5000, 'Teste PDF' FROM modelos m WHERE m.nome='Shotgun 650';
    """)
    psql("""
        INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, mecanico_nome)
        SELECT m.id, r.id, 5000, 'em_andamento', 'Mario Teste'
        FROM motos m JOIN revisoes r ON r.modelo_id=m.modelo_id AND r.km=5000
        WHERE m.placa='TST-4001';
    """)
    insp_id = psql("""
        SELECT id FROM inspecoes
        WHERE moto_id=(SELECT id FROM motos WHERE placa='TST-4001')
          AND km_registrado=5000
        LIMIT 1;
    """).strip()

    # Sem assinaturas
    r = psql(f"SELECT assinaturas_completas('{insp_id}');")
    teste("Sem assinaturas -> FALSE", r == 'f')

    # Apenas assinatura mecanico (uma sem cliente/nome)
    base64_falso = 'data:image/png;base64,' + 'A' * 200
    psql(f"UPDATE inspecoes SET assinatura_mecanico='{base64_falso}' WHERE id='{insp_id}';")
    r = psql(f"SELECT assinaturas_completas('{insp_id}');")
    teste("Apenas mecanico -> FALSE", r == 'f')

    # Falta nome do cliente
    psql(f"UPDATE inspecoes SET assinatura_cliente='{base64_falso}' WHERE id='{insp_id}';")
    r = psql(f"SELECT assinaturas_completas('{insp_id}');")
    teste("Duas assinaturas mas sem nome cliente -> FALSE", r == 'f')

    # Completo
    psql(f"UPDATE inspecoes SET nome_cliente_assinou='Cliente Teste' WHERE id='{insp_id}';")
    r = psql(f"SELECT assinaturas_completas('{insp_id}');")
    teste("Tudo preenchido -> TRUE", r == 't')

    # Assinatura curta (< 100 chars) - considera invalida
    psql(f"UPDATE inspecoes SET assinatura_mecanico='data:x' WHERE id='{insp_id}';")
    r = psql(f"SELECT assinaturas_completas('{insp_id}');")
    teste("Assinatura muito curta -> FALSE", r == 'f')

# ============================================================
# 4. VIEW vw_inspecoes_com_pdf
# ============================================================
def testar_view():
    cabecalho("4. VIEW vw_inspecoes_com_pdf")

    # Restaurar assinaturas completas
    insp_id = psql("SELECT id FROM inspecoes WHERE moto_id=(SELECT id FROM motos WHERE placa='TST-4001') LIMIT 1;")
    base64_ok = 'data:image/png;base64,' + 'A' * 200
    psql(f"""
        UPDATE inspecoes SET
            assinatura_mecanico='{base64_ok}',
            assinatura_cliente='{base64_ok}',
            nome_cliente_assinou='Cliente Teste',
            pdf_url='{insp_id}/relatorio.pdf',
            hash_integridade='abc123def456',
            status='finalizada',
            data_fim=NOW()
        WHERE id='{insp_id}';
    """)

    # View retorna a linha
    n = int(psql(f"SELECT COUNT(*) FROM vw_inspecoes_com_pdf WHERE id='{insp_id}';"))
    teste("View retorna inspecao finalizada", n == 1)

    # Flags booleanas
    tem_mec = psql(f"SELECT tem_assinatura_mecanico FROM vw_inspecoes_com_pdf WHERE id='{insp_id}';")
    tem_cli = psql(f"SELECT tem_assinatura_cliente FROM vw_inspecoes_com_pdf WHERE id='{insp_id}';")
    tem_pdf = psql(f"SELECT tem_pdf FROM vw_inspecoes_com_pdf WHERE id='{insp_id}';")
    teste("tem_assinatura_mecanico = TRUE", tem_mec == 't')
    teste("tem_assinatura_cliente = TRUE", tem_cli == 't')
    teste("tem_pdf = TRUE", tem_pdf == 't')

    # Nao inclui em_andamento
    psql("""
        INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, mecanico_nome)
        SELECT m.id, r.id, 10000, 'em_andamento', 'Teste'
        FROM motos m JOIN revisoes r ON r.modelo_id=m.modelo_id AND r.km=10000
        WHERE m.placa='TST-4001';
    """)
    insp2 = psql("""
        SELECT id FROM inspecoes
        WHERE moto_id=(SELECT id FROM motos WHERE placa='TST-4001')
          AND km_registrado=10000
        LIMIT 1;
    """).strip()
    em_view = psql(f"SELECT EXISTS(SELECT 1 FROM vw_inspecoes_com_pdf WHERE id='{insp2}');") == 't'
    teste("View NAO inclui em_andamento", em_view == False)

# ============================================================
# 5. PERSISTENCIA DE ASSINATURAS
# ============================================================
def testar_persistencia():
    cabecalho("5. PERSISTENCIA DE ASSINATURAS E PDF_URL")

    insp_id = psql("SELECT id FROM inspecoes WHERE moto_id=(SELECT id FROM motos WHERE placa='TST-4001') AND status='finalizada' LIMIT 1;")

    # Assinaturas persistidas
    ass = psql(f"SELECT length(assinatura_mecanico) FROM inspecoes WHERE id='{insp_id}';")
    teste("Assinatura mecanico salva (base64 > 100 chars)", int(ass) > 100, f"length: {ass}")

    ass_cli = psql(f"SELECT length(assinatura_cliente) FROM inspecoes WHERE id='{insp_id}';")
    teste("Assinatura cliente salva (base64 > 100 chars)", int(ass_cli) > 100, f"length: {ass_cli}")

    # Nome cliente
    nome = psql(f"SELECT nome_cliente_assinou FROM inspecoes WHERE id='{insp_id}';")
    teste("Nome cliente persistido", nome == 'Cliente Teste')

    # pdf_url
    url = psql(f"SELECT pdf_url FROM inspecoes WHERE id='{insp_id}';")
    teste("pdf_url persistido", url.endswith('.pdf'), f"url: {url}")

    # hash
    h = psql(f"SELECT hash_integridade FROM inspecoes WHERE id='{insp_id}';")
    teste("hash_integridade persistido", len(h) > 0)

# ============================================================
# 6. src/assinatura.js
# ============================================================
def testar_assinatura_js():
    cabecalho("6. MODULO src/assinatura.js")
    arq = RAIZ / 'src' / 'assinatura.js'
    teste("Arquivo existe", arq.exists())
    if not arq.exists(): return

    js = arq.read_text()
    res = subprocess.run(['node', '--check', str(arq)], capture_output=True, text=True)
    teste("Sintaxe valida (node --check)", res.returncode == 0,
          res.stderr.strip() if res.returncode != 0 else 'OK')

    teste("Exporta criarAssinatura", 'window.criarAssinatura' in js)
    teste("Retorna metodo limpar", "limpar" in js and 'return' in js)
    teste("Retorna metodo exportarPng", 'exportarPng' in js)
    teste("Retorna metodo foiTocado", 'foiTocado' in js)
    teste("Usa pointer events", 'pointerdown' in js and 'pointermove' in js)
    teste("Impede scroll (touchAction none)", "touchAction = 'none'" in js)
    teste("Usa devicePixelRatio (HDPI)", 'devicePixelRatio' in js)
    teste("Preenche fundo branco", '#ffffff' in js.lower())
    teste("Exporta toDataURL PNG", "toDataURL('image/png')" in js)
    teste("Trata resize", 'resize' in js)
    teste("preventDefault durante desenho", 'preventDefault' in js)

# ============================================================
# 7. src/pdf.js
# ============================================================
def testar_pdf_js():
    cabecalho("7. MODULO src/pdf.js")
    arq = RAIZ / 'src' / 'pdf.js'
    teste("Arquivo existe", arq.exists())
    if not arq.exists(): return

    js = arq.read_text()
    res = subprocess.run(['node', '--check', str(arq)], capture_output=True, text=True)
    teste("Sintaxe valida", res.returncode == 0,
          res.stderr.strip() if res.returncode != 0 else 'OK')

    teste("Exporta gerarPdfInspecao", 'window.gerarPdfInspecao' in js)
    teste("Exporta uploadPdfSupabase", 'window.uploadPdfSupabase' in js)
    teste("Exporta compartilharPdf", 'window.compartilharPdf' in js)
    teste("Exporta baixarPdf", 'window.baixarPdf' in js)
    teste("Exporta calcularHashSha256", 'window.calcularHashSha256' in js)
    teste("Exporta obterUrlDownloadPdf", 'window.obterUrlDownloadPdf' in js)

    teste("Usa jsPDF", 'jspdf' in js.lower() and 'jsPDF' in js)
    teste("SHA-256 via Web Crypto", 'crypto.subtle.digest' in js and 'SHA-256' in js)
    teste("Upload para bucket inspecoes", "'inspecoes'" in js)
    teste("Path relatorio.pdf", 'relatorio.pdf' in js)
    teste("Atualiza pdf_url e hash", 'pdf_url' in js and 'hash_integridade' in js)
    teste("Usa Web Share API", 'navigator.share' in js)
    teste("Fallback clipboard", 'clipboard' in js)
    teste("URL assinada para fotos", 'urlAssinada' in js)
    teste("Adiciona cabecalho ao PDF", 'RELATORIO' in js or 'RELATÓRIO' in js)
    teste("Adiciona assinaturas ao PDF", 'assinatura_mecanico' in js and 'assinatura_cliente' in js)
    teste("Adiciona hash no rodape", 'SHA-256:' in js)
    teste("Trata fotos com addImage", 'addImage' in js and 'JPEG' in js)
    teste("Suporta multiplas paginas", 'addPage' in js)

# ============================================================
# 8. INTEGRACAO NO inspecao.html
# ============================================================
def testar_inspecao_html():
    cabecalho("8. INTEGRACAO NO inspecao.html")
    arq = RAIZ / 'inspecao.html'
    teste("inspecao.html existe", arq.exists())
    if not arq.exists(): return

    html = arq.read_text(encoding='utf-8')

    # CDN de jsPDF
    teste("Inclui jsPDF via CDN", 'jspdf' in html.lower())

    # Scripts locais
    teste("Importa assinatura.js", 'assinatura.js' in html)
    teste("Importa pdf.js", 'pdf.js' in html)

    # Elementos de UI
    teste("Canvas do mecanico", 'canvas-mecanico' in html)
    teste("Canvas do cliente", 'canvas-cliente' in html)
    teste("Input nome cliente", 'input-nome-cliente' in html)
    teste("Botao limpar assinatura mecanico", 'limparAssinaturaMecanico' in html)
    teste("Botao limpar assinatura cliente", 'limparAssinaturaCliente' in html)
    teste("View gerando PDF", 'view-gerando' in html)
    teste("View sucesso", 'view-sucesso' in html)
    teste("Botao compartilhar", 'compartilharAgora' in html)
    teste("Botao baixar", 'baixarAgora' in html)
    teste("Botao copiar link", 'copiarLinkPdf' in html)
    teste("Mostra hash no sucesso", 'hash-info' in html)
    teste("Mostra progresso PDF", 'progresso-pdf' in html)

    # Fluxo JS
    teste("Chama criarAssinatura", 'criarAssinatura' in html)
    teste("Chama gerarPdfInspecao", 'gerarPdfInspecao' in html)
    teste("Chama uploadPdfSupabase", 'uploadPdfSupabase' in html)
    teste("Chama obterUrlDownloadPdf", 'obterUrlDownloadPdf' in html)
    teste("Valida assinaturas (foiTocado)", 'foiTocado' in html)
    teste("Salva assinaturas em UPDATE", 'assinatura_mecanico:' in html and 'assinatura_cliente:' in html)

    # Sintaxe JS inline
    scripts = re.findall(r'<script>([\s\S]*?)</script>', html)
    if scripts:
        tmp = '/tmp/inspecao_inline_f4.js'
        with open(tmp, 'w') as f:
            f.write(scripts[-1])
        res = subprocess.run(['node', '--check', tmp], capture_output=True, text=True)
        teste("JS inline do inspecao.html eh valido",
              res.returncode == 0,
              res.stderr.strip() if res.returncode != 0 else 'OK')

# ============================================================
# CLEANUP
# ============================================================
def cleanup():
    limpar()

# ============================================================
# RESUMO
# ============================================================
def resumo():
    print(f"\n{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")
    print(f"{Cor.NEGRITO}  RESUMO FASE 4{Cor.RESET}")
    print(f"{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")
    print(f"  Total : {testes_total}")
    print(f"  {Cor.VERDE}Passou: {testes_passou}{Cor.RESET}")
    if testes_falhou:
        print(f"  {Cor.VERMELHO}Falhou: {testes_falhou}{Cor.RESET}\n  Falhas:")
        for f in falhas:
            print(f"    - {f}")
    pct = (testes_passou / testes_total * 100) if testes_total else 0
    cor = Cor.VERDE if pct == 100 else (Cor.AMARELO if pct >= 80 else Cor.VERMELHO)
    print(f"\n  {cor}{Cor.NEGRITO}Sucesso: {pct:.1f}%{Cor.RESET}")
    return 0 if testes_falhou == 0 else 1

def main():
    print(f"{Cor.NEGRITO}REVISAO-MOTO :: Testes da Fase 4{Cor.RESET}")
    if not testar_migration(): return 1
    testar_estrutura()
    testar_assinaturas_completas()
    testar_view()
    testar_persistencia()
    testar_assinatura_js()
    testar_pdf_js()
    testar_inspecao_html()
    cleanup()
    return resumo()

if __name__ == '__main__':
    sys.exit(main())
