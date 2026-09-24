<map version="freeplane 1.11.0">
<!--To view this file, download free mind mapping software Freeplane from https://www.freeplane.org -->
<node TEXT="Fase 8 (P1)&#xa;Opera&#xe7;&#xe3;o Real" FOLDED="false" ID="ID_root" STYLE="oval">
<font SIZE="18" BOLD="true"/>
<edge COLOR="#cc0000" WIDTH="thin"/>
<richcontent TYPE="NOTE"><html><body>
<p>Os 4 itens criticos do Roadmap-Fase8: medicao numerica, queixa do cliente,</p>
<p>itens avulsos e orcamento com aprovacao previa.</p>
<p>Transformam o app de checklist em ferramenta de oficina.</p>
<p>Resultado: 145/145 testes. Total do projeto: 778.</p>
</body></html></richcontent>

<!-- =========================================================== -->
<!-- PASSOS                                                       -->
<!-- =========================================================== -->
<node TEXT="Passos" POSITION="right" ID="ID_passos" COLOR="#0066cc">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="list"/>
<edge COLOR="#0066cc" WIDTH="2"/>

<!-- 1. MEDICAO -->
<node TEXT="1. Medicao numerica com limites" ID="ID_p1" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="gohome"/>
<richcontent TYPE="NOTE"><html><body>
<p>Antes: valor_medido era TEXT livre. O mecanico digitava "2,3mm" ou "2.3"</p>
<p>e o banco aceitava tudo, sem saber o que significava.</p>
<p>Agora: o app compara com os limites e pinta o campo na hora.</p>
</body></html></richcontent>

<node TEXT="Schema: colunas novas">
<node TEXT="itens_checklist: unidade, limite_minimo, limite_maximo, alerta_em">
<font ITALIC="true"/>
</node>
<node TEXT="itens_checklist: chave_medicao">
<font ITALIC="true"/>
<icon BUILTIN="idea"/>
<richcontent TYPE="NOTE"><html><body>
<p><b>Nao estava no plano - apareceu testando.</b></p>
<p>A descricao do MESMO item fisico muda entre revisoes:</p>
<p>"Inspecao de pastilhas dianteiras" (500 km) vira</p>
<p>"Pastilhas dianteiras - espessura" (5000 km+).</p>
<p>Casar por texto quebraria o desgaste no caso de uso principal.</p>
<p>8 chaves cobrem 400 itens: pastilha_dianteira, pastilha_traseira,</p>
<p>corrente_folga, vela_folga, embreagem_folga, bateria_tensao,</p>
<p>alternador_tensao, pneu_pressao.</p>
</body></html></richcontent>
</node>
<node TEXT="inspecoes_itens: valor_numerico NUMERIC">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Paralelo ao valor_medido TEXT, que continua existindo.</p>
</body></html></richcontent>
</node>
<node TEXT="vw_checklist_completo recriada">
<font ITALIC="true"/>
<icon BUILTIN="messagebox_warning"/>
<richcontent TYPE="NOTE"><html><body>
<p><b>Tambem apareceu testando.</b> O front carrega os itens por essa view.</p>
<p>Sem expor unidade/limites/chave, o semaforo chegaria sem nada</p>
<p>contra o que comparar.</p>
</body></html></richcontent>
</node>
</node>

<node TEXT="Semaforo automatico">
<richcontent TYPE="NOTE"><html><body>
<p>SQL: funcao avaliar_medicao(item_id, valor)</p>
<p>JS: medicoes.avaliarLocal() faz o mesmo calculo no cliente,</p>
<p>para pintar o campo enquanto o mecanico digita (sem ida ao servidor).</p>
<p></p>
<p>verde = dentro da especificacao</p>
<p>amarelo = abaixo de alerta_em, planejar troca</p>
<p>vermelho = abaixo de limite_minimo ou acima de limite_maximo</p>
<p>sem_limite = item sem limite cadastrado</p>
</body></html></richcontent>
</node>

<node TEXT="Calculo de taxa de desgaste">
<icon BUILTIN="idea"/>
<richcontent TYPE="NOTE"><html><body>
<p>Funcao taxa_desgaste(moto_id, chave_medicao).</p>
<p>Validado no teste com pastilha 4,0mm@5000km -&gt; 2,8mm@10000km:</p>
<p></p>
<p>desgaste = (4,0 - 2,8) x 1000 / 5000 = 0,24 mm/1000km</p>
<p>restante = (2,8 - 1,5) x 1000 / 0,24 = 5.417 km</p>
<p>troca em = 10.000 + 5.417 = 15.417 km</p>
<p></p>
<p>Aparece como linha azul abaixo do campo, a partir da 2a medicao.</p>
<p>Tambem alimenta a view vw_recomendacoes_futuras.</p>
</body></html></richcontent>
</node>

<node TEXT="Seed: limites nos 1300 itens">
<richcontent TYPE="NOTE"><html><body>
<p>Regex extrai os limites dos valor_referencia textuais ja existentes.</p>
<p>5 padroes cobertos:</p>
<p>A) faixa "20-30 mm" -&gt; min 20, max 30</p>
<p>B) "minima 1,5 mm" / "Minimo 1,5 mm" -&gt; min 1.5, alerta 2.03</p>
<p>C) "&gt; 12,4 V" -&gt; min 12.4</p>
<p>D) "13,5-14,5 V" -&gt; min 13.5, max 14.5</p>
<p>E) psi -&gt; min 28, max 40</p>
<p></p>
<p>Resultado: 400 dos 1300 itens ganharam limite. Zero inconsistencias.</p>
<p>Os outros 900 sao verificacoes visuais, sem medicao.</p>
</body></html></richcontent>
</node>
</node>

<!-- 2. QUEIXA -->
<node TEXT="2. Queixa do cliente + resolucao" ID="ID_p2" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="messagebox_warning"/>
<richcontent TYPE="NOTE"><html><body>
<p>O cliente chega dizendo "ta fazendo um barulho quando freio".</p>
<p>Isso nao esta em checklist nenhum - eh a razao pela qual ele veio.</p>
<p>O menor custo e o maior valor pratico dos 4 itens.</p>
</body></html></richcontent>
<node TEXT="inspecoes.queixa_cliente TEXT (na abertura)">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Textarea na tela de selecao, antes de iniciar a inspecao.</p>
</body></html></richcontent>
</node>
<node TEXT="inspecoes.resolucao_queixa TEXT (no fim)">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Na tela de finalizacao, o bloco amarelo mostra a queixa original</p>
<p>e pede o que foi encontrado e feito.</p>
</body></html></richcontent>
</node>
<node TEXT="Nova secao no PDF, antes do checklist">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Bloco de fundo amarelo, em posicao de destaque.</p>
<p>Eh a primeira coisa que o cliente le no relatorio.</p>
</body></html></richcontent>
</node>
</node>

<!-- 3. AVULSOS -->
<node TEXT="3. Itens avulsos fora do checklist" ID="ID_p3" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="addition"/>
<richcontent TYPE="NOTE"><html><body>
<p>O checklist eh fixo por revisao (14 a 24 itens). Mas o mecanico</p>
<p>sempre acha algo fora da lista e nao tinha onde registrar.</p>
</body></html></richcontent>
<node TEXT="Botao '+ Adicionar item' na tela de execucao">
<font ITALIC="true"/>
</node>
<node TEXT="inspecoes_itens.item_id vira nullable">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>A UNIQUE(inspecao_id, item_id) original ja permite varios NULL</p>
<p>em Postgres, entao multiplos avulsos convivem sem conflito.</p>
</body></html></richcontent>
</node>
<node TEXT="inspecoes_itens.descricao_avulsa TEXT">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Constraint chk_item_ou_avulso garante que ou eh item do catalogo,</p>
<p>ou eh avulso COM descricao. Nao permite linha vazia.</p>
</body></html></richcontent>
</node>
<node TEXT="Aparece no PDF em secao 'Itens adicionais'">
<font ITALIC="true"/>
</node>
<node TEXT="View vw_inspecao_itens_completo">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Unifica catalogo + avulsos numa lista so, ja com o semaforo</p>
<p>calculado e a flag eh_avulso.</p>
</body></html></richcontent>
</node>
</node>

<!-- 4. ORCAMENTO -->
<node TEXT="4. Pecas e orcamento" ID="ID_p4" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="wizard"/>
<richcontent TYPE="NOTE"><html><body>
<p>Quando um item da "Nao OK", o proximo passo eh: qual peca resolve,</p>
<p>quanto custa, quantas horas. Sem isso o checklist terminava num</p>
<p>beco sem saida e o orcamento era refeito em papel separado.</p>
</body></html></richcontent>
<node TEXT="Tabela pecas (catalogo com preco de referencia)">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>id, codigo_re, descricao, preco_unitario, modelo_id (NULL = serve a todos).</p>
<p>Seed com 10 consumiveis comuns Royal Enfield.</p>
</body></html></richcontent>
</node>
<node TEXT="Tabela inspecao_pecas">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>O preco eh COPIADO para preco_aplicado, nao referenciado.</p>
<p>Assim o orcamento de uma inspecao antiga nao muda se o catalogo</p>
<p>for reajustado depois.</p>
<p>Aceita peca fora do catalogo via descricao_livre.</p>
</body></html></richcontent>
</node>
<node TEXT="Tabela inspecao_servicos (mao de obra)">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>descricao, horas, valor_hora. Padrao R$ 120/h.</p>
</body></html></richcontent>
</node>
<node TEXT="Secao 'Orcamento' no PDF com total">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Pecas e mao de obra em blocos separados, com subtotal por linha</p>
<p>e total geral destacado. View vw_orcamento_inspecao consolida.</p>
</body></html></richcontent>
</node>
<node TEXT="Assinatura de aprovacao previa">
<font ITALIC="true"/>
<icon BUILTIN="password"/>
<richcontent TYPE="NOTE"><html><body>
<p><b>CDC art. 40:</b> o fornecedor deve entregar orcamento previo e o</p>
<p>servico so pode ser executado apos autorizacao expressa do consumidor.</p>
<p></p>
<p>Assinatura SEPARADA da de conclusao:</p>
<p>- a de aprovacao autoriza EXECUTAR</p>
<p>- a de conclusao atesta que FOI FEITO</p>
<p></p>
<p>A finalizacao fica bloqueada se houver orcamento com valor sem</p>
<p>aprovacao. Assinatura com menos de 100 caracteres nao conta</p>
<p>(evita rabisco acidental).</p>
</body></html></richcontent>
</node>
</node>

</node>

<!-- =========================================================== -->
<!-- ORQUESTRADOR                                                 -->
<!-- =========================================================== -->
<node TEXT="Orquestrador" POSITION="left" ID="ID_orq" COLOR="#cc0000">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#cc0000" WIDTH="2"/>

<node TEXT="./orquestrador_fase8.sh" ID="ID_o1" COLOR="#cc0000">
<font BOLD="true" ITALIC="true" SIZE="12"/>
<icon BUILTIN="executable"/>
<richcontent TYPE="NOTE"><html><body>
<p>Roda so a Fase 8. ~15s (sobe Postgres efemero na porta 5441).</p>
<p>Valida: 5 arquivos, sintaxe de 5 modulos JS + 4 blocos inline do</p>
<p>inspecao.html, 9 pontos de integracao na UI, 4 no PDF, versao do SW.</p>
<p>Esperado: 145/145 OK.</p>
<p></p>
<p>Modos: padrao / --all (0-8, 778 testes) / --skip-tests / --project-dir</p>
</body></html></richcontent>
</node>

<node TEXT="Aplicar no Supabase" ID="ID_o2" COLOR="#cc0000">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="launch"/>
<node TEXT="SQL Editor &gt; cole sql/008_fase8_p1.sql &gt; Run">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Cria: 5 colunas em itens_checklist, 3 em inspecoes_itens,</p>
<p>5 em inspecoes, 3 tabelas novas, 2 funcoes, 3 views.</p>
<p>Faz o seed de limites em ~400 itens por regex.</p>
<p>Idempotente: pode rodar de novo sem erro.</p>
</body></html></richcontent>
</node>
<node TEXT="git add . &amp;&amp; git commit -m 'Fase 8 P1' &amp;&amp; git push">
<font ITALIC="true"/>
</node>
<node TEXT="Limpar SW no celular (v0.7.1 -&gt; v0.8.0)">
<font ITALIC="true"/>
<icon BUILTIN="messagebox_warning"/>
<richcontent TYPE="NOTE"><html><body>
<p>DevTools &gt; Application &gt; Service Workers &gt; Unregister</p>
<p>Depois Storage &gt; Clear site data &gt; Ctrl+Shift+R</p>
</body></html></richcontent>
</node>
</node>

<node TEXT="Roteiro de teste em campo" ID="ID_o3" COLOR="#cc0000">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="bookmark"/>
<richcontent TYPE="NOTE"><html><body>
<p>O que os 145 testes NAO conseguem verificar.</p>
</body></html></richcontent>
<node TEXT="Preencher o relato do cliente antes de iniciar"/>
<node TEXT="Digitar medicao num item de pastilha/corrente/bateria">
<richcontent TYPE="NOTE"><html><body>
<p>O campo deve pintar verde/amarelo/vermelho na hora,</p>
<p>com a referencia ("min 1.5 mm - alerta em 2.03 mm") ao lado.</p>
</body></html></richcontent>
</node>
<node TEXT="Adicionar um item fora do checklist"/>
<node TEXT="Lancar uma peca e uma mao de obra"/>
<node TEXT="Tentar finalizar: deve BLOQUEAR pedindo aprovacao">
<icon BUILTIN="password"/>
</node>
<node TEXT="Coletar assinatura de aprovacao e finalizar"/>
<node TEXT="Conferir as 3 secoes novas no PDF"/>
<node TEXT="2a revisao da MESMA moto: ver a previsao de troca">
<icon BUILTIN="idea"/>
<richcontent TYPE="NOTE"><html><body>
<p>A taxa de desgaste so aparece a partir da SEGUNDA medicao</p>
<p>do mesmo item na mesma moto. Na primeira inspecao nao ha</p>
<p>com o que comparar - isso eh esperado, nao bug.</p>
</body></html></richcontent>
</node>
</node>

</node>

<!-- =========================================================== -->
<!-- ESTADO                                                       -->
<!-- =========================================================== -->
<node TEXT="Estado apos a Fase 8" POSITION="left" ID="ID_estado" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>
<edge COLOR="#666666" STYLE="bezier"/>
<node TEXT="778 testes automatizados (100%)"><icon BUILTIN="button_ok"/></node>
<node TEXT="9 fases (0 a 8)"/>
<node TEXT="5 orquestradores (0, 5, 6, 7, 8)"/>
<node TEXT="Service Worker v0.8.0"/>
<node TEXT="Ainda no roadmap: P2, P3, P4">
<richcontent TYPE="NOTE"><html><body>
<p>Ver Roadmap-Fase8.mm.</p>
<p>P2: recebimento/avarias, recomendacoes futuras, fotos antes/depois,</p>
<p>lembrete ao cliente, numero de OS.</p>
<p>P3 e P4 so depois de uso real.</p>
</body></html></richcontent>
</node>
<node TEXT="O teste que falta eh usar numa moto de verdade">
<icon BUILTIN="stop-sign"/>
<richcontent TYPE="NOTE"><html><body>
<p>Os 4 itens vieram de analise de fluxo de oficina, nao de uso real.</p>
<p>Uma revisao completa numa Royal Enfield vale mais que os 145 testes</p>
<p>para decidir o que vem depois.</p>
</body></html></richcontent>
</node>
</node>

</node>
</map>
