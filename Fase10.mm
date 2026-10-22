<map version="freeplane 1.11.0">
<!--To view this file, download free mind mapping software Freeplane from https://www.freeplane.org -->
<node TEXT="Fase 10 (P3)&#xa;Media prioridade" FOLDED="false" ID="ID_root" STYLE="oval">
<font SIZE="18" BOLD="true"/>
<edge COLOR="#9333ea" WIDTH="thin"/>
<richcontent TYPE="NOTE"><html><body>
<p>Os 5 itens P3: comparacao entre revisoes, teste de rodagem,</p>
<p>garantia, torque aplicado e revisao rapida vs completa.</p>
<p>Aqui o app para de olhar so a revisao de hoje e passa a olhar</p>
<p>a vida da moto: o que mudou, o que esta coberto, o que foi</p>
<p>realmente apertado e quanto trabalho a visita de hoje pede.</p>
<p><b>206/206 testes. Total do projeto: 1120.</b></p>
</body></html></richcontent>

<!-- PASSOS                                                       -->
<node TEXT="Passos" POSITION="right" ID="ID_passos" COLOR="#0066cc">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="list"/>
<edge COLOR="#0066cc" WIDTH="2"/>

<!-- 10. COMPARACAO -->
<node TEXT="10. Comparacao entre revisoes">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>O historico mostrava cada revisao isolada. Agora mostra a</p>
<p>diferenca: pastilha 4,0 -&gt; 2,8 mm eh desgaste de 1,2 mm em</p>
<p>4.500 km. A chave eh itens_checklist.chave_medicao, que</p>
<p>identifica o mesmo item fisico mesmo quando a descricao muda</p>
<p>de uma revisao para a outra.</p>
</body></html></richcontent>
<node TEXT="comparar_inspecoes(uuid, uuid)">
<node TEXT="Casa as duas inspecoes por chave_medicao, nao por texto"/>
<node TEXT="Retorna anterior, atual, variacao, pct, tendencia, semaforo"/>
</node>
<node TEXT="Tendencia depende do TIPO do item">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Primeira versao dizia que folga de corrente 25 -&gt; 28 mm numa</p>
<p>faixa de 20-30 mm &quot;melhorou&quot;, porque so olhava se o numero</p>
<p>subiu. Errado: em item de faixa o bom eh estar no meio.</p>
</body></html></richcontent>
<node TEXT="FAIXA (min e max): afastar-se do centro = piorou"/>
<node TEXT="DESGASTE (so min): cair = piorou (pastilha, disco)"/>
<node TEXT="TETO (so max): subir = piorou (folga de valvula)"/>
</node>
<node TEXT="historico_medicao(moto_id, chave)">
<node TEXT="Serie completa de uma medicao ao longo das revisoes"/>
<node TEXT="Alimenta o grafico SVG com linha tracejada no limite"/>
</node>
<node TEXT="vw_inspecoes_comparaveis"/>
<node TEXT="comparacao.html + src/comparacao.js">
<node TEXT="Busca por placa, par de revisoes, resumo piorou/estavel/melhorou"/>
<node TEXT="Grafico de evolucao item a item"/>
</node>
</node>

<!-- 11. RODAGEM -->
<node TEXT="11. Teste de rodagem estruturado">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>O teste de rodagem existia como campo de texto livre. Virou</p>
<p>checklist de 14 itens com km inicial/final, condicao de pista</p>
<p>e responsavel, para que o que foi testado fique registrado.</p>
</body></html></richcontent>
<node TEXT="rodagem_itens (14 itens de seed)">
<node TEXT="Freios, motor, cambio, suspensao, direcao, eletrica, ruidos"/>
</node>
<node TEXT="inspecao_rodagem (cabecalho da volta)">
<node TEXT="km_inicial, km_final, condicao_pista, responsavel, obs"/>
</node>
<node TEXT="inspecao_rodagem_itens (resposta por item)"/>
<node TEXT="rodagem_completa(uuid)">
<node TEXT="Bloqueia encerrar com item obrigatorio em branco"/>
</node>
<node TEXT="vw_rodagem"/>
<node TEXT="src/rodagem.js">
<node TEXT="progressoLocal() calcula sem ida ao servidor (offline)"/>
</node>
</node>

<!-- 12. GARANTIA -->
<node TEXT="12. Garantia">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>CDC art. 26: 90 dias de garantia para servico duravel.</p>
<p>O app nao sabia se a visita era paga, retorno de garantia da</p>
<p>oficina ou garantia de fabrica - e cobrava sempre.</p>
</body></html></richcontent>
<node TEXT="4 tipos de cobranca, cada um com cobra: boolean">
<node TEXT="pago, garantia_oficina, garantia_fabrica, cortesia"/>
</node>
<node TEXT="6 colunas novas em inspecoes">
<node TEXT="tipo_cobranca, garantia_ate, garantia_obs, inspecao_origem"/>
<node TEXT="(+ tipo_execucao e servico_rapido_id, do item 14)"/>
</node>
<node TEXT="trigger_definir_garantia()">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Abre a janela de 90 dias ao finalizar, mas SO para trabalho</p>
<p>pago ou de garantia de fabrica. Retorno de garantia da propria</p>
<p>oficina nao reinicia o prazo - senao a garantia se renovaria</p>
<p>para sempre a cada retorno.</p>
</body></html></richcontent>
</node>
<node TEXT="garantia_vigente(moto_id)">
<node TEXT="Avisa na abertura: &quot;coberto ate 12/01, OS 240&quot;"/>
<node TEXT="Quando coberto, o app pula a aprovacao de orcamento"/>
</node>
<node TEXT="vw_garantias_vigentes"/>
<node TEXT="PDF mostra R$ 0,00 com o valor de referencia ao lado"/>
</node>

<!-- 13. TORQUE -->
<node TEXT="13. Torque efetivamente aplicado">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>A tela de especificacoes (Fase 7) dizia qual torque usar.</p>
<p>Nao havia registro do que foi aplicado de fato - o que importa</p>
<p>se a roda solta depois.</p>
</body></html></richcontent>
<node TEXT="inspecao_torques (registro por ponto)"/>
<node TEXT="torques_do_modelo(modelo_id)">
<node TEXT="Puxa as specs do modelo para a tela de execucao"/>
</node>
<node TEXT="avaliar_torque(aplicado, spec, tolerancia)">
<node TEXT="Tolerancia padrao 10%: ok / frouxo / apertado / sem_spec"/>
<node TEXT="Mesma regra duplicada em src/torque.js para offline"/>
<node TEXT="Verificado 6/6 contra o resultado do SQL"/>
</node>
<node TEXT="vw_torques_inspecao"/>
<node TEXT="Secao TORQUES APLICADOS no PDF"/>
</node>

<!-- 14. RAPIDA VS COMPLETA -->
<node TEXT="14. Revisao rapida vs completa">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Abrir checklist de 22 itens para uma troca de oleo eh atrito</p>
<p>puro. Tres modos: completa (como sempre), rapida (so os itens</p>
<p>do servico) e avulsa (so o que o mecanico adicionar).</p>
</body></html></richcontent>
<node TEXT="servicos_rapidos (6 servicos de seed)">
<node TEXT="Troca de oleo, relacao, freios, pneus, bateria, revisao de entrega"/>
</node>
<node TEXT="itens_do_servico_rapido(servico_id, revisao_id)">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Filtro foi corrigido duas vezes. Com OR entre categoria e</p>
<p>palavra-chave, a troca de oleo arrastava filtro de ar e</p>
<p>mangueiras do EVAP. Virou AND. Depois as palavras ainda eram</p>
<p>largas: &quot;filtro&quot; pegava filtro de ar, &quot;folga&quot; pegava folga de</p>
<p>embreagem na regulagem de corrente. Estreitadas para</p>
<p>['oleo','dreno'] e ['corrente','coroa','pinhao','relacao'].</p>
</body></html></richcontent>
</node>
<node TEXT="pode_finalizar_por_tipo(inspecao_id)">
<node TEXT="Revisao rapida nunca teria todos os itens da completa"/>
<node TEXT="A checagem da Fase 3 reprovaria sempre sem isso"/>
</node>
<node TEXT="vw_servicos_rapidos"/>
<node TEXT="Seletor de tipo no topo de inspecao.html"/>
</node>

<!-- BUG ENCONTRADO -->
<node TEXT="Bug pre-existente encontrado aqui" COLOR="#cc0000">
<font BOLD="true"/>
<icon BUILTIN="messagebox_warning"/>
<richcontent TYPE="NOTE"><html><body>
<p>vw_checklist_completo expoe a chave como item_id (vem de</p>
<p>&quot;i.id AS item_id&quot;), mas renderItem(), marcarStatus() e o mapa</p>
<p>de respostas usam item.id. Confirmado com</p>
<p>to_jsonb(v) ? 'id' retornando false.</p>
<p><b>Resultado: item.id era undefined, os botoes OK/N-OK/N/A</b></p>
<p><b>chamavam marcarStatus(undefined) e o checklist nao salvava.</b></p>
<p>Isso valia para TODAS as versoes anteriores, nao so a Fase 10.</p>
</body></html></richcontent>
<node TEXT="Correcao em src/inspecao.js">
<node TEXT="carregarItensDaRevisao() faz map(i =&gt; ({...i, id: i.item_id}))"/>
<node TEXT="Nos dois caminhos: checklist completo e servico rapido"/>
</node>
<node TEXT="Grupo de regressao dedicado em test_fase10.py"/>
</node>
</node>

<!-- ORQUESTRADOR                                                 -->
<node TEXT="Orquestrador" POSITION="right" ID="ID_orq" COLOR="#059669">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#059669" WIDTH="2"/>

<node TEXT="0. Estar no WSL (nao no PowerShell)">
<font BOLD="true"/>
<node TEXT="wsl"/>
<node TEXT="Alternativa numa linha so, direto do PowerShell:"/>
<node TEXT="wsl -d Ubuntu -- bash -lc &quot;cd /mnt/c/Users/mceza/Dropbox/PROGRAMACAO/JAVASCRIPT/APLICATIVOS/revisao-moto/revisao-moto &amp;&amp; ./orquestrador_fase10.sh --all&quot;"/>
</node>

<node TEXT="1. Ir ate o projeto no Dropbox">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Nesta fase os arquivos foram escritos direto no Dropbox, nao</p>
<p>entregues em zip. Nao ha unzip nem recolocar credenciais: o</p>
<p>.env e o src/supabase-client.js locais nao foram tocados.</p>
</body></html></richcontent>
<node TEXT="cd /mnt/c/Users/mceza/Dropbox/PROGRAMACAO/JAVASCRIPT/APLICATIVOS/revisao-moto/revisao-moto"/>
<node TEXT="Esperar o Dropbox terminar de sincronizar antes de rodar"/>
<node TEXT="Conferir que chegou: ls -la sql/010_fase10_p3.sql src/torque.js"/>
</node>

<node TEXT="2. Conferir que as credenciais continuam no lugar">
<font BOLD="true"/>
<node TEXT="grep -c &quot;supabase.co&quot; src/supabase-client.js"/>
<node TEXT="Se der 0, recolocar: source .env"/>
<node TEXT="sed -i &quot;s|https://SEU_PROJETO.supabase.co|$SUPABASE_URL|&quot; src/supabase-client.js"/>
<node TEXT="sed -i &quot;s|SUA_ANON_KEY_AQUI|$SUPABASE_ANON_KEY|&quot; src/supabase-client.js"/>
</node>

<node TEXT="3. Rodar o orquestrador">
<font BOLD="true"/>
<node TEXT="chmod +x orquestrador_fase10.sh tests/run_tests.sh"/>
<node TEXT="./orquestrador_fase10.sh --help"/>
<node TEXT="./orquestrador_fase10.sh"/>
<node TEXT="./orquestrador_fase10.sh --all"/>
<node TEXT="Esperado: TODOS OS TESTES PASSARAM (Fase 0 -&gt; 10), 1120 testes"/>
</node>

<node TEXT="4. Correcao de versao do service worker nas fases 6 a 9">
<font BOLD="true"/>
<icon BUILTIN="messagebox_warning"/>
<richcontent TYPE="NOTE"><html><body>
<p>Ja corrigido nos arquivos entregues, registrado aqui porque</p>
<p>quebrou na primeira rodada do --all.</p>
<p>O cache subiu de v0.9.0 para v1.0.0 e as fases 6..9 testavam</p>
<p>a versao com a regex v0\.(\d+), que nunca casa com v1.x.</p>
<p>Agora comparam a tupla (maior, menor) &gt;= (0, 6) etc.</p>
</body></html></richcontent>
<node TEXT="grep -n &quot;CACHE_VERSION&quot; service-worker.js"/>
<node TEXT="Esperado: const CACHE_VERSION = 'v1.0.0';"/>
</node>

<node TEXT="5. Aplicar a migration no Supabase">
<font BOLD="true"/>
<node TEXT="cat sql/010_fase10_p3.sql | clip.exe"/>
<node TEXT="Colar no SQL Editor do projeto jybfdknrxzlwpjyrayrb e rodar"/>
<node TEXT="A migration eh idempotente: pode rodar de novo sem estragar nada"/>
<node TEXT="Conferir (esperado: 5, 9, 5, 1, 14, 6)"/>
<node TEXT="SELECT count(*) FROM information_schema.tables WHERE table_name IN ('rodagem_itens','inspecao_rodagem','inspecao_rodagem_itens','inspecao_torques','servicos_rapidos');"/>
<node TEXT="SELECT count(*) FROM pg_proc WHERE proname IN ('comparar_inspecoes','historico_medicao','rodagem_completa','garantia_vigente','torques_do_modelo','avaliar_torque','itens_do_servico_rapido','pode_finalizar_por_tipo','trigger_definir_garantia');"/>
<node TEXT="SELECT count(*) FROM information_schema.views WHERE table_name LIKE 'vw_%' AND table_name IN ('vw_inspecoes_comparaveis','vw_rodagem','vw_garantias_vigentes','vw_torques_inspecao','vw_servicos_rapidos');"/>
<node TEXT="SELECT count(*) FROM pg_trigger WHERE tgname = 'set_garantia_ao_finalizar';"/>
<node TEXT="SELECT count(*) FROM rodagem_itens;"/>
<node TEXT="SELECT count(*) FROM servicos_rapidos;"/>
</node>

<node TEXT="6. Commit e push">
<font BOLD="true"/>
<node TEXT="git status --short"/>
<node TEXT="git add -A"/>
<node TEXT="git commit -m &quot;Fase 10 (P3): comparacao, rodagem, garantia, torque, servico rapido&quot;"/>
<node TEXT="git push"/>
<node TEXT="GitHub Pages republica em ~1 min"/>
</node>

<node TEXT="7. Forcar atualizacao do app no celular">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>O service worker v1.0.0 limpa os caches antigos sozinho, mas</p>
<p>o navegador pode servir a pagina velha uma vez antes disso.</p>
</body></html></richcontent>
<node TEXT="Fechar e reabrir o app, ou limpar dados do site"/>
</node>
</node>

<!-- TESTE EM CAMPO                                               -->
<node TEXT="Teste em campo" POSITION="left" COLOR="#b45309">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="help"/>
<edge COLOR="#b45309" WIDTH="2"/>

<node TEXT="Comparacao">
<node TEXT="Abrir comparacao.html, buscar uma placa com 2+ revisoes"/>
<node TEXT="Conferir se o resumo piorou/estavel/melhorou faz sentido"/>
<node TEXT="Trocar o item no grafico e ver a linha tracejada do limite"/>
</node>
<node TEXT="Servico rapido">
<node TEXT="Nova inspecao, escolher Servico rapido &gt; Troca de oleo"/>
<node TEXT="O checklist deve vir curto, sem filtro de ar"/>
<node TEXT="Finalizar: nao deve pedir os itens da revisao completa"/>
</node>
<node TEXT="Garantia">
<node TEXT="Abrir inspecao numa moto revisada nos ultimos 90 dias"/>
<node TEXT="Deve aparecer o aviso de cobertura no topo"/>
<node TEXT="Marcar garantia_oficina e conferir R$ 0,00 no PDF"/>
</node>
<node TEXT="Torque">
<node TEXT="Registrar um valor fora de 10% da spec"/>
<node TEXT="Deve pintar frouxo ou apertado na hora, sem recarregar"/>
</node>
<node TEXT="Rodagem">
<node TEXT="Iniciar a volta, deixar um item obrigatorio em branco"/>
<node TEXT="Encerrar deve ser bloqueado"/>
</node>
<node TEXT="Checklist (regressao do bug do item.id)">
<font BOLD="true"/>
<icon BUILTIN="messagebox_warning"/>
<node TEXT="Marcar OK num item e recarregar a pagina"/>
<node TEXT="A resposta tem que continuar la - antes nao continuava"/>
</node>
</node>

<!-- ESTADO                                                       -->
<node TEXT="Estado" POSITION="left" COLOR="#64748b">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="info"/>
<edge COLOR="#64748b" WIDTH="2"/>

<node TEXT="Testes por fase">
<node TEXT="0=111  1=24  2=61  3=69  4=83  5=80"/>
<node TEXT="6=83  7=122  8=145  9=136  10=206"/>
<node TEXT="Total: 1120"/>
</node>
<node TEXT="Arquivos novos nesta fase">
<node TEXT="sql/010_fase10_p3.sql"/>
<node TEXT="comparacao.html"/>
<node TEXT="src/comparacao.js  src/rodagem.js  src/garantia.js"/>
<node TEXT="src/torque.js  src/servicos.js"/>
<node TEXT="tests/test_fase10.py  orquestrador_fase10.sh  Fase10.mm"/>
</node>
<node TEXT="Arquivos alterados">
<node TEXT="src/inspecao.js (correcao do item.id)"/>
<node TEXT="src/pdf.js (torques e rodagem no PDF)"/>
<node TEXT="inspecao.html (tipo de execucao, garantia, torque, rodagem)"/>
<node TEXT="index.html (link Comparar revisoes)"/>
<node TEXT="service-worker.js (v1.0.0)"/>
<node TEXT="tests/run_tests.sh  tests/test_fase6..9.py  README.md"/>
</node>
<node TEXT="Resta do roadmap: P4">
<richcontent TYPE="NOTE"><html><body>
<p>P4 so faz sentido com escala: agendamento, estoque de pecas,</p>
<p>multi-tenancy (mais de uma oficina), leitura de VIN,</p>
<p>API publica e nota fiscal.</p>
</body></html></richcontent>
</node>
</node>

</node>
</map>
