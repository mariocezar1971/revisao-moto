<map version="freeplane 1.11.0">
<!--To view this file, download free mind mapping software Freeplane from https://www.freeplane.org -->
<node TEXT="Revis&#xe3;o Moto&#xa;Roadmap" FOLDED="false" ID="ID_root" CREATED="1750000000000" MODIFIED="1750000000000" STYLE="oval">
<font SIZE="20" BOLD="true"/>
<edge COLOR="#cc0000" WIDTH="thin"/>
<richcontent TYPE="NOTE">
<html>
  <head></head>
  <body>
    <p>PWA para checklist de revisões Royal Enfield.</p>
    <p>Stack: HTML/CSS/JS vanilla + Tailwind CDN + Supabase + GitHub Pages.</p>
    <p>Repo: github.com/mariocezar1971/revisao-moto</p>
    <p>Padrão: mesmo da Fase 0 do RideLink.</p>
  </body>
</html>
</richcontent>

<!-- ============================================================ -->
<!-- FASE 0 - SETUP (Procedimento de execucao)                     -->
<!-- ============================================================ -->
<node TEXT="Fase 0 - Setup" POSITION="right" ID="ID_fase0" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#006400">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="button_ok"/>
<edge COLOR="#006400"/>
<richcontent TYPE="NOTE"><html><body><p>Procedimento de setup do ambiente local (WSL Ubuntu).</p><p>Pre-requisito: WSL ja instalado no Windows.</p></body></html></richcontent>

<node TEXT="wsl" ID="ID_f0_wsl"><icon BUILTIN="launch"/>
<richcontent TYPE="NOTE"><html><body><p>No PowerShell: digite 'wsl' para entrar no Ubuntu.</p><p>O prompt muda de PS C:\..&gt; para mceza@mcezarjr:...$</p></body></html></richcontent>
</node>

<node TEXT="Voce ja esta no WSL com sudo funcionando" ID="ID_f0_wsl_ok"><icon BUILTIN="button_ok"/>
<node TEXT="sudo apt update; sudo apt install -y postgresql postgresql-contrib python3 nodejs" ID="ID_f0_apt">
<font ITALIC="true"/>
<icon BUILTIN="prepare"/>
<richcontent TYPE="NOTE"><html><body><p>Instala PostgreSQL (banco para testes), Python 3 (runner dos testes) e Node.js (validador de sintaxe JS).</p><p>Duracao: 2-5 minutos na primeira vez.</p></body></html></richcontent>
</node>
</node>

<node TEXT="Vai ate o projeto" ID="ID_f0_cd"><icon BUILTIN="folder"/>
<node TEXT="cd /mnt/c/Users/mceza/Dropbox/PROGRAMACAO/JAVASCRIPT/APLICATIVOS/revisao-moto/revisao-moto" ID="ID_f0_cd_cmd">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body><p>WSL acessa o disco C: do Windows via /mnt/c/</p><p>Note as barras / (Linux), nao \ (Windows).</p></body></html></richcontent>
</node>
</node>

<node TEXT="OU se voce ja fez o git init/commit, faca um pull/cherry-pick" ID="ID_f0_git"><icon BUILTIN="help"/>
<richcontent TYPE="NOTE"><html><body><p>Alternativa: clonar/atualizar via Git em vez de descompactar o ZIP.</p></body></html></richcontent>
<node TEXT="chmod +x tests/run_tests.sh" ID="ID_f0_chmod">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body><p>Torna o script executavel (Linux exige permissao explicita).</p></body></html></richcontent>
</node>
<node TEXT="./tests/run_tests.sh" ID="ID_f0_run">
<font ITALIC="true" BOLD="true"/>
<icon BUILTIN="gohome"/>
<richcontent TYPE="NOTE"><html><body><p>Executa a suite completa: 110 testes em 9 grupos.</p><p>Sobe Postgres efemero, roda schema e seed, valida tudo, derruba o servidor.</p><p>Duracao: ~30 segundos.</p><p>Esperado: 110/110 passando.</p></body></html></richcontent>
</node>
</node>

<!-- Sub-arvore: artefatos entregues (referencia) -->
<node TEXT="Artefatos entregues (referencia)" ID="ID_f0_artefatos" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>
<node TEXT="Estrutura de pastas" ID="ID_f0_1"><icon BUILTIN="button_ok"/></node>
<node TEXT="Schema SQL completo (001_schema.sql)" ID="ID_f0_2"><icon BUILTIN="button_ok"/>
<node TEXT="Tabelas: modelos, revisoes, itens_checklist, motos, inspecoes, inspecoes_itens"/>
<node TEXT="Views: vw_checklist_completo, vw_motos_status"/>
<node TEXT="Triggers de atualizado_em"/>
<node TEXT="RLS policies (auth read/write)"/>
<node TEXT="Indices de performance"/>
</node>
<node TEXT="Seed Royal Enfield (002_seed)" ID="ID_f0_3"><icon BUILTIN="button_ok"/>
<node TEXT="10 modelos (Shotgun 650, Super Meteor, Interceptor, Continental GT, Classic 650, Bear 650, Hunter 350, Classic 350, Meteor 350, Himalayan 450)"/>
<node TEXT="70 revisoes (10 modelos x 7 km)"/>
<node TEXT="1300 itens de checklist"/>
</node>
<node TEXT="index.html com login funcional" ID="ID_f0_4"><icon BUILTIN="button_ok"/></node>
<node TEXT="Dashboard com estatisticas" ID="ID_f0_5"><icon BUILTIN="button_ok"/></node>
<node TEXT="Service Worker (cache app shell)" ID="ID_f0_6"><icon BUILTIN="button_ok"/></node>
<node TEXT="PWA manifest + icones placeholder" ID="ID_f0_7"><icon BUILTIN="button_ok"/></node>
<node TEXT="README com roadmap" ID="ID_f0_8"><icon BUILTIN="button_ok"/></node>
<node TEXT="Suite de testes automatizada" ID="ID_f0_9"><icon BUILTIN="button_ok"/>
<node TEXT="tests/test_fase0.py - 110 testes em 9 grupos"/>
<node TEXT="tests/run_tests.sh - runner com Postgres efemero"/>
<node TEXT="tests/README.md - documentacao dos testes"/>
<node TEXT="Resultado: 110/110 passando (100%)"/>
</node>
</node>
</node>

<!-- ============================================================ -->
<!-- FASE 1 - CATALOGO (Procedimento de execucao)                  -->
<!-- ============================================================ -->
<node TEXT="Fase 1 - Catalogo no banco" POSITION="right" ID="ID_fase1" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#006400">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="button_ok"/>
<edge COLOR="#006400"/>
<richcontent TYPE="NOTE"><html><body><p>Setup do catalogo Royal Enfield no Supabase (cloud).</p><p>Acontece no Dashboard do Supabase + scripts de automacao locais.</p></body></html></richcontent>

<node TEXT="Rodar 001_schema.sql no SQL Editor" ID="ID_f1_sql1"><icon BUILTIN="bookmark"/>
<richcontent TYPE="NOTE"><html><body><p>Dashboard Supabase &gt; SQL Editor &gt; New query</p><p>Cole o conteudo de sql/001_schema.sql e clique em Run.</p><p>Cria 6 tabelas, 2 views, triggers, RLS policies, indices.</p></body></html></richcontent>
</node>

<node TEXT="Rodar 002_seed_royal_enfield.sql" ID="ID_f1_sql2"><icon BUILTIN="bookmark"/>
<richcontent TYPE="NOTE"><html><body><p>Novo query no SQL Editor.</p><p>Cole o conteudo de sql/002_seed_royal_enfield.sql e Run.</p><p>Popula 10 modelos, 70 revisoes, 1300 itens de checklist.</p></body></html></richcontent>
</node>

<node TEXT="Validar contagens" ID="ID_f1_valid"><icon BUILTIN="help"/>
<richcontent TYPE="NOTE"><html><body><p>Duas opcoes de validacao:</p><p>A) Rapida: cole sql/validacao_fase1.sql no SQL Editor (output PASS/FAIL inline)</p><p>B) Completa: rode python3 tests/test_fase1.py --remote (apos preencher .env)</p></body></html></richcontent>
<node TEXT="SELECT COUNT(*) FROM modelos -- esperado: 10" ID="ID_f1_v1">
<font ITALIC="true"/>
</node>
<node TEXT="SELECT COUNT(*) FROM revisoes -- esperado: 70" ID="ID_f1_v2">
<font ITALIC="true"/>
</node>
<node TEXT="SELECT COUNT(*) FROM itens_checklist -- esperado: 1300" ID="ID_f1_v3">
<font ITALIC="true"/>
</node>
<node TEXT="Ou rode o script completo: \\i sql/validacao_fase1.sql" ID="ID_f1_v4">
<font ITALIC="true"/>
<icon BUILTIN="gohome"/>
</node>
</node>

<node TEXT="Criar bucket 'inspecoes' no Storage" ID="ID_f1_bucket"><icon BUILTIN="folder"/>
<richcontent TYPE="NOTE"><html><body><p>Bucket privado, max 10MB/arquivo, tipos: jpg, png, webp, pdf.</p><p>Duas opcoes:</p><p>A) Manual: Dashboard &gt; Storage &gt; New bucket &gt; nome 'inspecoes', private</p><p>B) Automatica: python3 scripts/setup_fase1.py (cria via Admin API)</p></body></html></richcontent>
</node>

<node TEXT="Cadastrar usuarios mecanicos" ID="ID_f1_users"><icon BUILTIN="prepare"/>
<richcontent TYPE="NOTE"><html><body><p>Duas opcoes:</p><p>A) Manual: Dashboard &gt; Authentication &gt; Add user (um a um)</p><p>B) Automatica: edite usuarios.json (copie de usuarios.json.exemplo)</p><p>e rode python3 scripts/setup_fase1.py</p></body></html></richcontent>
</node>

<!-- Sub-arvore: artefatos de automacao -->
<node TEXT="Artefatos de automacao (referencia)" ID="ID_f1_artefatos" COLOR="#666666">
<font ITALIC="true" SIZE="11"/>
<icon BUILTIN="info"/>
<node TEXT=".env.exemplo - template de credenciais"/>
<node TEXT="usuarios.json.exemplo - lista de mecanicos"/>
<node TEXT="sql/validacao_fase1.sql - script de validacao inline (24 asserts)"/>
<node TEXT="scripts/setup_fase1.py - cria bucket + usuarios via Admin API"/>
<node TEXT="tests/test_fase1.py - suite com modo local/remote"/>
<node TEXT="Resultado local: 24/24 passando (100%)"/>
</node>
</node>

<!-- ============================================================ -->
<!-- FASE 2 - CRUD MOTOS                                            -->
<!-- ============================================================ -->
<node TEXT="Fase 2 - CRUD de Motos" POSITION="right" ID="ID_fase2" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#ff8c00">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="prepare"/>
<edge COLOR="#ff8c00"/>
<richcontent TYPE="NOTE"><html><body><p>Próxima fase. Estimativa: 1 fim de semana.</p></body></html></richcontent>

<node TEXT="Criar admin.html" ID="ID_f2_1"/>
<node TEXT="Listagem de motos cadastradas" ID="ID_f2_2">
<node TEXT="Filtro por placa"/>
<node TEXT="Filtro por proprietário"/>
<node TEXT="Paginação (se &gt; 50 motos)"/>
</node>
<node TEXT="Formulário de cadastro" ID="ID_f2_3">
<node TEXT="Placa (obrigatório, único)"/>
<node TEXT="Chassi e Renavam"/>
<node TEXT="Modelo (select com 10 RE)"/>
<node TEXT="Ano, cor"/>
<node TEXT="Proprietário: nome, telefone, e-mail"/>
<node TEXT="Data de compra"/>
<node TEXT="Km atual"/>
<node TEXT="Observações livres"/>
</node>
<node TEXT="Edição de moto existente" ID="ID_f2_4"/>
<node TEXT="Atualização de km (quick action)" ID="ID_f2_5"/>
<node TEXT="Soft delete (campo ativo)" ID="ID_f2_6"><icon BUILTIN="help"/></node>
</node>

<!-- ============================================================ -->
<!-- FASE 3 - EXECUÇÃO DO CHECKLIST (CORE)            -->
<!-- ============================================================ -->
<node TEXT="Fase 3 - Execução do Checklist (CORE)" POSITION="right" ID="ID_fase3" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#cc0000">
<font BOLD="true" SIZE="15"/>
<icon BUILTIN="gohome"/>
<icon BUILTIN="bookmark"/>
<edge COLOR="#cc0000" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body><p>Coração do app. Estimativa: 2 fins de semana.</p></body></html></richcontent>

<node TEXT="Criar inspecao.html" ID="ID_f3_1"/>
<node TEXT="Criar src/inspecao.js" ID="ID_f3_2"/>
<node TEXT="Criar src/camera.js" ID="ID_f3_3"/>

<node TEXT="Seleção da moto" ID="ID_f3_4">
<node TEXT="Autocomplete por placa"/>
<node TEXT="Mostrar última revisão feita"/>
<node TEXT="Mostrar km atual"/>
</node>

<node TEXT="Detecção automática da revisão" ID="ID_f3_5">
<node TEXT="Calcular próxima revisão pelo km"/>
<node TEXT="Considerar tempo (6 meses)"/>
<node TEXT="Permitir override manual"/>
</node>

<node TEXT="Carregamento dinâmico dos itens" ID="ID_f3_6">
<node TEXT="Query: vw_checklist_completo WHERE modelo_id = X AND revisao_id = Y"/>
<node TEXT="Agrupar por categoria"/>
<node TEXT="Ordenar por campo ordem"/>
</node>

<node TEXT="Renderização de cada item" ID="ID_f3_7">
<node TEXT="Botões OK / N-OK / N-A (44px min altura)"/>
<node TEXT="Campo observação"/>
<node TEXT="Botão de foto (se exige_foto)"/>
<node TEXT="Campo valor medido (se exige_medicao)"/>
<node TEXT="Valor de referência em destaque"/>
</node>

<node TEXT="Captura de foto" ID="ID_f3_8">
<node TEXT="Tentar getUserMedia API"/>
<node TEXT="Fallback: input file capture='environment'"/>
<node TEXT="Compressão client-side (max 1MB)"/>
<node TEXT="Upload para Storage Supabase"/>
<node TEXT="Bucket: inspecoes/{inspecao_id}/{item_id}.jpg"/>
</node>

<node TEXT="Autosave a cada interação" ID="ID_f3_9">
<node TEXT="Debounce 500ms"/>
<node TEXT="Indicador visual 'salvando...'"/>
<node TEXT="Fallback IndexedDB se offline"/>
</node>

<node TEXT="Indicador de progresso" ID="ID_f3_10">
<node TEXT="Barra X de Y itens"/>
<node TEXT="% concluído por categoria"/>
</node>

<node TEXT="Validação de finalização" ID="ID_f3_11">
<node TEXT="Bloquear se obrigatório pendente"/>
<node TEXT="Exigir foto onde marcado"/>
<node TEXT="Exigir valor medido onde marcado"/>
<node TEXT="Confirmar antes de finalizar"/>
</node>
</node>

<!-- ============================================================ -->
<!-- FASE 4 - ASSINATURA + PDF                                      -->
<!-- ============================================================ -->
<node TEXT="Fase 4 - Assinatura + PDF" POSITION="right" ID="ID_fase4" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#0066cc">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="pencil"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body><p>Estimativa: 1 fim de semana.</p></body></html></richcontent>

<node TEXT="Criar src/assinatura.js" ID="ID_f4_1"/>
<node TEXT="Criar src/pdf.js (usando jsPDF)" ID="ID_f4_2"/>

<node TEXT="Canvas de assinatura" ID="ID_f4_3">
<node TEXT="touch-action: none (impede scroll)"/>
<node TEXT="Eventos pointer (touch + mouse)"/>
<node TEXT="Botão limpar"/>
<node TEXT="Export como base64 PNG"/>
</node>

<node TEXT="Coleta de assinaturas" ID="ID_f4_4">
<node TEXT="Mecânico (obrigatório)"/>
<node TEXT="Cliente + nome (obrigatório)"/>
</node>

<node TEXT="Geração do PDF" ID="ID_f4_5">
<node TEXT="Cabeçalho (logo, oficina, data)"/>
<node TEXT="Dados da moto e proprietário"/>
<node TEXT="Tabela de itens (status, obs, valor)"/>
<node TEXT="Fotos embarcadas como thumbnails"/>
<node TEXT="Assinaturas no rodapé"/>
<node TEXT="Hash SHA-256 do conteúdo"/>
<node TEXT="QR Code de verificação (opcional)"/>
</node>

<node TEXT="Upload do PDF para Storage" ID="ID_f4_6">
<node TEXT="Path: inspecoes/{id}/relatorio.pdf"/>
<node TEXT="Atualizar inspecoes.pdf_url"/>
</node>

<node TEXT="Compartilhamento" ID="ID_f4_7">
<node TEXT="Web Share API (WhatsApp, email)"/>
<node TEXT="Botão copiar link"/>
<node TEXT="Download local"/>
</node>
</node>

<!-- ============================================================ -->
<!-- FASE 5 - HISTÓRICO                                      -->
<!-- ============================================================ -->
<node TEXT="Fase 5 - Histórico e Relatórios" POSITION="left" ID="ID_fase5" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#0066cc">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="list"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body><p>Estimativa: 1 fim de semana.</p></body></html></richcontent>

<node TEXT="Criar historico.html" ID="ID_f5_1"/>

<node TEXT="Lista de motos com última inspeção" ID="ID_f5_2">
<node TEXT="Indicador de revisão atrasada"/>
<node TEXT="Cálculo de próxima prevista"/>
</node>

<node TEXT="Detalhe por moto" ID="ID_f5_3">
<node TEXT="Timeline de revisões"/>
<node TEXT="Link para PDF de cada uma"/>
<node TEXT="Gráfico de km vs tempo"/>
</node>

<node TEXT="Filtros" ID="ID_f5_4">
<node TEXT="Período (de/até)"/>
<node TEXT="Mecânico responsável"/>
<node TEXT="Status (em andamento, finalizada)"/>
<node TEXT="Modelo"/>
</node>

<node TEXT="Export CSV" ID="ID_f5_5">
<node TEXT="Inspeções (cabeçalho)"/>
<node TEXT="Itens (detalhe)"/>
</node>

<node TEXT="Relatórios gerenciais" ID="ID_f5_6">
<node TEXT="Inspeções por mecânico/mês"/>
<node TEXT="Itens mais reprovados (problemas comuns)"/>
<node TEXT="Tempo médio por revisão"/>
</node>
</node>

<!-- ============================================================ -->
<!-- FASE 6 - OFFLINE                                               -->
<!-- ============================================================ -->
<node TEXT="Fase 6 - Offline completo" POSITION="left" ID="ID_fase6" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#0066cc">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="broken-line"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body><p>Estimativa: 1 fim de semana. Crítico para mecânico em garagem sem 4G.</p></body></html></richcontent>

<node TEXT="Criar src/db-local.js (IndexedDB wrapper)" ID="ID_f6_1"/>

<node TEXT="Cache do catálogo" ID="ID_f6_2">
<node TEXT="Baixar modelos no 1º login"/>
<node TEXT="Baixar revisões no 1º login"/>
<node TEXT="Baixar itens_checklist completo"/>
<node TEXT="Refresh quando online"/>
</node>

<node TEXT="Fila de upload de fotos" ID="ID_f6_3">
<node TEXT="Foto salva local em base64"/>
<node TEXT="Background sync quando online"/>
<node TEXT="Retry com backoff exponencial"/>
</node>

<node TEXT="Sincronização de inspeções" ID="ID_f6_4">
<node TEXT="Inspecao iniciada offline -&gt; UUID local"/>
<node TEXT="Push quando online"/>
<node TEXT="Resolução de conflitos last-write-wins"/>
</node>

<node TEXT="Indicador visual de modo offline" ID="ID_f6_5"><icon BUILTIN="button_ok"/>
<node TEXT="Já implementado no boot do index.html"/>
</node>

<node TEXT="Estratégia stale-while-revalidate" ID="ID_f6_6">
<node TEXT="Atualizar SW para v0.2.0"/>
</node>
</node>

<!-- ============================================================ -->
<!-- FASE 7 - POLIMENTO                                             -->
<!-- ============================================================ -->
<node TEXT="Fase 7 - Polimento" POSITION="left" ID="ID_fase7" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#0066cc">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="launch"/>
<edge COLOR="#0066cc"/>

<node TEXT="Ícones reais (substituir placeholders)" ID="ID_f7_1"><icon BUILTIN="help"/></node>
<node TEXT="Onboarding na 1ª abertura" ID="ID_f7_2"/>
<node TEXT="QR Code na moto -&gt; abre inspeção direto" ID="ID_f7_3">
<node TEXT="Gerar QR por placa"/>
<node TEXT="Scanner via getUserMedia"/>
</node>
<node TEXT="Tela de torques/specs por modelo" ID="ID_f7_4">
<node TEXT="Consulta rápida durante revisão"/>
</node>
<node TEXT="Push notifications" ID="ID_f7_5">
<node TEXT="Revisão próxima"/>
<node TEXT="Inspeção em andamento há muito tempo"/>
</node>
<node TEXT="Dark mode" ID="ID_f7_6"/>
<node TEXT="Internacionalização (PT-EN)" ID="ID_f7_7"><icon BUILTIN="help"/></node>
</node>

<!-- ============================================================ -->
<!-- BRANCH: STACK TÉCNICA                                   -->
<!-- ============================================================ -->
<node TEXT="Stack Técnica" POSITION="left" ID="ID_stack" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#666666">
<font BOLD="true" SIZE="13" ITALIC="true"/>
<edge COLOR="#666666" STYLE="bezier"/>

<node TEXT="Frontend">
<node TEXT="HTML/CSS/JS vanilla (sem build)"/>
<node TEXT="Tailwind CDN"/>
<node TEXT="Service Worker (cache offline)"/>
<node TEXT="IndexedDB (Fase 6)"/>
<node TEXT="jsPDF (Fase 4)"/>
</node>

<node TEXT="Backend">
<node TEXT="Supabase Auth"/>
<node TEXT="Postgres (6 tabelas + 2 views)"/>
<node TEXT="Supabase Storage (bucket inspecoes)"/>
<node TEXT="Realtime (futuro)"/>
</node>

<node TEXT="Deploy">
<node TEXT="GitHub Pages (gratuito)"/>
<node TEXT="Repo: github.com/mariocezar1971/revisao-moto"/>
<node TEXT="Branch main, pasta raiz"/>
</node>

<node TEXT="APIs do navegador">
<node TEXT="getUserMedia (câmera)"/>
<node TEXT="Canvas (assinatura, PDF)"/>
<node TEXT="Web Share API (compartilhar PDF)"/>
<node TEXT="Notification API (Fase 7)"/>
</node>
</node>

<!-- ============================================================ -->
<!-- BRANCH: DADOS                                                   -->
<!-- ============================================================ -->
<node TEXT="Modelo de Dados" POSITION="left" ID="ID_dados" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#666666">
<font BOLD="true" SIZE="13" ITALIC="true"/>
<edge COLOR="#666666" STYLE="bezier"/>

<node TEXT="modelos (10 linhas)">
<node TEXT="Linha 650 Twin: Shotgun, Super Meteor, Interceptor, Continental GT, Classic 650, Bear 650"/>
<node TEXT="Linha 350 J: Hunter, Classic, Meteor"/>
<node TEXT="Himalayan 450"/>
</node>

<node TEXT="revisoes (70 linhas)">
<node TEXT="500 km / 1 mês - amaciamento"/>
<node TEXT="5.000 km / 6 meses - leve"/>
<node TEXT="10.000 km / 12 meses - intermediária"/>
<node TEXT="15.000 km / 18 meses - leve"/>
<node TEXT="20.000 km / 24 meses - pesada"/>
<node TEXT="25.000 km / 30 meses - leve"/>
<node TEXT="30.000 km / 36 meses - intermediária"/>
</node>

<node TEXT="itens_checklist (1300 linhas)">
<node TEXT="14 itens na 500 km"/>
<node TEXT="16 itens nas leves (5k/15k/25k)"/>
<node TEXT="22 itens nas intermediárias (10k/30k)"/>
<node TEXT="24 itens na pesada (20k)"/>
</node>

<node TEXT="Categorias">
<node TEXT="Motor"/>
<node TEXT="Freios"/>
<node TEXT="Transmissão"/>
<node TEXT="Elétrica"/>
<node TEXT="Suspensão"/>
<node TEXT="Pneus"/>
<node TEXT="Lubrificação"/>
<node TEXT="Geral"/>
</node>
</node>

<!-- ============================================================ -->
<!-- BRANCH: DECISÕES DE PROJETO                             -->
<!-- ============================================================ -->
<node TEXT="Decisões" POSITION="right" ID="ID_decisoes" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#666666">
<font BOLD="true" SIZE="13" ITALIC="true"/>
<edge COLOR="#666666" STYLE="bezier"/>

<node TEXT="Sem build step" COLOR="#006400">
<node TEXT="Padrão RideLink Fase 0"/>
<node TEXT="GitHub Pages serve direto"/>
</node>

<node TEXT="Sem monetização" COLOR="#006400">
<node TEXT="Uso interno"/>
<node TEXT="RLS simples (auth = acesso total)"/>
</node>

<node TEXT="Snapshot do nome do mecânico" COLOR="#006400">
<node TEXT="Histórico imutável"/>
<node TEXT="Mesmo se user for removido"/>
</node>

<node TEXT="Hash SHA-256 no PDF" COLOR="#006400">
<node TEXT="Trilha de auditoria"/>
<node TEXT="Verificação de integridade"/>
</node>

<node TEXT="PWA em vez de app nativo" COLOR="#006400">
<node TEXT="Sem app store"/>
<node TEXT="Atualização imediata via SW"/>
</node>
</node>

<!-- ============================================================ -->
<!-- BRANCH: MARCOS / TIMELINE                                       -->
<!-- ============================================================ -->
<node TEXT="Marcos" POSITION="right" ID="ID_marcos" CREATED="1750000000000" MODIFIED="1750000000000" COLOR="#000000">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="calendar"/>
<edge COLOR="#000000" STYLE="bezier"/>

<node TEXT="M1: Setup validado (Fase 0+1)" COLOR="#ff8c00">
<icon BUILTIN="flag-orange"/>
<node TEXT="Login funcionando no celular"/>
<node TEXT="Dashboard carrega"/>
<node TEXT="Catálogo populado no banco"/>
</node>

<node TEXT="M2: CRUD funcional (Fase 2)" COLOR="#0066cc">
<icon BUILTIN="flag"/>
<node TEXT="Pelo menos 5 motos cadastradas"/>
<node TEXT="Edição funciona"/>
</node>

<node TEXT="M3: 1ª inspeção real (Fase 3)" COLOR="#cc0000">
<icon BUILTIN="flag"/>
<icon BUILTIN="bookmark"/>
<node TEXT="Mecânico real conclui checklist completo"/>
<node TEXT="Fotos salvas no Storage"/>
<node TEXT="Marco mais crítico do projeto"/>
</node>

<node TEXT="M4: Documento gerado (Fase 4)" COLOR="#0066cc">
<icon BUILTIN="flag"/>
<node TEXT="PDF válido enviado para cliente via WhatsApp"/>
</node>

<node TEXT="M5: Operação em campo (Fase 5+6)" COLOR="#0066cc">
<icon BUILTIN="flag"/>
<node TEXT="Histórico consultável"/>
<node TEXT="Funciona sem internet na garagem"/>
</node>
</node>

</node>
</map>
