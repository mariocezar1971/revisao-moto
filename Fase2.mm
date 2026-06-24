<map version="freeplane 1.11.0">
<node TEXT="Fase 2&#xa;CRUD de Motos" FOLDED="false" ID="ID_root" CREATED="1750000000000" MODIFIED="1750000000000" STYLE="oval">
<font SIZE="18" BOLD="true"/>
<edge COLOR="#006400" WIDTH="thin"/>
<richcontent TYPE="NOTE"><html><body>
<p>Cadastro, edicao, soft delete, filtros e paginacao de motos.</p>
<p>5 passos em sequencia.</p>
<p>Resultado esperado: 61/61 testes em test_fase2.py</p>
</body></html></richcontent>

<!-- ============================================================ -->
<!-- PASSO A - MIGRATION                                            -->
<!-- ============================================================ -->
<node TEXT="A. Aplicar migration no Supabase" POSITION="right" ID="ID_A" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="bookmark"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body>
<p><b>Onde:</b> dashboard Supabase &gt; SQL Editor</p>
<p>Adiciona campo 'ativo' (soft delete), indice, atualiza vw_motos_status, cria vw_motos_arquivadas e funcao reativar_moto.</p>
<p>Idempotente.</p>
</body></html></richcontent>
<node TEXT="1. sql/003_fase2_motos_ativo.sql -&gt; Run"/>
<node TEXT="2. sql/validacao_fase2.sql -&gt; Run"><icon BUILTIN="button_ok"/>
<richcontent TYPE="NOTE"><html><body><p>Esperado: TODAS AS VALIDACOES PASSARAM</p></body></html></richcontent>
</node>
</node>

<!-- ============================================================ -->
<!-- PASSO B - DEPLOY admin.html                                    -->
<!-- ============================================================ -->
<node TEXT="B. Deploy do admin.html" POSITION="right" ID="ID_B" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="folder"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body>
<p>O arquivo admin.html ja existe na raiz do projeto.</p>
<p>Se voce ja fez deploy no GitHub Pages, basta fazer git push.</p>
<p>Caso contrario, abre direto via http://localhost:8000/admin.html</p>
</body></html></richcontent>
<node TEXT="git add admin.html sql/003_*.sql sql/validacao_fase2.sql" ID="ID_B1"><font ITALIC="true"/></node>
<node TEXT="git commit -m 'Fase 2: CRUD de motos'" ID="ID_B2"><font ITALIC="true"/></node>
<node TEXT="git push" ID="ID_B3"><font ITALIC="true"/></node>
</node>

<!-- ============================================================ -->
<!-- PASSO C - SEED DEMO (opcional)                                 -->
<!-- ============================================================ -->
<node TEXT="C. Seed de motos demo (opcional)" POSITION="right" ID="ID_C" COLOR="#666666">
<font BOLD="true" SIZE="12" ITALIC="true"/>
<icon BUILTIN="info"/>
<edge COLOR="#666666"/>
<richcontent TYPE="NOTE"><html><body>
<p>Cole sql/seed_motos_demo.sql no SQL Editor.</p>
<p>Cria 5 motos de exemplo para testar a UI.</p>
<p>Pode apagar depois com: DELETE FROM motos WHERE placa IN ('ABC-1234','DEF-5678','GHI-9012','JKL-3456','MNO-7890');</p>
</body></html></richcontent>
<node TEXT="3. sql/seed_motos_demo.sql -&gt; Run"/>
</node>

<!-- ============================================================ -->
<!-- PASSO D - VALIDACAO AUTOMATIZADA (LOCAL)                       -->
<!-- ============================================================ -->
<node TEXT="D. Validacao automatizada (local)" POSITION="left" ID="ID_D" COLOR="#cc0000">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#cc0000" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p>Suite Fase 2: 61 testes em 8 grupos.</p>
<p>Valida: migration idempotente, campo ativo, indice, views, funcao reativar,</p>
<p>insert, edicao, trigger, soft delete, reativacao, filtros, paginacao, UI.</p>
<p>Roda contra Postgres efemero criado pelo run_tests.sh.</p>
</body></html></richcontent>
<node TEXT="./tests/run_tests.sh" ID="ID_D1"><font BOLD="true" ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body><p>Esperado: 195/195 testes passando (Fase 0+1+2 juntos)</p></body></html></richcontent>
</node>
</node>

<!-- ============================================================ -->
<!-- PASSO E - VALIDACAO VISUAL                                     -->
<!-- ============================================================ -->
<node TEXT="E. Validacao visual no celular" POSITION="left" ID="ID_E" COLOR="#cc0000">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="phone_mobile"/>
<edge COLOR="#cc0000"/>
<richcontent TYPE="NOTE"><html><body>
<p>Testa o CRUD na pratica com PC e celular na mesma Wi-Fi.</p>
<p>Pre-requisito: src/supabase-client.js ja configurado (Fase 1, passo H).</p>
</body></html></richcontent>
<node TEXT="1. Sirva o app" ID="ID_E1">
<node TEXT="python3 -m http.server 8000" ID="ID_E1_cmd"><font ITALIC="true"/></node>
</node>
<node TEXT="2. Abra no celular" ID="ID_E2">
<node TEXT="http://IP-DO-PC:8000/admin.html" ID="ID_E2_cmd"><font ITALIC="true"/></node>
</node>
<node TEXT="3. Teste o fluxo completo" ID="ID_E3">
<node TEXT="Login com seu admin"/>
<node TEXT="Cadastrar nova moto (placa, modelo, ano)"/>
<node TEXT="Filtrar por placa e proprietario"/>
<node TEXT="Editar moto cadastrada"/>
<node TEXT="Quick action de km (+Km)"/>
<node TEXT="Arquivar moto"/>
<node TEXT="Marcar 'Mostrar arquivadas' e Reativar"/>
</node>
</node>

<!-- Sub-arvore de referencia -->
<node TEXT="Artefatos entregues" POSITION="right" ID="ID_artefatos" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>
<node TEXT="sql/003_fase2_motos_ativo.sql (migration)"/>
<node TEXT="sql/seed_motos_demo.sql (5 motos demo)"/>
<node TEXT="sql/validacao_fase2.sql (asserts inline)"/>
<node TEXT="admin.html (CRUD completo)"/>
<node TEXT="tests/test_fase2.py (61 testes)"/>
<node TEXT="Resultado: 61/61 passando localmente (100%)"/>
</node>

</node>
</map>
