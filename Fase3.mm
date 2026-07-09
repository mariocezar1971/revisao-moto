<map version="freeplane 1.11.0">
<node TEXT="Fase 3&#xa;Execucao do Checklist" FOLDED="false" ID="ID_root" CREATED="1750000000000" MODIFIED="1750000000000" STYLE="oval">
<font SIZE="18" BOLD="true"/>
<edge COLOR="#cc0000" WIDTH="thin"/>
<richcontent TYPE="NOTE"><html><body>
<p>Nucleo do app: executar checklist com autosave, foto, progresso e validacao.</p>
<p>7 passos em sequencia.</p>
<p>Resultado esperado: 264/264 testes totais + inspecao real no celular.</p>
</body></html></richcontent>

<!-- ============================================================ -->
<!-- PASSO A - ATUALIZAR ARQUIVOS                                   -->
<!-- ============================================================ -->
<node TEXT="A. Atualizar arquivos locais" POSITION="right" ID="ID_A" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="folder"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body>
<p>Extrai o zip novo por cima do projeto (sem tocar em .env/usuarios.json).</p>
</body></html></richcontent>
<node TEXT="cp revisao-moto/.env /tmp/.env.backup" ID="ID_A1"><font ITALIC="true"/></node>
<node TEXT="unzip -o ~/Downloads/revisao-moto.zip -d /mnt/c/Users/mceza/Dropbox/PROGRAMACAO/JAVASCRIPT/APLICATIVOS/" ID="ID_A2"><font ITALIC="true"/></node>
<node TEXT="cp /tmp/.env.backup revisao-moto/.env" ID="ID_A3"><font ITALIC="true"/></node>
</node>

<!-- ============================================================ -->
<!-- PASSO B - MIGRATION NO SUPABASE                                -->
<!-- ============================================================ -->
<node TEXT="B. Migration no Supabase" POSITION="right" ID="ID_B" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="bookmark"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body>
<p>SQL Editor - New query - cole - Run.</p>
<p>Cria: funcao sugerir_revisao, funcao pode_finalizar_inspecao,</p>
<p>view vw_inspecao_progresso, view vw_inspecoes_lista, trigger de km_moto, 2 indices.</p>
<p>Idempotente.</p>
</body></html></richcontent>
<node TEXT="1. sql/004_fase3_execucao.sql -&gt; Run"/>
<node TEXT="2. sql/validacao_fase3.sql -&gt; Run"><icon BUILTIN="button_ok"/>
<richcontent TYPE="NOTE"><html><body><p>Esperado: TODAS AS VALIDACOES PASSARAM (7 asserts)</p></body></html></richcontent>
</node>
</node>

<!-- ============================================================ -->
<!-- PASSO C - VALIDAR LOCALMENTE                                   -->
<!-- ============================================================ -->
<node TEXT="C. Validar localmente" POSITION="right" ID="ID_C" COLOR="#cc0000">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#cc0000" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p>Suite completa: Fase 0 (110) + Fase 1 (24) + Fase 2 (61) + Fase 3 (69) = 264 testes.</p>
<p>Sobe Postgres efemero, aplica todas as migrations em ordem, valida tudo.</p>
<p>Duracao: ~40 segundos.</p>
</body></html></richcontent>
<node TEXT="cd revisao-moto" ID="ID_C1"><font ITALIC="true"/></node>
<node TEXT="./tests/run_tests.sh" ID="ID_C2"><font BOLD="true" ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body><p>Esperado: TODOS OS TESTES PASSARAM (Fase 0 + 1 + 2 + 3) - 264/264</p></body></html></richcontent>
</node>
</node>

<!-- ============================================================ -->
<!-- PASSO D - COMMIT E PUSH                                        -->
<!-- ============================================================ -->
<node TEXT="D. Commit e push" POSITION="left" ID="ID_D" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="launch"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body>
<p>Deploy automatico via GitHub Pages (~1 min apos push).</p>
<p>credential.helper store ja salvou o PAT, nao pede senha.</p>
</body></html></richcontent>
<node TEXT="git add ." ID="ID_D1"><font ITALIC="true"/></node>
<node TEXT="git commit -m &quot;Fase 3: execucao do checklist (264 testes)&quot;" ID="ID_D2"><font ITALIC="true"/></node>
<node TEXT="git push" ID="ID_D3"><font ITALIC="true"/></node>
</node>

<!-- ============================================================ -->
<!-- PASSO E - VALIDACAO VISUAL                                     -->
<!-- ============================================================ -->
<node TEXT="E. Validacao visual no celular" POSITION="left" ID="ID_E" COLOR="#cc0000">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="phone_mobile"/>
<edge COLOR="#cc0000"/>
<richcontent TYPE="NOTE"><html><body>
<p>Fluxo real de inspecao end-to-end no celular.</p>
<p>Pre-requisito: bucket 'inspecoes' criado (Fase 1) e moto cadastrada (Fase 2).</p>
</body></html></richcontent>

<node TEXT="1. Cadastro previo">
<node TEXT="Certifique que ha pelo menos 1 moto cadastrada"/>
<node TEXT="admin.html -&gt; nova moto (ou seed_motos_demo.sql)"/>
</node>

<node TEXT="2. Abrir inspecao no celular">
<node TEXT="https://mariocezar1971.github.io/revisao-moto/inspecao.html" ID="ID_E2a"><font ITALIC="true"/></node>
</node>

<node TEXT="3. Executar checklist completo">
<node TEXT="Buscar moto por placa (autocomplete)"/>
<node TEXT="Confirmar revisao sugerida"/>
<node TEXT="Ajustar km atual"/>
<node TEXT="Iniciar inspecao"/>
<node TEXT="Marcar itens: OK / N-OK / N/A"/>
<node TEXT="Preencher observacoes"/>
<node TEXT="Tirar fotos onde exige_foto = true"/>
<node TEXT="Preencher medidas onde exige_medicao = true"/>
<node TEXT="Ver progresso na barra superior"/>
<node TEXT="Finalizar inspecao"/>
</node>

<node TEXT="4. Validar comportamento">
<node TEXT="Autosave a cada mudanca (indicador 'salvo')"/>
<node TEXT="Bloqueio de finalizacao se obrigatorio pendente"/>
<node TEXT="Km da moto atualizado automaticamente ao finalizar"/>
<node TEXT="Historico visivel no admin.html"/>
</node>
</node>

<!-- ============================================================ -->
<!-- FUNCIONALIDADES CHAVE                                           -->
<!-- ============================================================ -->
<node TEXT="Funcionalidades implementadas" POSITION="right" ID="ID_features" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>

<node TEXT="Selecao de moto">
<node TEXT="Autocomplete por placa (debounce 250ms)"/>
<node TEXT="Mostra km atual, ultima inspecao"/>
<node TEXT="Warning se sem historico"/>
</node>

<node TEXT="Sugestao inteligente de revisao">
<node TEXT="Funcao SQL sugerir_revisao(moto_id)"/>
<node TEXT="Baseada em km + historico"/>
<node TEXT="Permite override manual"/>
<node TEXT="Motivo explicativo"/>
</node>

<node TEXT="Renderizacao dinamica">
<node TEXT="Agrupado por categoria"/>
<node TEXT="Ordem definida por campo 'ordem'"/>
<node TEXT="Botoes 44px (touch target)"/>
<node TEXT="Cores: OK verde, N-OK vermelho, N/A cinza"/>
</node>

<node TEXT="Autosave com debounce">
<node TEXT="500ms apos ultima interacao"/>
<node TEXT="Upsert (nao gera duplicata)"/>
<node TEXT="Indicador visual: salvando / salvo / erro"/>
<node TEXT="flushSalvamentos antes de finalizar"/>
</node>

<node TEXT="Captura de foto">
<node TEXT="input file com capture=environment"/>
<node TEXT="Compressao via canvas (1600px / 75% quality)"/>
<node TEXT="Upload para bucket inspecoes/{insp_id}/{item_id}.jpg"/>
<node TEXT="URL assinada (bucket privado)"/>
</node>

<node TEXT="Progresso">
<node TEXT="Barra no header (X de Y, %)"/>
<node TEXT="Calculo local para reatividade"/>
<node TEXT="View vw_inspecao_progresso agregada"/>
</node>

<node TEXT="Validacao de finalizacao">
<node TEXT="Funcao SQL pode_finalizar_inspecao"/>
<node TEXT="Bloqueia se obrigatorio pendente"/>
<node TEXT="Bloqueia se foto/medicao exigida faltando"/>
<node TEXT="Mostra motivo especifico da falha"/>
</node>

<node TEXT="Trigger de km da moto">
<node TEXT="Atualiza motos.km_atual ao finalizar"/>
<node TEXT="Usa GREATEST (nunca regride)"/>
</node>
</node>

<!-- ============================================================ -->
<!-- ARTEFATOS                                                       -->
<!-- ============================================================ -->
<node TEXT="Artefatos entregues" POSITION="right" ID="ID_artefatos" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>
<node TEXT="sql/004_fase3_execucao.sql (migration)"/>
<node TEXT="sql/validacao_fase3.sql (asserts inline)"/>
<node TEXT="src/camera.js (captura + compressao + upload)"/>
<node TEXT="src/inspecao.js (autosave, progresso, validacao)"/>
<node TEXT="inspecao.html (3 telas: selecao, execucao, finalizacao)"/>
<node TEXT="tests/test_fase3.py (69 testes em 8 grupos)"/>
<node TEXT="Resultado: 69/69 passando localmente (100%)"/>
<node TEXT="Total geral: 264/264 (Fase 0+1+2+3)"/>
</node>

</node>
</map>
