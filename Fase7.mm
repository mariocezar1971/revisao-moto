<map version="freeplane 1.11.0">
<node TEXT="Fase 7&#xa;Polimento" FOLDED="false" ID="ID_root" STYLE="oval">
<font SIZE="18" BOLD="true"/>
<edge COLOR="#cc0000" WIDTH="thin"/>
<richcontent TYPE="NOTE"><html><body>
<p>7 melhorias de qualidade: icones reais, onboarding, QR code, torques por modelo,</p>
<p>notificacoes locais, dark mode e internacionalizacao PT-EN.</p>
<p>Resultado: 122/122 testes.</p>
</body></html></richcontent>

<!-- PASSOS -->
<node TEXT="Passos" POSITION="right" ID="ID_passos" COLOR="#0066cc">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="list"/>
<edge COLOR="#0066cc" WIDTH="2"/>

<node TEXT="Icones reais&#xa;(substituir placeholders)" ID="ID_p1" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="idea"/>
<richcontent TYPE="NOTE"><html><body>
<p>3 icones PNG gerados programaticamente:</p>
<p>- icon-192.png (1.4 KB) - normal 192x192</p>
<p>- icon-512.png (4.1 KB) - normal 512x512</p>
<p>- icon-512-maskable.png (2.7 KB) - safe zone Android</p>
<p>Design: quadrado vermelho arredondado + checkmark + duas rodas de moto.</p>
<p>Manifest atualizado: purpose 'any' e 'maskable' separados, shortcuts para Nova Inspecao e Historico.</p>
</body></html></richcontent>
</node>

<node TEXT="Onboarding na 1a abertura" ID="ID_p2" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="phone_mobile"/>
<richcontent TYPE="NOTE"><html><body>
<p>Arquivo: onboarding.html</p>
<p>5 slides: bem-vindo, cadastrar, executar, assinar, offline.</p>
<p>Dots de progresso, botao pular, i18n PT/EN.</p>
<p>Ao finalizar: grava rm_onboarding_visto em localStorage e redireciona para index.html.</p>
<p>index.html: se rm_onboarding_visto ausente, redireciona para onboarding.html.</p>
</body></html></richcontent>
</node>

<node TEXT="QR Code na moto -&gt; abre inspecao direto" ID="ID_p3" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="bookmark"/>
<node TEXT="Gerar QR por placa">
<richcontent TYPE="NOTE"><html><body>
<p>Modulo: src/qrcode.js + qrcode.html</p>
<p>Usa CDN qrcode-generator (biblioteca leve).</p>
<p>gerarQrParaPlaca(placa) -&gt; SVG com URL: .../inspecao.html?placa=XXX</p>
<p>Botoes: Imprimir (janela nova) e Baixar SVG.</p>
</body></html></richcontent>
</node>
<node TEXT="Scanner via getUserMedia">
<richcontent TYPE="NOTE"><html><body>
<p>Usa BarcodeDetector nativo (Chrome Android).</p>
<p>Camera traseira (facingMode: environment).</p>
<p>Ao ler QR: extrairPlacaDoQr() e redireciona para inspecao.html?placa=X</p>
<p>inspecao.html: funcao preencherPlacaViaUrl() auto-preenche o input.</p>
</body></html></richcontent>
</node>
</node>

<node TEXT="Tela de torques/specs por modelo" ID="ID_p4" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="folder"/>
<node TEXT="Consulta rapida durante revisao">
<richcontent TYPE="NOTE"><html><body>
<p>Arquivo: especificacoes.html</p>
<p>SQL: 007_fase7_especificacoes.sql cria tabela + view vw_especificacoes.</p>
<p>5 categorias: Torques, Fluidos, Pneus, Eletrica, Geral.</p>
<p>18 items por modelo (170 registros no seed - 10 modelos).</p>
<p>Volumes de oleo especificos: 650 = 3.1L, 350 = 2.5L, 450 = 2.4L.</p>
<p>Aceita ?modelo=X na URL (integracao futura com inspecao).</p>
</body></html></richcontent>
</node>
</node>

<node TEXT="Push notifications" ID="ID_p5" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="messagebox_warning"/>
<node TEXT="Revisao proxima">
<richcontent TYPE="NOTE"><html><body>
<p>Modulo: src/notifications.js</p>
<p>Nao usa Web Push (nao ha servidor): notificacoes LOCAIS via Notification API + Service Worker.</p>
<p>Ao carregar dashboard, checa vw_motos_com_status_revisao e alerta motos com status 'proxima' ou 'atrasada'.</p>
</body></html></richcontent>
</node>
<node TEXT="Inspecao em andamento ha muito tempo">
<richcontent TYPE="NOTE"><html><body>
<p>Query: inspecoes WHERE status='em_andamento' AND data_inicio &lt; NOW() - 24h.</p>
<p>Notifica: 'Voce iniciou uma inspecao ha mais de 24 horas'.</p>
<p>Anti-spam: usa chave localStorage por dia (rm_notif_insp_YYYY-MM-DD).</p>
</body></html></richcontent>
</node>
</node>

<node TEXT="Dark mode" ID="ID_p6" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="clanbomber"/>
<richcontent TYPE="NOTE"><html><body>
<p>Modulo: src/darkmode.js + CSS regras html.dark em styles.css.</p>
<p>Estrategia:</p>
<p>1. Detecta prefers-color-scheme na 1a visita.</p>
<p>2. Usuario pode alternar manualmente via botao flutuante (bottom-right).</p>
<p>3. Preferencia salva em localStorage (rm_tema).</p>
<p>Tailwind: darkMode: 'class' - adiciona classe 'dark' no &lt;html&gt;.</p>
<p>Muda tambem meta theme-color (barra do navegador mobile).</p>
</body></html></richcontent>
</node>

<node TEXT="Internacionalizacao PT-EN" ID="ID_p7" COLOR="#0066cc">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="button_ok"/>
<richcontent TYPE="NOTE"><html><body>
<p>Modulo: src/i18n.js + assets/i18n/pt.json + en.json.</p>
<p>Sistema leve sem framework:</p>
<p>- t('dashboard.motos') retorna string traduzida</p>
<p>- Suporta placeholders: t('notif.desc', {placa:'X'})</p>
<p>- data-i18n="chave" em HTML -&gt; aplicarNoDOM() traduz</p>
<p>- localStorage salva escolha (rm_idioma)</p>
<p>- Detecta navigator.language como fallback</p>
<p>Chaves cobertas: app, nav, login, dashboard, moto, inspecao, historico, specs, onboarding, qr, notif, geral.</p>
</body></html></richcontent>
</node>

</node>

<!-- ORQUESTRADOR -->
<node TEXT="Orquestrador" POSITION="left" ID="ID_orq" COLOR="#cc0000">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#cc0000" WIDTH="2"/>

<node TEXT="./orquestrador_fase7.sh" ID="ID_o1" COLOR="#cc0000">
<font BOLD="true" ITALIC="true" SIZE="12"/>
<icon BUILTIN="executable"/>
<richcontent TYPE="NOTE"><html><body>
<p>Roda so testes Fase 7. ~10s (sobe Postgres efemero para migration).</p>
<p>Valida: 12 arquivos, 4 JSONs, sintaxe JS, integracao nas 4 paginas existentes, versao SW.</p>
<p>Esperado: 122/122 OK.</p>
<p>Modos: padrao (Fase 7) / --all (0-7, ~40s, 633 testes) / --skip-tests.</p>
</body></html></richcontent>
</node>

<node TEXT="Testar no Supabase (producao)" ID="ID_o2" COLOR="#cc0000">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="launch"/>
<node TEXT="Cole sql/007_fase7_especificacoes.sql no SQL Editor -&gt; Run">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Cria tabela especificacoes_modelo + view vw_especificacoes + seed generico para todos os modelos.</p>
</body></html></richcontent>
</node>
<node TEXT="git add . &amp;&amp; git commit -m 'Fase 7: polimento' &amp;&amp; git push">
<font ITALIC="true"/>
</node>
<node TEXT="Aguardar deploy do GitHub Pages (~1min)">
<font ITALIC="true"/>
</node>
<node TEXT="Limpar SW no celular (DevTools &gt; Application)">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Passo essencial: SW v0.6.0 antigo vai continuar servindo cache.</p>
<p>Application &gt; Service Workers &gt; Unregister.</p>
<p>Depois: Storage &gt; Clear site data.</p>
</body></html></richcontent>
</node>
<node TEXT="Abrir a URL - onboarding aparece">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Se localStorage.rm_onboarding_visto nao existir, entra no onboarding.</p>
<p>Passa pelos 5 slides (ou pula) e vai para login.</p>
</body></html></richcontent>
</node>
<node TEXT="Testar dark mode (botao lua/sol embaixo direita)">
<font ITALIC="true"/>
</node>
<node TEXT="Testar QR: gerar para placa, imprimir, escanear com camera">
<font ITALIC="true"/>
</node>
<node TEXT="Permitir notificacoes quando o app pedir">
<font ITALIC="true"/>
</node>
</node>

<node TEXT="Testar localmente" ID="ID_o3" COLOR="#cc0000">
<font BOLD="true" SIZE="12"/>
<icon BUILTIN="button_ok"/>
<richcontent TYPE="NOTE"><html><body>
<p>Servidor HTTP local. Usa credenciais do src/supabase-client.js.</p>
<p>Ideal para iterar rapido sem esperar deploy do Pages.</p>
</body></html></richcontent>
<node TEXT="cd /mnt/c/Users/mceza/Dropbox/PROJETOS/APLICATIVOS/JAVASCRIPT/APLICATIVOS/revisao-moto">
<font ITALIC="true"/>
</node>
<node TEXT="python3 -m http.server 8000">
<font ITALIC="true"/>
</node>
<node TEXT="http://localhost:8000">
<font ITALIC="true"/>
<richcontent TYPE="NOTE"><html><body>
<p>Se ja passou pelo onboarding uma vez, adicione ?skip_onboarding para nao ver de novo.</p>
</body></html></richcontent>
</node>
</node>

</node>

</node>
</map>
