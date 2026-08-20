<map version="freeplane 1.11.0">
<node TEXT="Fase 5&#xa;Historico e Relatorios" FOLDED="false" ID="ID_root" STYLE="oval">
<font SIZE="18" BOLD="true"/>
<edge COLOR="#cc0000" WIDTH="thin"/>
<richcontent TYPE="NOTE"><html><body>
<p>Historico por moto, filtros de inspecoes, export CSV, relatorios gerenciais.</p>
<p>4 views + 2 funcoes + 1 pagina + 1 modulo JS.</p>
<p>Resultado: 80/80 testes locais.</p>
</body></html></richcontent>

<!-- A. ATUALIZAR ARQUIVOS -->
<node TEXT="A. Atualizar arquivos locais" POSITION="right" ID="ID_A" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="folder"/>
<edge COLOR="#0066cc"/>
<node TEXT="cp .env /tmp/.env.backup" ID="ID_A1"><font ITALIC="true"/></node>
<node TEXT="cd .. &amp;&amp; unzip -o ~/Downloads/revisao-moto.zip &amp;&amp; cd revisao-moto" ID="ID_A2"><font ITALIC="true"/></node>
<node TEXT="cp /tmp/.env.backup .env" ID="ID_A3"><font ITALIC="true"/></node>
</node>

<!-- B. MIGRATION -->
<node TEXT="B. Migration no Supabase" POSITION="right" ID="ID_B" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="bookmark"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body>
<p>SQL Editor - New query - cole - Run.</p>
<p>Cria: funcoes status_revisao_moto + estatisticas_gerais,</p>
<p>4 views (motos_com_status, timeline, mecanico_mes, itens_reprovados),</p>
<p>3 indices adicionais.</p>
<p>Idempotente.</p>
</body></html></richcontent>
<node TEXT="1. sql/006_fase5_historico.sql -&gt; Run"/>
<node TEXT="2. sql/validacao_fase5.sql -&gt; Run"><icon BUILTIN="button_ok"/>
<richcontent TYPE="NOTE"><html><body><p>Esperado: TODAS AS VALIDACOES PASSARAM (5 asserts)</p></body></html></richcontent>
</node>
</node>

<!-- C. VALIDAR LOCAL -->
<node TEXT="C. Validar localmente" POSITION="right" ID="ID_C" COLOR="#cc0000">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#cc0000" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p>Opcao rapida: so a Fase 5 (~15 segundos).</p>
<p>Opcao completa: todas as fases 0-5 (~40 segundos, 427 testes).</p>
</body></html></richcontent>
<node TEXT="./orquestrador_fase5.sh" ID="ID_C1"><font BOLD="true" ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body><p>Sobe Postgres efemero, aplica todas migrations, roda so testes Fase 5.</p></body></html></richcontent>
</node>
<node TEXT="./orquestrador_fase5.sh --all (opcional)" ID="ID_C2"><font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body><p>Roda toda a suite. Esperado: 427/427.</p></body></html></richcontent>
</node>
</node>

<!-- D. DEPLOY -->
<node TEXT="D. Commit e push" POSITION="left" ID="ID_D" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="launch"/>
<edge COLOR="#0066cc"/>
<node TEXT="git add ." ID="ID_D1"><font ITALIC="true"/></node>
<node TEXT="git commit -m &quot;Fase 5: historico e relatorios (80 testes)&quot;" ID="ID_D2"><font ITALIC="true"/></node>
<node TEXT="git push" ID="ID_D3"><font ITALIC="true"/></node>
</node>

<!-- E. VALIDACAO VISUAL -->
<node TEXT="E. Validacao visual no celular" POSITION="left" ID="ID_E" COLOR="#cc0000">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="phone_mobile"/>
<edge COLOR="#cc0000"/>
<node TEXT="Abrir historico no celular">
<node TEXT="https://mariocezar1971.github.io/revisao-moto/historico.html" ID="ID_E1"><font ITALIC="true"/></node>
</node>
<node TEXT="Testar Aba Motos">
<node TEXT="Ver status de revisao com cores"/>
<node TEXT="Filtrar por placa e status"/>
<node TEXT="Clicar em moto -&gt; timeline + grafico km"/>
<node TEXT="Abrir PDF do historico"/>
</node>
<node TEXT="Testar Aba Inspecoes">
<node TEXT="Filtrar por mecanico"/>
<node TEXT="Filtrar por status (em andamento / finalizada)"/>
<node TEXT="Filtrar por modelo"/>
<node TEXT="Filtrar por periodo (de/ate)"/>
<node TEXT="Export CSV cabecalho -&gt; abre no Excel"/>
<node TEXT="Export CSV itens -&gt; abre no Excel"/>
</node>
<node TEXT="Testar Aba Relatorios">
<node TEXT="Ver 4 KPIs no topo"/>
<node TEXT="Tabela inspecoes por mecanico/mes"/>
<node TEXT="Tabela itens mais reprovados"/>
</node>
</node>

<!-- FUNCIONALIDADES -->
<node TEXT="Funcionalidades implementadas" POSITION="right" ID="ID_features" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>

<node TEXT="Lista de motos">
<node TEXT="Status: em_dia / proxima / atrasada / sem_historico"/>
<node TEXT="Ultima inspecao e km"/>
<node TEXT="Proxima km prevista"/>
<node TEXT="Filtros placa + status"/>
</node>

<node TEXT="Detalhe da moto (modal)">
<node TEXT="KPIs: total, km atual, proxima em X km"/>
<node TEXT="Grafico SVG km vs tempo"/>
<node TEXT="Timeline vertical de inspecoes"/>
<node TEXT="Botao abrir PDF de cada uma"/>
</node>

<node TEXT="Filtros de inspecoes">
<node TEXT="Placa (ilike)"/>
<node TEXT="Mecanico (dropdown dinamico)"/>
<node TEXT="Status (em andamento/finalizada/cancelada)"/>
<node TEXT="Modelo (dropdown dinamico)"/>
<node TEXT="Periodo (data de + ate)"/>
</node>

<node TEXT="Export CSV">
<node TEXT="Cabecalho: 1 linha por inspecao (17 colunas)"/>
<node TEXT="Itens: 1 linha por item avaliado"/>
<node TEXT="BOM UTF-8 (Excel abre acentos corretos)"/>
<node TEXT="Aplica os mesmos filtros do dashboard"/>
</node>

<node TEXT="Relatorios gerenciais">
<node TEXT="4 KPIs (motos, inspecoes, atrasadas, tempo medio)"/>
<node TEXT="Inspecoes por mecanico e mes (com media)"/>
<node TEXT="Top 15 itens mais reprovados"/>
</node>
</node>

<!-- ARTEFATOS -->
<node TEXT="Artefatos entregues" POSITION="right" ID="ID_artefatos" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>
<node TEXT="sql/006_fase5_historico.sql (migration)"/>
<node TEXT="sql/validacao_fase5.sql (asserts inline)"/>
<node TEXT="src/relatorios.js (CSV, agregados, filtros)"/>
<node TEXT="historico.html (3 tabs + modal detalhe)"/>
<node TEXT="tests/test_fase5.py (80 testes em 9 grupos)"/>
<node TEXT="orquestrador_fase5.sh (validacao 1-comando)"/>
<node TEXT="Resultado: 80/80 na Fase 5 (100%)"/>
<node TEXT="Total geral: 427/427 (Fase 0+1+2+3+4+5)"/>
</node>

</node>
</map>
