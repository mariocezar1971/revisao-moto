<map version="freeplane 1.11.0">
<!--To view this file, download free mind mapping software Freeplane from https://www.freeplane.org -->
<node TEXT="Fase 9 (P2)&#xa;Alta prioridade" FOLDED="false" ID="ID_root" STYLE="oval">
<font SIZE="18" BOLD="true"/>
<edge COLOR="#ff8c00" WIDTH="thin"/>
<richcontent TYPE="NOTE"><html><body>
<p>Os 5 itens P2 do Roadmap-Fase8: recebimento, recomendacoes,</p>
<p>fotos antes/depois, lembretes ao cliente e numero de OS.</p>
<p>Fecham o ciclo da oficina: a moto chega, eh vistoriada, revisada,</p>
<p>entregue e o cliente eh chamado de volta.</p>
<p>Resultado: 136/136 testes. Total do projeto: 914.</p>
</body></html></richcontent>

<!-- =========================================================== -->
<!-- PASSOS                                                       -->
<!-- =========================================================== -->
<node TEXT="Passos" POSITION="right" ID="ID_passos" COLOR="#0066cc">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="list"/>
<edge COLOR="#0066cc" WIDTH="2"/>

<!-- 5. RECEBIMENTO -->
<node TEXT="5. Checklist de recebimento (avarias)" ID="ID_p5" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="attach"/>
<richcontent TYPE="NOTE"><html><body>
<p>Tabela recebimentos + pagina recebimento.html.</p>
<p>Protege de "minha moto nao tinha esse risco no tanque".</p>
<p>Acontece ANTES da inspecao: a moto chega, eh vistoriada e</p>
<p>so depois o servico comeca.</p>
<p></p>
<p>Funcao recebimento_completo() valida 4 fotos + assinatura.</p>
<p>Retoma vistoria interrompida (recebimentoAbertoDaMoto).</p>
</body></html></richcontent>
<node TEXT="4 fotos obrigatorias (frente, tras, lado esq, lado dir)">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Grade 2x2 com borda verde quando a foto existe.</p>
<p>Contador "N de 4" muda de ambar para verde ao completar.</p>
<p>Conclusao bloqueada enquanto faltar foto.</p>
</body></html></richcontent>
</node>
<node TEXT="Inventario de avarias (texto livre + marcacao)">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>avarias_texto TEXT para a descricao corrida.</p>
<p>avarias_marcacoes JSONB para pontos: [{x,y,lado,nota}].</p>
<p>x e y sao relativos (0 a 1) para funcionar em qualquer tela.</p>
</body></html></richcontent>
</node>
<node TEXT="Nivel de combustivel">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>0=vazio 1=1/4 2=1/2 3=3/4 4=cheio, com CHECK no banco.</p>
<p>A view traduz para texto ('1/2') no PDF.</p>
</body></html></richcontent>
</node>
<node TEXT="Acessorios presentes (bau, capacete, documentos)">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Tres booleanos + campo livre para outros.</p>
<p>Saem listados no PDF.</p>
</body></html></richcontent>
</node>
<node TEXT="Assinatura do cliente na entrada">
<font ITALIC="true"/>
<icon BUILTIN="password"/>
<richcontent TYPE="NOTE"><html><body>
<p>Terceira assinatura do sistema, distinta das outras duas:</p>
<p>- entrada: o cliente confirma o ESTADO em que entregou</p>
<p>- orcamento (Fase 8): autoriza EXECUTAR</p>
<p>- conclusao (Fase 4): atesta que FOI FEITO</p>
<p>Assinatura com menos de 100 caracteres nao conta.</p>
</body></html></richcontent>
</node>
</node>

<!-- 6. RECOMENDACOES -->
<node TEXT="6. Recomendacoes futuras" ID="ID_p6" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="forward"/>
<richcontent TYPE="NOTE"><html><body>
<p>A view vw_recomendacoes_futuras ja existia (Fase 8), mas era</p>
<p>so consulta ao vivo. Agora a tabela recomendacoes CONGELA o que</p>
<p>foi recomendado naquela inspecao.</p>
<p></p>
<p>Por que congelar: a view recalcula com os dados de hoje. O PDF</p>
<p>entregue ao cliente precisa mostrar o que foi dito NAQUELE dia,</p>
<p>mesmo que a moto rode mais 5.000 km depois.</p>
<p></p>
<p>gerar_recomendacoes(inspecao_id) roda ao finalizar:</p>
<p>- item abaixo do limite -&gt; prioridade 'urgente'</p>
<p>- item na faixa de alerta -&gt; prioridade 'planejar'</p>
<p>- busca a previsao de km em taxa_desgaste()</p>
<p>Idempotente: regerar apaga e refaz, nao duplica.</p>
</body></html></richcontent>
</node>

<!-- 7. FOTOS -->
<node TEXT="7. Fotos antes/depois" ID="ID_p7" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="image"/>
<richcontent TYPE="NOTE"><html><body>
<p>Colunas foto_antes_url e foto_depois_url em inspecoes_itens.</p>
<p>foto_url continua existindo e a migration copia o conteudo dela</p>
<p>para foto_antes_url - nenhuma foto antiga se perde.</p>
<p></p>
<p>Na UI: dois botoes lado a lado no lugar do botao unico.</p>
<p>Cada um fica verde quando a foto correspondente existe.</p>
<p>O path no Storage ganha sufixo -antes / -depois.</p>
</body></html></richcontent>
</node>

<!-- 8. LEMBRETES -->
<node TEXT="8. Lembrete automatico ao CLIENTE" ID="ID_p8" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="phone_mobile"/>
<richcontent TYPE="NOTE"><html><body>
<p>As notificacoes da Fase 7 avisam o MECANICO. Estas avisam o CLIENTE.</p>
<p></p>
<p>Escolha de projeto: link wa.me em vez da API do WhatsApp Business.</p>
<p>A API custa por mensagem e exige aprovacao de template; o link abre</p>
<p>o app com o texto pronto e o mecanico so aperta enviar.</p>
<p>Custo: um toque a mais. Ganho: zero mensalidade, zero burocracia.</p>
<p></p>
<p>4 templates: revisao_proxima, revisao_atrasada, recomendacao, pronta.</p>
<p>normalizarTelefone() aceita "(27) 99988-7766", "27999887766",</p>
<p>"+55 27 99988-7766" e devolve o formato do wa.me.</p>
<p></p>
<p>vw_lembretes_pendentes: motos proxima/atrasada, COM telefone,</p>
<p>que nao receberam lembrete nos ultimos 30 dias.</p>
<p>Badge no dashboard mostra quantas aguardam.</p>
</body></html></richcontent>
</node>

<!-- 9. OS -->
<node TEXT="9. Numero de OS (ordem de servico)" ID="ID_p9" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="licq"/>
<richcontent TYPE="NOTE"><html><body>
<p>Antes a inspecao so tinha UUID, que ninguem consegue ditar</p>
<p>no telefone. Agora: 2026-0001, 2026-0002...</p>
<p></p>
<p>Trigger BEFORE INSERT gera automaticamente. Numero informado</p>
<p>explicitamente eh respeitado (nao sobrescreve).</p>
<p></p>
<p>proximo_numero_os() usa INSERT ... ON CONFLICT DO UPDATE</p>
<p>RETURNING: incrementa e devolve numa operacao so, sem risco</p>
<p>de dois inserts simultaneos pegarem o mesmo numero.</p>
<p></p>
<p>Backfill: as inspecoes que ja existiam recebem numero em</p>
<p>ordem cronologica. Indice unico garante que nao repete.</p>
<p>Aparece no cabecalho do PDF no lugar do UUID truncado.</p>
</body></html></richcontent>
</node>

</node>

<!-- =========================================================== -->
<!-- ORQUESTRADOR                                                 -->
<!-- =========================================================== -->
<node TEXT="Orquestrador" POSITION="left" ID="ID_orq" COLOR="#cc0000">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#cc0000" WIDTH="2"/>

<node TEXT="./orquestrador_fase9.sh" ID="ID_o1" COLOR="#cc0000">
<font BOLD="true" ITALIC="true" SIZE="12"/>
<icon BUILTIN="executable"/>
<richcontent TYPE="NOTE"><html><body>
<p>Roda so a Fase 9. ~15s (Postgres efemero na porta 5451).</p>
<p>Valida 5 arquivos, sintaxe de 5 modulos JS, 6 pontos no</p>
<p>recebimento.html, 4 no inspecao.html, 4 no PDF, 3 no dashboard.</p>
<p>Esperado: 136/136 OK.</p>
<p></p>
<p>Modos: padrao / --all (0-9, 914 testes) / --skip-tests</p>
</body></html></richcontent>
</node>

<node TEXT="Aplicar no Supabase" ID="ID_o2" COLOR="#cc0000">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="launch"/>
<node TEXT="SQL Editor &gt; cole sql/009_fase9_p2.sql &gt; Run">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Cria 4 tabelas (recebimentos, lembretes_cliente, recomendacoes,</p>
<p>os_contador), 3 funcoes, 3 views, 1 trigger.</p>
<p>Faz backfill dos numeros de OS das inspecoes existentes.</p>
<p>Idempotente.</p>
</body></html></richcontent>
</node>
<node TEXT="Conferir: SELECT COUNT(*) FROM inspecoes WHERE numero_os IS NOT NULL">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Deve bater com o total de inspecoes - o backfill nao deixa nenhuma</p>
<p>sem numero.</p>
</body></html></richcontent>
</node>
<node TEXT="git add . &amp;&amp; git commit -m 'Fase 9 P2' &amp;&amp; git push">
<font ITALIC="true"/>
</node>
<node TEXT="Limpar SW no celular (v0.8.0 -&gt; v0.9.0)">
<font ITALIC="true"/>
<icon BUILTIN="messagebox_warning"/>
</node>
</node>

<node TEXT="Roteiro de teste em campo" ID="ID_o3" COLOR="#cc0000">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="bookmark"/>
<richcontent TYPE="NOTE"><html><body>
<p>O fluxo completo da Fase 9, do portao ao WhatsApp.</p>
</body></html></richcontent>
<node TEXT="Dashboard &gt; Recebimento de moto &gt; buscar a placa"/>
<node TEXT="Tirar as 4 fotos (obrigatorias)"/>
<node TEXT="Anotar avarias, combustivel e acessorios"/>
<node TEXT="Colher a assinatura do cliente NA ENTRADA">
<icon BUILTIN="password"/>
</node>
<node TEXT="'Iniciar inspecao' - a vistoria fica vinculada">
<richcontent TYPE="NOTE"><html><body>
<p>O link leva ?placa=X&amp;recebimento=UUID. O inspecao.html</p>
<p>preenche a placa e vincula a vistoria a inspecao criada.</p>
</body></html></richcontent>
</node>
<node TEXT="Num item com foto, usar os botoes Antes e Depois"/>
<node TEXT="Finalizar e conferir o PDF">
<richcontent TYPE="NOTE"><html><body>
<p>Deve trazer: numero da OS no cabecalho, bloco de vistoria de</p>
<p>entrada, relato do cliente, checklist, itens adicionais,</p>
<p>orcamento e recomendacoes para a proxima revisao.</p>
</body></html></richcontent>
</node>
<node TEXT="Dashboard &gt; Lembretes ao cliente &gt; testar o WhatsApp">
<richcontent TYPE="NOTE"><html><body>
<p>A fila so mostra motos proxima/atrasada COM telefone.</p>
<p>Se estiver vazia, nenhuma moto precisa de contato agora.</p>
</body></html></richcontent>
</node>
</node>

</node>

<!-- =========================================================== -->
<!-- ESTADO                                                       -->
<!-- =========================================================== -->
<node TEXT="Estado apos a Fase 9" POSITION="left" ID="ID_estado" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>
<edge COLOR="#666666" STYLE="bezier"/>
<node TEXT="914 testes automatizados (100%)"><icon BUILTIN="button_ok"/></node>
<node TEXT="10 fases (0 a 9)"/>
<node TEXT="6 orquestradores (0, 5, 6, 7, 8, 9)"/>
<node TEXT="Service Worker v0.9.0"/>
<node TEXT="3 assinaturas distintas no fluxo">
<richcontent TYPE="NOTE"><html><body>
<p>entrada (estado recebido) / orcamento (autoriza executar) /</p>
<p>conclusao (atesta execucao). Cada uma num momento diferente.</p>
</body></html></richcontent>
</node>
<node TEXT="Resta do roadmap: P3 e P4">
<richcontent TYPE="NOTE"><html><body>
<p>P3: comparacao entre revisoes, teste de rodagem estruturado,</p>
<p>garantia, torque aplicado, revisao rapida.</p>
<p>P4 (so com escala): agendamento, estoque, multi-tenancy,</p>
<p>VIN, API publica, nota fiscal.</p>
</body></html></richcontent>
</node>
<node TEXT="O teste que falta continua sendo uma moto de verdade">
<icon BUILTIN="stop-sign"/>
<richcontent TYPE="NOTE"><html><body>
<p>914 testes nao respondem se o fluxo de recebimento eh rapido</p>
<p>o bastante com o cliente esperando em pe na oficina.</p>
<p>So uma moto real responde.</p>
</body></html></richcontent>
</node>
</node>

</node>
</map>
