<map version="freeplane 1.11.0">
<node TEXT="Fase 1&#xa;Cat&#xe1;logo no Supabase" FOLDED="false" ID="ID_root" CREATED="1750000000000" MODIFIED="1750000000000" STYLE="oval">
<font SIZE="18" BOLD="true"/>
<edge COLOR="#006400" WIDTH="thin"/>
<richcontent TYPE="NOTE">
<html><body>
<p>Setup do Supabase: schema, seed, bucket, usuarios.</p>
<p>8 passos em sequencia. Cada passo tem nota explicativa.</p>
<p>Resultado esperado: 8/8 testes passando em test_fase1.py --remote</p>
</body></html>
</richcontent>

<!-- ============================================================ -->
<!-- PASSO A - CRIAR PROJETO                                       -->
<!-- ============================================================ -->
<node TEXT="A. Criar projeto Supabase" POSITION="right" ID="ID_A" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="launch"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body>
<p><b>Onde:</b> browser, supabase.com</p>
<p><b>Duracao:</b> ~3 min (2 min provisionando)</p>
</body></html></richcontent>
<node TEXT="supabase.com -&gt; Login (GitHub funciona)"/>
<node TEXT="New project"/>
<node TEXT="Nome: revisao-moto"/>
<node TEXT="Database password: ANOTAR em local seguro"><icon BUILTIN="messagebox_warning"/></node>
<node TEXT="Region: South America (Sao Paulo)"/>
</node>

<!-- ============================================================ -->
<!-- PASSO B - RODAR SQLs                                          -->
<!-- ============================================================ -->
<node TEXT="B. Rodar SQLs no SQL Editor" POSITION="right" ID="ID_B" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="bookmark"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body>
<p><b>Onde:</b> dashboard Supabase &gt; SQL Editor</p>
<p><b>Duracao:</b> ~1 min</p>
<p>Para cada SQL: New query &gt; cole conteudo &gt; Run (Ctrl+Enter)</p>
</body></html></richcontent>
<node TEXT="1. sql/001_schema.sql -&gt; Run"/>
<node TEXT="2. sql/002_seed_royal_enfield.sql -&gt; Run"/>
<node TEXT="3. sql/validacao_fase1.sql -&gt; Run">
<icon BUILTIN="button_ok"/>
<richcontent TYPE="NOTE"><html><body>
<p>Veja a aba <b>Output</b> ou <b>Messages</b> do painel Results.</p>
<p>Esperado: RESULTADO: TODAS AS VALIDACOES PASSARAM (OK)</p>
</body></html></richcontent>
</node>
</node>

<!-- ============================================================ -->
<!-- PASSO C - COPIAR CREDENCIAIS                                  -->
<!-- ============================================================ -->
<node TEXT="C. Copiar credenciais da API" POSITION="right" ID="ID_C" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="password"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body>
<p><b>Onde:</b> dashboard Supabase &gt; Settings (engrenagem) &gt; API</p>
<p>Anote os 3 valores em algum lugar temporario (vai colar no .env)</p>
</body></html></richcontent>
<node TEXT="Project URL (ex: https://abc123.supabase.co)"/>
<node TEXT="anon / public key (eyJhbG...)"/>
<node TEXT="service_role / secret key (eyJhbG...)">
<icon BUILTIN="messagebox_warning"/>
<richcontent TYPE="NOTE"><html><body><p>Chave administrativa - NUNCA commitar no Git!</p></body></html></richcontent>
</node>
</node>

<!-- ============================================================ -->
<!-- PASSO D - CONFIGURAR .env                                     -->
<!-- ============================================================ -->
<node TEXT="D. Configurar .env" POSITION="left" ID="ID_D" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="edit"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body>
<p><b>Onde:</b> WSL, na raiz do projeto</p>
<p>Salvar no nano: Ctrl+O -&gt; Enter -&gt; Ctrl+X</p>
</body></html></richcontent>
<node TEXT="cp .env.exemplo .env" ID="ID_D1"><font ITALIC="true"/></node>
<node TEXT="nano .env" ID="ID_D2"><font ITALIC="true"/></node>
<node TEXT="Substituir os 3 valores do Passo C">
<node TEXT="SUPABASE_URL=https://...supabase.co"/>
<node TEXT="SUPABASE_ANON_KEY=eyJhbG..."/>
<node TEXT="SUPABASE_SERVICE_KEY=eyJhbG..."/>
</node>
</node>

<!-- ============================================================ -->
<!-- PASSO E - CONFIGURAR usuarios.json                            -->
<!-- ============================================================ -->
<node TEXT="E. Configurar usuarios.json" POSITION="left" ID="ID_E" COLOR="#0066cc">
<font BOLD="true" SIZE="13"/>
<icon BUILTIN="edit"/>
<edge COLOR="#0066cc"/>
<richcontent TYPE="NOTE"><html><body>
<p><b>Onde:</b> WSL, na raiz do projeto</p>
<p>Edite com seus usuarios reais (admin + mecanicos).</p>
<p>Apague os exemplos mecanico1@ e mecanico2@ se nao for usar.</p>
</body></html></richcontent>
<node TEXT="cp usuarios.json.exemplo usuarios.json" ID="ID_E1"><font ITALIC="true"/></node>
<node TEXT="nano usuarios.json" ID="ID_E2"><font ITALIC="true"/></node>
<node TEXT="Minimo: 1 usuario admin (voce mesmo)"/>
</node>

<!-- ============================================================ -->
<!-- PASSO F - SETUP AUTOMATIZADO                                  -->
<!-- ============================================================ -->
<node TEXT="F. Setup automatizado" POSITION="left" ID="ID_F" COLOR="#cc0000">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="gohome"/>
<edge COLOR="#cc0000" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p><b>Cria automaticamente:</b></p>
<p>- Bucket 'inspecoes' no Storage (privado, max 10MB, jpg/png/webp/pdf)</p>
<p>- Usuarios listados em usuarios.json (via Admin API)</p>
<p><b>Idempotente:</b> pode rodar varias vezes sem efeito colateral.</p>
</body></html></richcontent>
<node TEXT="python3 scripts/setup_fase1.py" ID="ID_F1"><font BOLD="true" ITALIC="true"/></node>
</node>

<!-- ============================================================ -->
<!-- PASSO G - VALIDACAO                                           -->
<!-- ============================================================ -->
<node TEXT="G. Validacao automatizada" POSITION="left" ID="ID_G" COLOR="#cc0000">
<font BOLD="true" SIZE="14"/>
<icon BUILTIN="button_ok"/>
<edge COLOR="#cc0000" WIDTH="2"/>
<richcontent TYPE="NOTE"><html><body>
<p><b>Esperado: 8/8 testes passando.</b></p>
<p>Valida: contagens (10/70/1300), views, bucket privado, usuarios cadastrados.</p>
<p>Usa SERVICE_KEY para bypassar RLS nas contagens administrativas.</p>
</body></html></richcontent>
<node TEXT="python3 tests/test_fase1.py --remote" ID="ID_G1"><font BOLD="true" ITALIC="true"/></node>
</node>

<!-- ============================================================ -->
<!-- PASSO H - VALIDACAO VISUAL (OPCIONAL)                         -->
<!-- ============================================================ -->
<node TEXT="H. Validacao visual no celular (opcional)" POSITION="right" ID="ID_H" COLOR="#666666">
<font BOLD="true" SIZE="12" ITALIC="true"/>
<icon BUILTIN="phone_mobile"/>
<edge COLOR="#666666"/>
<richcontent TYPE="NOTE"><html><body>
<p>Confirma que o PWA realmente abre e conecta no Supabase.</p>
<p>PC e celular precisam estar na mesma Wi-Fi.</p>
<p>Para descobrir o IP do PC: ipconfig no PowerShell -&gt; Endereco IPv4.</p>
</body></html></richcontent>
<node TEXT="1. Atualizar src/supabase-client.js">
<node TEXT="nano src/supabase-client.js" ID="ID_H1"><font ITALIC="true"/></node>
<node TEXT="Trocar URL e ANON_KEY (mesmos do .env, mas ANON, NAO service)"/>
</node>
<node TEXT="2. Servir o app">
<node TEXT="python3 -m http.server 8000" ID="ID_H2"><font ITALIC="true"/></node>
</node>
<node TEXT="3. Abrir no celular">
<node TEXT="http://IP-DO-PC:8000" ID="ID_H3"><font ITALIC="true"/></node>
<node TEXT="Login com email/senha do usuarios.json"/>
<node TEXT="Dashboard deve abrir com stats zeradas"/>
</node>
</node>

</node>
</map>
