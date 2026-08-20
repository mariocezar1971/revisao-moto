<map version="freeplane 1.11.0">
<node TEXT="Fase 6&#xa;Suporte Offline" FOLDED="false" ID="ID_root" STYLE="oval">
<font SIZE="18" BOLD="true"/>
<edge COLOR="#cc0000" WIDTH="thin"/>
<richcontent TYPE="NOTE"><html><body>
<p>Cache local de catalogo, fila de escritas pendentes, sync automatico ao voltar online.</p>
<p>2 novos modulos JS + Service Worker atualizado + integracao em 4 paginas.</p>
<p>Resultado: 83/83 testes locais.</p>
</body></html></richcontent>

<node TEXT="A. Atualizar arquivos locais" POSITION="right" ID="ID_A" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="folder"/>
<edge COLOR="#0066cc"/>
<node TEXT="cp .env /tmp/.env.backup"><font ITALIC="true"/></node>
<node TEXT="cd .. &amp;&amp; unzip -o ~/Downloads/revisao-moto.zip &amp;&amp; cd revisao-moto"><font ITALIC="true"/></node>
<node TEXT="cp /tmp/.env.backup .env"><font ITALIC="true"/></node>
</node>

<node TEXT="B. Validar localmente" POSITION="right" ID="ID_B" COLOR="#cc0000">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#cc0000" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p>Fase 6 NAO exige PostgreSQL (testes sao estaticos).</p>
<p>Isolado: ~5 segundos. Completo (0-6): ~40 segundos, 510 testes.</p>
</body></html></richcontent>
<node TEXT="chmod +x orquestrador_fase6.sh"><font ITALIC="true"/></node>
<node TEXT="./orquestrador_fase6.sh"><font BOLD="true" ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body><p>Roda so testes Fase 6. Rapido.</p></body></html></richcontent>
</node>
<node TEXT="./orquestrador_fase6.sh --all"><font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body><p>Roda toda a suite. Esperado: 510/510.</p></body></html></richcontent>
</node>
</node>

<node TEXT="C. Commit e push" POSITION="left" ID="ID_C" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="launch"/>
<edge COLOR="#0066cc"/>
<node TEXT="git add ."><font ITALIC="true"/></node>
<node TEXT="git commit -m &quot;Fase 6: suporte offline (83 testes)&quot;"><font ITALIC="true"/></node>
<node TEXT="git push"><font ITALIC="true"/></node>
<node TEXT="Aguardar GitHub Pages redeployar (~1 min)"><font ITALIC="true"/></node>
</node>

<node TEXT="D. Teste manual no celular" POSITION="left" ID="ID_D" COLOR="#cc0000">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="phone_mobile"/>
<edge COLOR="#cc0000"/>
<richcontent TYPE="NOTE"><html><body>
<p>A funcionalidade offline so pode ser validada realmente no browser (IndexedDB, eventos online/offline).</p>
<p>Testes automatizados verificam estrutura e sintaxe.</p>
</body></html></richcontent>

<node TEXT="1. Cachear catalogo (com internet)">
<node TEXT="Abrir index.html no celular (online)"/>
<node TEXT="Fazer login"/>
<node TEXT="Abrir console (DevTools ou eruda)"/>
<node TEXT="Executar: window.offline.cachearCatalogo()"/>
<node TEXT="Esperado: {sucesso: true, modelos: 10, revisoes: 70, itens: 1300}"/>
</node>

<node TEXT="2. Simular perda de conexao">
<node TEXT="Ativar modo aviao no celular"/>
<node TEXT="Bolinha no header vira VERMELHA - 'Offline'"/>
</node>

<node TEXT="3. Fazer uma inspecao offline">
<node TEXT="Ir para inspecao.html"/>
<node TEXT="Buscar moto por placa (usa cache)"/>
<node TEXT="Marcar itens OK/nao-OK"/>
<node TEXT="Bolinha muda: 'Offline - N na fila'"/>
</node>

<node TEXT="4. Voltar online">
<node TEXT="Desativar modo aviao"/>
<node TEXT="Bolinha fica AMARELA (Sincronizando)"/>
<node TEXT="Bolinha fica VERDE (Online) quando termina"/>
<node TEXT="Verificar no Supabase que dados chegaram"/>
</node>

<node TEXT="5. Forcar sincronizacao">
<node TEXT="Se ainda houver pendentes, clicar na bolinha"/>
</node>
</node>

<node TEXT="Arquitetura implementada" POSITION="right" ID="ID_arq" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>

<node TEXT="src/offline.js (nucleo)">
<node TEXT="Wrapper sobre IndexedDB (DB: revisao_moto_offline)"/>
<node TEXT="4 object stores: catalogo, inspecoes_locais, pending_operations, fotos_pendentes"/>
<node TEXT="cachearCatalogo(): cacheia modelos+revisoes+itens"/>
<node TEXT="obterCatalogo(chave): read-through"/>
<node TEXT="enfileirarOperacao(tipo, dados): grava na fila"/>
<node TEXT="4 tipos: upsert_item, update_inspecao, insert_inspecao, upload_foto"/>
<node TEXT="sincronizar(): processa fila com retry"/>
<node TEXT="Backoff exponencial: 5s, 10s, 20s, 40s, 80s"/>
<node TEXT="MAX_TENTATIVAS=5 -&gt; marca 'desistido'"/>
<node TEXT="salvarItemInteligente(): online-first / offline-fallback"/>
<node TEXT="Auto-sync a cada 30s enquanto online"/>
<node TEXT="Sync imediato ao voltar online"/>
</node>

<node TEXT="src/status_offline.js (widget)">
<node TEXT="Badge fixo top-right z-index 60"/>
<node TEXT="Bolinha VERDE: online, sem pendencias"/>
<node TEXT="Bolinha VERDE + N: online mas com N na fila"/>
<node TEXT="Bolinha AMARELA (pulsando): sincronizando"/>
<node TEXT="Bolinha VERMELHA: offline"/>
<node TEXT="Bolinha VERMELHA + N: offline com N na fila"/>
<node TEXT="Click quando online + pendentes: forca sync"/>
<node TEXT="Click quando offline: mostra explicacao"/>
<node TEXT="Refresh do contador a cada 5s"/>
</node>

<node TEXT="service-worker.js (v0.6.0)">
<node TEXT="APP_SHELL: 4 HTMLs + 8 modulos JS + assets + CDNs"/>
<node TEXT="Inclui jsPDF da CDN"/>
<node TEXT="Cache-first para app shell"/>
<node TEXT="Network-first para Supabase"/>
<node TEXT="Fallback offline: retorna index.html cached"/>
</node>

<node TEXT="Integracao">
<node TEXT="index.html: importa offline.js + status_offline.js"/>
<node TEXT="admin.html: idem"/>
<node TEXT="inspecao.html: idem (usa salvarItemInteligente futuramente)"/>
<node TEXT="historico.html: idem"/>
</node>
</node>

<node TEXT="Limitacoes conhecidas" POSITION="right" ID="ID_lim" COLOR="#996600">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="messagebox_warning"/>
<node TEXT="Fotos capturadas offline aguardam sync">
<node TEXT="Se navegador limpar cache antes de sync, foto perdida"/>
</node>
<node TEXT="Autenticacao exige online (primeira vez)">
<node TEXT="Sessao Supabase eh persistida em localStorage"/>
<node TEXT="Depois de logado, funciona offline"/>
</node>
<node TEXT="Conflitos nao sao resolvidos">
<node TEXT="Last-write-wins (upsert)"/>
<node TEXT="Aceitavel para 1 mecanico por moto por inspecao"/>
</node>
<node TEXT="Fila nao persiste entre trocas de usuario">
<node TEXT="Se trocar de conta antes de sync, mudancas ficam orfas"/>
</node>
</node>

<node TEXT="Artefatos entregues" POSITION="left" ID="ID_artefatos" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>
<node TEXT="src/offline.js (~350 linhas)"/>
<node TEXT="src/status_offline.js (~150 linhas)"/>
<node TEXT="service-worker.js atualizado (v0.6.0)"/>
<node TEXT="tests/test_fase6.py (83 testes em 7 grupos)"/>
<node TEXT="orquestrador_fase6.sh (validacao 1-comando)"/>
<node TEXT="index.html, admin.html, inspecao.html, historico.html atualizados"/>
<node TEXT="Resultado: 83/83 na Fase 6 (100%)"/>
<node TEXT="Total geral: 510/510 (Fase 0 -&gt; 6)"/>
</node>

</node>
</map>
