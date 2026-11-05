<map version="freeplane 1.11.0">
<!--To view this file, download free mind mapping software Freeplane from https://www.freeplane.org -->
<node TEXT="Revis&#xe3;o Moto&#xa;Fluxo de Trabalho" FOLDED="false" ID="ID_root" STYLE="oval">
<font SIZE="18" BOLD="true"/>
<edge COLOR="#cc0000" WIDTH="thin"/>
<richcontent TYPE="NOTE"><html><body>
<p>A ordem em que o app eh usado numa revis&#xe3;o de verdade, da moto</p>
<p>chegando no p&#xe1;tio ao PDF na m&#xe3;o do cliente.</p>
<p>&#160;</p>
<p>Escrito a partir do c&#xf3;digo publicado (commit f50253d), n&#xe3;o do</p>
<p>que o app deveria fazer: cada trava listada aqui existe mesmo e</p>
<p>vai barrar voc&#xea; se o passo anterior ficou pela metade.</p>
<p>&#160;</p>
<p><b>Nenhuma revis&#xe3;o real passou por este fluxo ainda.</b> Ele &#xe9; a</p>
<p>hip&#xf3;tese a testar, n&#xe3;o o procedimento consagrado - espere que</p>
<p>a primeira revis&#xe3;o de verdade o contradiga em algum ponto.</p>
</body></html></richcontent>

<!-- ============================================================ -->
<!-- 1. A MOTO CHEGA                                              -->
<!-- ============================================================ -->
<node TEXT="1. A moto chega" POSITION="right" ID="ID_chega" COLOR="#b45309">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="forward"/>
<edge COLOR="#b45309" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p>Antes de encostar na moto. Esta etapa n&#xe3;o &#xe9; sobre a revis&#xe3;o:</p>
<p>&#xe9; sobre provar em que estado a moto chegou.</p>
</body></html></richcontent>

<node TEXT="Achar a moto">
<node TEXT="Buscar pela placa, ou"/>
<node TEXT="Escanear o QR colado na moto (qrcode.html)">
<node TEXT="Abre direto na inspe&#xe7;&#xe3;o, sem digitar placa"/>
</node>
<node TEXT="Moto nova: cadastrar antes (admin.html)"/>
</node>

<node TEXT="Vistoria de entrada (recebimento.html)">
<font BOLD="true"/>
<icon BUILTIN="attach"/>
<node TEXT="4 fotos: frente, tr&#xe1;s, lado esq, lado dir">
<icon BUILTIN="messagebox_warning"/>
<richcontent TYPE="NOTE"><html><body>
<p>Obrigat&#xf3;rias. A vistoria n&#xe3;o conclui sem as quatro, e o</p>
<p>contador mostra quantas faltam. S&#xe3;o elas que respondem</p>
<p>&quot;esse risco no tanque n&#xe3;o estava a&#xed;&quot; tr&#xea;s semanas depois.</p>
</body></html></richcontent>
</node>
<node TEXT="Avarias: texto livre + marca&#xe7;&#xf5;es no diagrama"/>
<node TEXT="N&#xed;vel de combust&#xed;vel (vazio / 1-4 / 1-2 / 3-4 / cheio)"/>
<node TEXT="Acess&#xf3;rios: ba&#xfa;, capacete, documentos, outros"/>
<node TEXT="Km de entrada"/>
<node TEXT="Assinatura do CLIENTE, ali, antes do servi&#xe7;o">
<icon BUILTIN="messagebox_warning"/>
<node TEXT="Nome com 3 letras ou mais, sen&#xe3;o n&#xe3;o conta"/>
</node>
</node>

<node TEXT="Quando pular a vistoria">
<node TEXT="Moto do pr&#xf3;prio dono da oficina"/>
<node TEXT="Servi&#xe7;o de 10 minutos com o cliente esperando"/>
<node TEXT="Nos dois casos: a prova some junto. Decis&#xe3;o sua."/>
</node>
</node>

<!-- ============================================================ -->
<!-- 2. ABRIR A INSPECAO                                          -->
<!-- ============================================================ -->
<node TEXT="2. Abrir a inspe&#xe7;&#xe3;o" POSITION="right" ID="ID_abrir" COLOR="#0066cc">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="pencil"/>
<edge COLOR="#0066cc" WIDTH="2"/>

<node TEXT="Escolher o TIPO de execu&#xe7;&#xe3;o">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Primeira decis&#xe3;o da tela, e a que mais muda o resto.</p>
<p>Escolher errado aqui significa um checklist de 22 itens</p>
<p>para uma troca de &#xf3;leo, ou o contr&#xe1;rio.</p>
</body></html></richcontent>
<node TEXT="Completa: todos os itens da revis&#xe3;o prevista pelo km"/>
<node TEXT="R&#xe1;pida: s&#xf3; os itens do servi&#xe7;o escolhido">
<node TEXT="Troca de &#xf3;leo"/>
<node TEXT="Troca de pastilhas"/>
<node TEXT="Ajuste de corrente"/>
<node TEXT="Pneus"/>
<node TEXT="Bateria e el&#xe9;trica"/>
<node TEXT="Vela e filtro de ar"/>
</node>
<node TEXT="Avulsa: s&#xf3; o que voc&#xea; adicionar na hora"/>
</node>

<node TEXT="O app avisa se a moto est&#xe1; em garantia">
<font BOLD="true"/>
<icon BUILTIN="idea"/>
<richcontent TYPE="NOTE"><html><body>
<p>Aparece sozinho no topo quando h&#xe1; servi&#xe7;o pago nos &#xfa;ltimos</p>
<p>90 dias (CDC art. 26): &quot;coberto at&#xe9; 12/01, OS 2026-0007&quot;.</p>
<p>Se for retorno de garantia, marque o tipo de cobran&#xe7;a - o</p>
<p>or&#xe7;amento passa a ser dispensado e o PDF sai zerado.</p>
</body></html></richcontent>
<node TEXT="pago / garantia da oficina / garantia de f&#xe1;brica / cortesia"/>
</node>

<node TEXT="Km atual e queixa do cliente">
<node TEXT="A queixa nas palavras dele: &quot;barulho ao frear&quot;"/>
<node TEXT="&#xc9; o motivo real da visita, e sai no PDF"/>
</node>
</node>

<!-- ============================================================ -->
<!-- 3. A REVISAO                                                 -->
<!-- ============================================================ -->
<node TEXT="3. A revis&#xe3;o" POSITION="right" ID="ID_revisao" COLOR="#059669">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#059669" WIDTH="2"/>

<node TEXT="Percorrer o checklist">
<font BOLD="true"/>
<node TEXT="Cada item: OK / N-OK / N-A"/>
<node TEXT="Item com medi&#xe7;&#xe3;o: digitar o n&#xfa;mero">
<node TEXT="O sem&#xe1;foro pinta sozinho contra o limite de servi&#xe7;o"/>
<node TEXT="Com duas revis&#xf5;es, mostra o desgaste e a previs&#xe3;o de troca"/>
<node TEXT="V&#xed;rgula funciona: 2,8 e 2.8 d&#xe3;o no mesmo"/>
</node>
<node TEXT="Item com foto: antes e depois"/>
<node TEXT="Salva sozinho a cada toque (e offline tamb&#xe9;m)"/>
</node>

<node TEXT="Achou algo fora da lista">
<node TEXT="Adicionar item avulso, na mesma inspe&#xe7;&#xe3;o"/>
<node TEXT="Entra no PDF como ITENS ADICIONAIS"/>
</node>

<node TEXT="Registrar os torques aplicados">
<node TEXT="O app mostra a spec do modelo"/>
<node TEXT="Digite o que voc&#xea; realmente aplicou"/>
<node TEXT="Pinta na hora: ok / frouxo / apertado (toler&#xe2;ncia 10%)"/>
<node TEXT="Isso &#xe9; o que importa se a roda soltar depois"/>
</node>

<node TEXT="Pe&#xe7;as e m&#xe3;o de obra">
<font BOLD="true"/>
<icon BUILTIN="messagebox_warning"/>
<richcontent TYPE="NOTE"><html><body>
<p>CDC art. 40: or&#xe7;amento pr&#xe9;vio aprovado antes de executar.</p>
<p>O app trava a finaliza&#xe7;&#xe3;o sem a assinatura de aprova&#xe7;&#xe3;o,</p>
<p>que &#xe9; separada da assinatura de conclus&#xe3;o.</p>
<p>Servi&#xe7;o coberto por garantia pula esta trava.</p>
</body></html></richcontent>
<node TEXT="Lan&#xe7;ar pe&#xe7;as (cat&#xe1;logo ou descri&#xe7;&#xe3;o livre)"/>
<node TEXT="Lan&#xe7;ar horas de servi&#xe7;o"/>
<node TEXT="Mostrar o total ao cliente"/>
<node TEXT="Colher a assinatura de APROVA&#xc7;&#xc3;O (nome + assinatura)"/>
<node TEXT="S&#xf3; ent&#xe3;o executar o que foi or&#xe7;ado"/>
</node>

<node TEXT="Teste de rodagem">
<node TEXT="Anotar km inicial, dar a volta, anotar km final"/>
<node TEXT="Condi&#xe7;&#xe3;o da pista e quem rodou"/>
<node TEXT="14 itens: freios, motor, c&#xe2;mbio, suspens&#xe3;o, dire&#xe7;&#xe3;o, el&#xe9;trica, ru&#xed;dos"/>
<node TEXT="12 deles s&#xe3;o obrigat&#xf3;rios: n&#xe3;o encerra em branco">
<icon BUILTIN="messagebox_warning"/>
</node>
</node>
</node>

<!-- ============================================================ -->
<!-- 4. ENTREGA                                                   -->
<!-- ============================================================ -->
<node TEXT="4. Entrega" POSITION="right" ID="ID_entrega" COLOR="#7c3aed">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="button_ok"/>
<edge COLOR="#7c3aed" WIDTH="2"/>

<node TEXT="Responder a queixa">
<node TEXT="O que era e o que foi feito, em uma frase"/>
<node TEXT="&quot;Pastilha dianteira gasta (1,2mm), substitu&#xed;da&quot;"/>
</node>

<node TEXT="Conferir as recomenda&#xe7;&#xf5;es geradas">
<node TEXT="O app gera sozinho a partir das medi&#xe7;&#xf5;es no amarelo"/>
<node TEXT="urgente (abaixo do limite) ou planejar (perto dele)"/>
<node TEXT="Saem no PDF e viram motivo de retorno"/>
</node>

<node TEXT="Duas assinaturas">
<font BOLD="true"/>
<node TEXT="Mec&#xe2;nico"/>
<node TEXT="Cliente"/>
<node TEXT="Sem as duas, n&#xe3;o finaliza"><icon BUILTIN="messagebox_warning"/></node>
</node>

<node TEXT="Gerar e entregar o PDF">
<node TEXT="Compartilhar, baixar ou copiar o link"/>
<node TEXT="Tem hash de integridade"/>
<node TEXT="O n&#xfa;mero de OS (AAAA-NNNN) &#xe9; o que o cliente dita no telefone"/>
</node>

<node TEXT="Depois, quando o km chegar">
<node TEXT="lembretes.html lista quem est&#xe1; na hora"/>
<node TEXT="Manda por WhatsApp (wa.me, sem API paga)"/>
<node TEXT="Registra o envio: n&#xe3;o repete em 30 dias"/>
</node>
</node>

<!-- ============================================================ -->
<!-- TRAVAS                                                       -->
<!-- ============================================================ -->
<node TEXT="Onde o app vai te barrar" POSITION="left" ID="ID_travas" COLOR="#cc0000">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="stop-sign"/>
<edge COLOR="#cc0000" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p>Cinco travas de verdade no c&#xf3;digo. Quando uma delas aparecer,</p>
<p>n&#xe3;o &#xe9; bug: &#xe9; um passo anterior que ficou pela metade.</p>
</body></html></richcontent>

<node TEXT="Vistoria sem as 4 fotos ou sem assinatura">
<node TEXT="&quot;Faltam N foto(s) e a assinatura do cliente&quot;"/>
</node>
<node TEXT="Finalizar com item obrigat&#xf3;rio em branco">
<node TEXT="A conta muda com o tipo: r&#xe1;pida cobra s&#xf3; os itens do servi&#xe7;o"/>
</node>
<node TEXT="Finalizar sem or&#xe7;amento aprovado">
<node TEXT="A n&#xe3;o ser que seja garantia ou cortesia"/>
</node>
<node TEXT="Encerrar rodagem com obrigat&#xf3;rio pendente"/>
<node TEXT="Gerar PDF sem as duas assinaturas"/>
</node>

<!-- ============================================================ -->
<!-- OFFLINE                                                      -->
<!-- ============================================================ -->
<node TEXT="Sem sinal na garagem" POSITION="left" ID="ID_offline" COLOR="#64748b">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="broken-line"/>
<edge COLOR="#64748b" WIDTH="2"/>

<node TEXT="Pode trabalhar normalmente">
<node TEXT="Checklist, fotos e medi&#xe7;&#xf5;es ficam no aparelho"/>
<node TEXT="Sobem sozinhos quando o sinal voltar"/>
</node>
<node TEXT="O widget no canto inferior esquerdo diz o estado">
<node TEXT="Verde online, amarelo sincronizando, vermelho offline"/>
<node TEXT="Mostra quantas altera&#xe7;&#xf5;es est&#xe3;o na fila"/>
<node TEXT="Tocar nele for&#xe7;a a sincroniza&#xe7;&#xe3;o"/>
</node>
<node TEXT="N&#xc3;O saia da conta com a fila cheia">
<icon BUILTIN="messagebox_warning"/>
<node TEXT="O app pergunta antes, justamente por isso"/>
<node TEXT="O trabalho fica no aparelho, mas s&#xf3; sobe na MESMA conta"/>
</node>
</node>

<!-- ============================================================ -->
<!-- QUANDO MEXER NO CODIGO                                       -->
<!-- ============================================================ -->
<node TEXT="Quando mexer no c&#xf3;digo" POSITION="left" ID="ID_dev" COLOR="#475569">
<font BOLD="true" SIZE="13" ITALIC="true"/>
<icon BUILTIN="wizard"/>
<edge COLOR="#475569" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p>Outro fluxo, para outro chap&#xe9;u. A ordem importa: j&#xe1; custou</p>
<p>uma migration recusada e dois commits que pareciam perdidos.</p>
</body></html></richcontent>

<node TEXT="1. Rodar a su&#xed;te antes de qualquer coisa">
<node TEXT="cd /mnt/c/Users/mceza/Dropbox/PROJETOS/APLICATIVOS/JAVASCRIPT/APLICATIVOS/revisao-moto"/>
<node TEXT="./tests/run_tests.sh"/>
<node TEXT="Esperado: TODOS OS TESTES PASSARAM (Fase 0 -&gt; 10 + sessao)"/>
</node>
<node TEXT="2. Migrations em ordem, no SQL Editor do Supabase">
<node TEXT="cat sql/0NN_*.sql | clip.exe, colar no navegador"/>
<node TEXT="NO NAVEGADOR, n&#xe3;o no terminal do WSL"/>
<node TEXT="A 010 falha se a 009 n&#xe3;o entrou antes"/>
<node TEXT="O aviso de &quot;opera&#xe7;&#xe3;o destrutiva&quot; &#xe9; o DROP TRIGGER da idempot&#xea;ncia"/>
</node>
<node TEXT="3. Commit e push">
<node TEXT="Se der .git/index.lock: rm -f .git/index.lock e repetir"/>
<node TEXT="git status -sb tem que terminar em ## main...origin/main"/>
<node TEXT="Sem n&#xfa;mero ao lado: n&#xfa;mero significa que n&#xe3;o subiu"/>
</node>
<node TEXT="4. For&#xe7;ar a atualiza&#xe7;&#xe3;o no celular">
<node TEXT="Subir CACHE_VERSION no service-worker.js antes do push"/>
<node TEXT="Fechar e reabrir o app uma vez"/>
</node>
<node TEXT="Preven&#xe7;&#xe3;o: tirar o .git do Dropbox">
<icon BUILTIN="idea"/>
<richcontent TYPE="NOTE"><html><body>
<p>No PowerShell, uma vez s&#xf3;:</p>
<p>Set-Content -Path 'C:\Users\mceza\...\revisao-moto\.git'</p>
<p>&#160;&#160;-Stream com.dropbox.ignored -Value 1</p>
<p>O Dropbox para de mexer no .git e os locks somem. O</p>
<p>hist&#xf3;rico continua no GitHub, que &#xe9; o lugar dele.</p>
</body></html></richcontent>
</node>
</node>

<!-- ============================================================ -->
<!-- ENDERECOS E COMANDOS                                         -->
<!-- ============================================================ -->
<node TEXT="Endere&#xe7;os" POSITION="right" ID="ID_enderecos" COLOR="#0891b2">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="licq"/>
<edge COLOR="#0891b2" WIDTH="2"/>

<node TEXT="App publicado (&#xe9; este que o celular abre)">
<font BOLD="true"/>
<node TEXT="https://mariocezar1971.github.io/revisao-moto/"/>
<node TEXT="Atualiza ~1 min depois do git push"/>
</node>

<node TEXT="Reposit&#xf3;rio">
<node TEXT="https://github.com/mariocezar1971/revisao-moto"/>
<node TEXT="Pages: Settings &gt; Pages, branch main, pasta / (root)"/>
</node>

<node TEXT="Supabase (banco, Auth e Storage)">
<node TEXT="Painel: https://supabase.com/dashboard/project/jybfdknrxzlwpjyrayrb"/>
<node TEXT="API: https://jybfdknrxzlwpjyrayrb.supabase.co"/>
<node TEXT="SQL Editor: &#xe9; onde as migrations s&#xe3;o coladas"/>
<node TEXT="Regi&#xe3;o: S&#xe3;o Paulo"/>
</node>

<node TEXT="Projeto no disco">
<node TEXT="No WSL: /mnt/c/Users/mceza/Dropbox/PROJETOS/APLICATIVOS/JAVASCRIPT/APLICATIVOS/revisao-moto"/>
<node TEXT="No Windows: C:\Users\mceza\Dropbox\PROJETOS\APLICATIVOS\JAVASCRIPT\APLICATIVOS\revisao-moto"/>
</node>

<node TEXT="Atalhos de URL (servem para QR e favoritos)">
<node TEXT="inspecao.html?placa=ABC1234 - abre a inspe&#xe7;&#xe3;o j&#xe1; na moto"/>
<node TEXT="recebimento.html?placa=ABC1234 - vistoria de entrada"/>
<node TEXT="comparacao.html?placa=ABC1234 - compara revis&#xf5;es"/>
<node TEXT="especificacoes.html?modelo=3 - specs de um modelo"/>
<node TEXT="qrcode.html?placa=ABC1234 - gera o QR para colar na moto"/>
</node>
</node>

<node TEXT="Comandos" POSITION="right" ID="ID_comandos" COLOR="#334155">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#334155" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p>Todos a partir do WSL, j&#xe1; dentro da pasta do projeto.</p>
<p>Para entrar no WSL a partir do PowerShell: wsl</p>
</body></html></richcontent>

<node TEXT="Ir para o projeto">
<node TEXT="cd /mnt/c/Users/mceza/Dropbox/PROJETOS/APLICATIVOS/JAVASCRIPT/APLICATIVOS/revisao-moto"/>
<node TEXT="Vale um alias no ~/.bashrc:"/>
<node TEXT="alias moto='cd /mnt/c/Users/mceza/Dropbox/PROJETOS/APLICATIVOS/JAVASCRIPT/APLICATIVOS/revisao-moto'"/>
</node>

<node TEXT="Rodar localmente">
<font BOLD="true"/>
<icon BUILTIN="messagebox_warning"/>
<richcontent TYPE="NOTE"><html><body>
<p>Precisa ser por http://, n&#xe3;o abrindo o arquivo direto: o</p>
<p>service worker e o manifest n&#xe3;o funcionam em file://.</p>
<p>&#160;</p>
<p>ATEN&#xc7;&#xc3;O: rodando local, o app continua apontando para o</p>
<p>Supabase de PRODU&#xc7;&#xc3;O. O que voc&#xea; salvar na c&#xf3;pia local vai</p>
<p>para o banco de verdade. Use placa fict&#xed;cia (TESTE01) e</p>
<p>apague depois.</p>
</body></html></richcontent>
<node TEXT="python3 -m http.server 8000"/>
<node TEXT="Abrir http://localhost:8000 no navegador do Windows"/>
<node TEXT="Ctrl+C encerra"/>
<node TEXT="Se a porta estiver ocupada: python3 -m http.server 8001"/>
</node>

<node TEXT="Rodar os testes">
<node TEXT="./tests/run_tests.sh - tudo (Fase 0 a 10 + sessao)"/>
<node TEXT="python3 tests/test_fase10.py - uma fase s&#xf3; (precisa do banco de pe)"/>
<node TEXT="python3 tests/test_sessao.py - s&#xf3; est&#xe1;tico, n&#xe3;o precisa de banco"/>
<node TEXT="./orquestrador_fase10.sh --help - o que o orquestrador faz"/>
<node TEXT="./orquestrador_fase10.sh --all - fase 10 + su&#xed;te inteira"/>
</node>

<node TEXT="Migrations no Supabase">
<font BOLD="true"/>
<node TEXT="ls sql/*.sql - ver todas, em ordem"/>
<node TEXT="1. Copiar: cat sql/010_fase10_p3.sql | clip.exe">
<node TEXT="S&#xf3; copia para a &#xe1;rea de transfer&#xea;ncia do Windows; n&#xe3;o executa nada"/>
</node>
<node TEXT="2. Abrir o SQL Editor">
<node TEXT="supabase.com/dashboard/project/jybfdknrxzlwpjyrayrb"/>
<node TEXT="Menu da esquerda &gt; SQL Editor &gt; New query"/>
</node>
<node TEXT="3. Ctrl+V e Run (ou Ctrl+Enter)"/>
<node TEXT="4. O aviso &quot;Potential issue detected&quot; &#xe9; esperado">
<richcontent TYPE="NOTE"><html><body>
<p>Dispara por causa do DROP TRIGGER IF EXISTS que existe s&#xf3;</p>
<p>para a migration poder ser reaplicada, e dos CREATE OR</p>
<p>REPLACE. Nenhuma migration do projeto tem DELETE, TRUNCATE,</p>
<p>DROP TABLE ou DROP COLUMN. Pode clicar em Run query.</p>
</body></html></richcontent>
</node>
<node TEXT="5. Deu certo: &quot;Success. No rows returned&quot;">
<node TEXT="Deu erro: a transa&#xe7;&#xe3;o inteira &#xe9; desfeita, nada fica pela metade"/>
<node TEXT="A mensagem diz a linha; erro de coluna inexistente costuma ser migration anterior faltando"/>
</node>
<node TEXT="S&#xe3;o idempotentes: rodar de novo n&#xe3;o estraga nada"/>
</node>

<node TEXT="Conferir que a migration entrou">
<font BOLD="true"/>
<icon BUILTIN="help"/>
<richcontent TYPE="NOTE"><html><body>
<p>Tr&#xea;s jeitos, do mais r&#xe1;pido ao mais visual. O primeiro</p>
<p>responde tudo de uma vez e &#xe9; o que vale guardar.</p>
</body></html></richcontent>

<node TEXT="A. Query de confer&#xea;ncia (cola no mesmo SQL Editor)">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Lista os nomes, n&#xe3;o s&#xf3; a contagem: se faltar alguma coisa</p>
<p>voc&#xea; v&#xea; o QUE faltou, n&#xe3;o s&#xf3; que o n&#xfa;mero deu diferente.</p>
<p>&#160;</p>
<p>Esperado para a Fase 10: 5 tabelas, 5 views, 9 fun&#xe7;&#xf5;es,</p>
<p>6 colunas novas em inspecoes.</p>
<p>&#160;</p>
<p>SELECT 'tabelas' AS objeto,</p>
<p>&#160;&#160;string_agg(table_name, ', ' ORDER BY table_name) AS encontrados,</p>
<p>&#160;&#160;count(*) AS qtd</p>
<p>FROM information_schema.tables</p>
<p>WHERE table_schema='public' AND table_name IN</p>
<p>&#160;&#160;('rodagem_itens','inspecao_rodagem','inspecao_rodagem_itens',</p>
<p>&#160;&#160;&#160;'inspecao_torques','servicos_rapidos')</p>
<p>UNION ALL</p>
<p>SELECT 'views', string_agg(table_name, ', ' ORDER BY table_name), count(*)</p>
<p>FROM information_schema.views</p>
<p>WHERE table_schema='public' AND table_name IN</p>
<p>&#160;&#160;('vw_inspecoes_comparaveis','vw_rodagem','vw_garantias_vigentes',</p>
<p>&#160;&#160;&#160;'vw_torques_inspecao','vw_servicos_rapidos')</p>
<p>UNION ALL</p>
<p>SELECT 'funcoes', string_agg(proname, ', ' ORDER BY proname), count(*)</p>
<p>FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace</p>
<p>WHERE n.nspname='public' AND proname IN</p>
<p>&#160;&#160;('comparar_inspecoes','historico_medicao','rodagem_completa',</p>
<p>&#160;&#160;&#160;'garantia_vigente','torques_do_modelo','avaliar_torque',</p>
<p>&#160;&#160;&#160;'itens_do_servico_rapido','pode_finalizar_por_tipo',</p>
<p>&#160;&#160;&#160;'trigger_definir_garantia')</p>
<p>UNION ALL</p>
<p>SELECT 'colunas novas', string_agg(column_name, ', ' ORDER BY column_name), count(*)</p>
<p>FROM information_schema.columns</p>
<p>WHERE table_name='inspecoes' AND column_name IN</p>
<p>&#160;&#160;('tipo_cobranca','garantia_ate','garantia_obs','inspecao_origem',</p>
<p>&#160;&#160;&#160;'tipo_execucao','servico_rapido_id');</p>
</body></html></richcontent>
</node>

<node TEXT="B. Testar que funciona, n&#xe3;o s&#xf3; que existe">
<font BOLD="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Objeto criado n&#xe3;o &#xe9; objeto correto. Estas quatro linhas</p>
<p>exercitam a regra de torque de verdade e t&#xea;m que devolver,</p>
<p>em ordem: frouxo, ok, apertado, sem_spec.</p>
<p>&#160;</p>
<p>SELECT (SELECT situacao FROM avaliar_torque(80,60,10))  AS t60,</p>
<p>&#160;&#160;&#160;&#160;&#160;&#160;(SELECT situacao FROM avaliar_torque(80,80,10))  AS t80,</p>
<p>&#160;&#160;&#160;&#160;&#160;&#160;(SELECT situacao FROM avaliar_torque(80,95,10))  AS t95,</p>
<p>&#160;&#160;&#160;&#160;&#160;&#160;(SELECT situacao FROM avaliar_torque(NULL,50,10)) AS sem_spec,</p>
<p>&#160;&#160;&#160;&#160;&#160;&#160;(SELECT count(*) FROM rodagem_itens)    AS seed_rodagem,</p>
<p>&#160;&#160;&#160;&#160;&#160;&#160;(SELECT count(*) FROM servicos_rapidos) AS seed_servicos;</p>
<p>&#160;</p>
<p>Os seeds t&#xea;m que dar 14 e 6.</p>
</body></html></richcontent>
</node>

<node TEXT="C. Olhar na interface, sem escrever SQL">
<node TEXT="Table Editor: as 5 tabelas novas aparecem na lista da esquerda"/>
<node TEXT="Database &gt; Functions: as 9 fun&#xe7;&#xf5;es"/>
<node TEXT="Database &gt; Triggers: set_garantia_ao_finalizar"/>
<node TEXT="Table Editor &gt; inspecoes: as 6 colunas novas no fim"/>
</node>

<node TEXT="Se faltar alguma coisa">
<node TEXT="Rodar a migration de novo: &#xe9; idempotente"/>
<node TEXT="Faltando tudo: provavelmente a migration anterior n&#xe3;o entrou"/>
<node TEXT="A 010 depende da 009 (numero_os); a 009 depende da 008"/>
</node>
</node>

<node TEXT="Git do dia a dia">
<node TEXT="git status -sb - tem que terminar em ## main...origin/main"/>
<node TEXT="git add -A &amp;&amp; git commit -m &quot;...&quot; &amp;&amp; git push"/>
<node TEXT="git log --oneline -5 - &#xfa;ltimos commits"/>
<node TEXT="git log origin/main..main --oneline - o que ainda n&#xe3;o subiu"/>
<node TEXT="rm -f .git/index.lock - quando o Dropbox trava o git"/>
<node TEXT="git fetch origin - resincroniza o ponteiro depois do lock"/>
</node>

<node TEXT="Publicar uma mudan&#xe7;a de c&#xf3;digo">
<node TEXT="1. Subir CACHE_VERSION no service-worker.js"/>
<node TEXT="2. ./tests/run_tests.sh"/>
<node TEXT="3. git add -A &amp;&amp; git commit -m &quot;...&quot; &amp;&amp; git push"/>
<node TEXT="4. Esperar 1 min, fechar e reabrir o app no celular"/>
</node>

<node TEXT="Conferir o que est&#xe1; publicado">
<node TEXT="grep -n CACHE_VERSION service-worker.js - vers&#xe3;o local"/>
<node TEXT="No celular: fechar o app e abrir de novo pega a nova"/>
<node TEXT="Se teimar: limpar dados do site no navegador"/>
</node>

<node TEXT="Limpar dados de teste do banco">
<icon BUILTIN="messagebox_warning"/>
<node TEXT="No SQL Editor, com placa fict&#xed;cia:"/>
<node TEXT="DELETE FROM inspecoes WHERE moto_id = (SELECT id FROM motos WHERE placa='TESTE01');"/>
<node TEXT="DELETE FROM motos WHERE placa='TESTE01';"/>
<node TEXT="O CASCADE leva itens, torques, rodagem, recomenda&#xe7;&#xf5;es e recebimentos"/>
</node>
</node>

<!-- ============================================================ -->
<!-- PRIMEIRA REVISAO REAL                                        -->
<!-- ============================================================ -->
<node TEXT="A primeira revis&#xe3;o de verdade" POSITION="left" ID="ID_primeira" COLOR="#dc2626">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="bookmark"/>
<icon BUILTIN="help"/>
<edge COLOR="#dc2626" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p>O pr&#xe9;-requisito que o roadmap pede desde agosto e que ainda</p>
<p>n&#xe3;o foi cumprido. At&#xe9; hoje o banco tem UMA inspe&#xe7;&#xe3;o, cancelada,</p>
<p>com zero itens salvos.</p>
<p>&#160;</p>
<p>As duas falhas que realmente impediam o uso - o checklist que</p>
<p>n&#xe3;o gravava e o bot&#xe3;o de sair coberto por um widget - passaram</p>
<p>por 1.191 testes verdes sem serem vistas. Nenhuma su&#xed;te pega</p>
<p>&quot;o bot&#xe3;o est&#xe1; l&#xe1;, mas ningu&#xe9;m consegue clicar&quot;.</p>
</body></html></richcontent>

<node TEXT="Teste zero, antes de tudo">
<font BOLD="true"/>
<node TEXT="Abrir uma inspe&#xe7;&#xe3;o, marcar OK num item, recarregar a p&#xe1;gina"/>
<node TEXT="A marca&#xe7;&#xe3;o tem que continuar l&#xe1;"/>
</node>

<node TEXT="Rodar uma revis&#xe3;o inteira na sua Shotgun"/>

<node TEXT="Anotar tr&#xea;s categorias, durante o uso">
<font BOLD="true"/>
<node TEXT="O que atrapalha (ex: ter que girar o celular)"/>
<node TEXT="O que falta (ex: onde anotar n&#xfa;mero de s&#xe9;rie)"/>
<node TEXT="O que j&#xe1; sei que vou precisar (ex: meu compadre quer usar)"/>
</node>

<node TEXT="S&#xf3; depois decidir o P4">
<node TEXT="Agendamento, estoque, multi-tenancy, VIN, API, nota fiscal"/>
<node TEXT="Pelo que o campo mostrar, n&#xe3;o pelo que parece bom no papel"/>
</node>
</node>

</node>
</map>
