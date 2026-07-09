<map version="freeplane 1.11.0">
<node TEXT="Fase 4&#xa;Assinatura + PDF" FOLDED="false" ID="ID_root" CREATED="1750000000000" MODIFIED="1750000000000" STYLE="oval">
<font SIZE="18" BOLD="true"/>
<edge COLOR="#cc0000" WIDTH="thin"/>
<richcontent TYPE="NOTE"><html><body>
<p>Assinaturas em canvas + geracao de PDF + upload + compartilhamento.</p>
<p>5 passos em sequencia.</p>
<p>Resultado esperado: 347/347 testes totais + PDF real gerado no celular.</p>
</body></html></richcontent>

<!-- A. ATUALIZAR ARQUIVOS -->
<node TEXT="A. Atualizar arquivos locais" POSITION="right" ID="ID_A" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="folder"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body><p>Backup .env, unzip por cima, restaura .env.</p></body></html></richcontent>
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
<p>Cria: view vw_inspecoes_com_pdf, funcao assinaturas_completas, indice pdf_url.</p>
<p>Os campos ja existem no schema original (Fase 0).</p>
<p>Idempotente.</p>
</body></html></richcontent>
<node TEXT="1. sql/005_fase4_assinaturas_pdf.sql -&gt; Run"/>
<node TEXT="2. sql/validacao_fase4.sql -&gt; Run"><icon BUILTIN="button_ok"/>
<richcontent TYPE="NOTE"><html><body><p>Esperado: TODAS AS VALIDACOES PASSARAM (4 asserts)</p></body></html></richcontent>
</node>
</node>

<!-- C. VALIDAR LOCAL -->
<node TEXT="C. Validar localmente" POSITION="right" ID="ID_C" COLOR="#cc0000">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#cc0000" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p>Suite completa: Fase 0 (110) + 1 (24) + 2 (61) + 3 (69) + 4 (83) = 347 testes.</p>
</body></html></richcontent>
<node TEXT="./tests/run_tests.sh" ID="ID_C1"><font BOLD="true" ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body><p>Esperado: TODOS OS TESTES PASSARAM (Fase 0+1+2+3+4) - 347/347</p></body></html></richcontent>
</node>
</node>

<!-- D. DEPLOY -->
<node TEXT="D. Commit e push" POSITION="left" ID="ID_D" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="launch"/>
<edge COLOR="#0066cc"/>
<node TEXT="git add ." ID="ID_D1"><font ITALIC="true"/></node>
<node TEXT="git commit -m &quot;Fase 4: assinaturas e PDF (347 testes)&quot;" ID="ID_D2"><font ITALIC="true"/></node>
<node TEXT="git push" ID="ID_D3"><font ITALIC="true"/></node>
</node>

<!-- E. VALIDACAO VISUAL -->
<node TEXT="E. Validacao visual no celular" POSITION="left" ID="ID_E" COLOR="#cc0000">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="phone_mobile"/>
<edge COLOR="#cc0000"/>
<richcontent TYPE="NOTE"><html><body>
<p>Executa inspecao completa ate o PDF.</p>
<p>Testar em Android e iOS se possivel (Web Share API varia).</p>
</body></html></richcontent>

<node TEXT="1. Executar inspecao">
<node TEXT="Selecionar moto"/>
<node TEXT="Preencher todos os itens"/>
<node TEXT="Ir para finalizacao"/>
</node>

<node TEXT="2. Coletar assinaturas">
<node TEXT="Preencher nome do cliente"/>
<node TEXT="Assinar como mecanico (touch)"/>
<node TEXT="Assinar como cliente (touch)"/>
<node TEXT="Testar botao 'Limpar' se necessario"/>
</node>

<node TEXT="3. Gerar PDF">
<node TEXT="Botao 'Finalizar e gerar PDF'"/>
<node TEXT="Tela de progresso: Coletando... Gerando... Enviando..."/>
<node TEXT="Tela de sucesso com hash SHA-256"/>
</node>

<node TEXT="4. Compartilhar">
<node TEXT="Compartilhar via WhatsApp/e-mail"/>
<node TEXT="Baixar PDF localmente"/>
<node TEXT="Copiar link (URL assinada 1h)"/>
</node>

<node TEXT="5. Verificar no Supabase">
<node TEXT="inspecoes.status = finalizada"/>
<node TEXT="inspecoes.pdf_url preenchido"/>
<node TEXT="inspecoes.hash_integridade preenchido"/>
<node TEXT="Storage: inspecoes/{id}/relatorio.pdf"/>
</node>
</node>

<!-- FUNCIONALIDADES -->
<node TEXT="Funcionalidades implementadas" POSITION="right" ID="ID_features" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>

<node TEXT="Canvas de assinatura">
<node TEXT="Pointer events (touch + mouse)"/>
<node TEXT="touch-action: none (impede scroll)"/>
<node TEXT="DevicePixelRatio para HDPI"/>
<node TEXT="Botao limpar"/>
<node TEXT="Export base64 PNG"/>
<node TEXT="Reinicializa em resize"/>
</node>

<node TEXT="Coleta de assinaturas">
<node TEXT="Mecanico (foiTocado() obrigatorio)"/>
<node TEXT="Cliente (foiTocado() obrigatorio)"/>
<node TEXT="Nome do cliente (input obrigatorio)"/>
</node>

<node TEXT="Geracao do PDF">
<node TEXT="jsPDF via CDN"/>
<node TEXT="Cabecalho colorido (vermelho RE)"/>
<node TEXT="Dados moto + proprietario"/>
<node TEXT="Tabela de itens agrupada por categoria"/>
<node TEXT="Status colorido (OK verde, N-OK vermelho, N/A cinza)"/>
<node TEXT="Fotos embarcadas como thumbnails (42x32mm)"/>
<node TEXT="Assinaturas com linha separadora"/>
<node TEXT="SHA-256 no rodape de todas as paginas"/>
<node TEXT="Multi-pagina automatico"/>
</node>

<node TEXT="Upload para Storage">
<node TEXT="Path: inspecoes/{insp_id}/relatorio.pdf"/>
<node TEXT="upsert (permite substituir)"/>
<node TEXT="Atualiza inspecoes.pdf_url + hash_integridade"/>
</node>

<node TEXT="Compartilhamento">
<node TEXT="Web Share API (nativo mobile)"/>
<node TEXT="Fallback: copia URL para clipboard"/>
<node TEXT="Download local direto (blob)"/>
<node TEXT="URL assinada valida 1h"/>
</node>

<node TEXT="Hash SHA-256 de integridade">
<node TEXT="Web Crypto API (crypto.subtle.digest)"/>
<node TEXT="Cobre: id, moto, km, data, itens (status/valor/obs)"/>
<node TEXT="Salvo em inspecoes.hash_integridade"/>
<node TEXT="Impresso no rodape do PDF"/>
</node>
</node>

<!-- ARTEFATOS -->
<node TEXT="Artefatos entregues" POSITION="right" ID="ID_artefatos" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>
<node TEXT="sql/005_fase4_assinaturas_pdf.sql (migration)"/>
<node TEXT="sql/validacao_fase4.sql (asserts inline)"/>
<node TEXT="src/assinatura.js (canvas pointer events, 122 linhas)"/>
<node TEXT="src/pdf.js (jsPDF, hash, upload, share, 405 linhas)"/>
<node TEXT="inspecao.html (atualizado - 5 telas)"/>
<node TEXT="tests/test_fase4.py (83 testes em 8 grupos)"/>
<node TEXT="Resultado: 83/83 passando (100%)"/>
<node TEXT="Total geral: 347/347 (Fase 0+1+2+3+4)"/>
</node>

</node>
</map>
