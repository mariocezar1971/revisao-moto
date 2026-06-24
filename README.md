# Revisão Moto

PWA para mecânicos conferirem itens de checklist em cada revisão de motocicletas Royal Enfield, com fotos, assinatura digital e PDF gerado automaticamente.

Stack: HTML/CSS/JS vanilla + Tailwind CDN + Supabase + GitHub Pages.
Padrão: mesmo da Fase 0 do RideLink (sem build step, sem npm install).

---

## Status atual

**Fase 0 — concluída e validada** ✅
**Fase 1 — pronta para deploy** ✅

- 21 arquivos, ~200 KB
- Schema SQL com 6 tabelas, 2 views, triggers e RLS
- Catálogo populado: **10 modelos, 70 revisões, 1300 itens** de checklist
- Login + dashboard funcionando com Supabase
- Service Worker e PWA manifest prontos para instalação no celular
- **Fase 1** (cloud setup): script `setup_fase1.py` cria bucket e usuários via Admin API
- Suite automatizada: **110 + 24 = 134/134 testes passando** (rode `./tests/run_tests.sh`)
- Roadmap completo em Freeplane (`Roadmap.mm`)

**Próxima fase:** Fase 2 — CRUD de Motos.

---

## Estrutura

```
revisao-moto/
├── index.html                      # Login + dashboard (Fase 0 - implementado)
├── inspecao.html                   # Execução do checklist (Fase 3)
├── historico.html                  # Histórico por moto (Fase 5)
├── admin.html                      # CRUD de motos (Fase 2)
├── manifest.json                   # PWA manifest
├── service-worker.js               # Cache offline
├── Roadmap.mm                      # Roadmap em Freeplane (250 nodes)
├── .gitignore
├── /src
│   ├── supabase-client.js          # Inicialização do client
│   ├── auth.js                     # Login/logout
│   ├── inspecao.js                 # (Fase 3) lógica do checklist
│   ├── camera.js                   # (Fase 3) captura de foto
│   ├── assinatura.js               # (Fase 4) canvas para assinatura
│   ├── pdf.js                      # (Fase 4) geração de PDF
│   └── db-local.js                 # (Fase 6) IndexedDB offline
├── /css
│   └── styles.css                  # Customizações além do Tailwind
├── /assets
│   ├── icon-192.png
│   └── icon-512.png
├── /sql
│   ├── 001_schema.sql              # DDL completo (6 tabelas, 2 views, RLS)
│   ├── 002_seed_royal_enfield.sql  # Catálogo: 10 modelos, 70 revisões, 1300 itens
│   └── validacao_fase1.sql         # Asserts inline para colar no SQL Editor
├── /scripts
│   └── setup_fase1.py              # Cria bucket + usuários via Admin API
├── /tests
│   ├── test_fase0.py               # Suite Fase 0 (110 testes)
│   ├── test_fase1.py               # Suite Fase 1 (24 testes, modo local/remote)
│   ├── run_tests.sh                # Runner com Postgres efêmero
│   ├── README.md                   # Documentação dos testes
│   └── relatorio_execucao.txt      # Último output (regenerado a cada run)
├── .env.exemplo                    # Template de credenciais Supabase
├── usuarios.json.exemplo           # Template de usuários mecânicos
└── README.md
```

---

## Execução da Fase 1 (cloud setup)

Após a Fase 0 (arquivos prontos), a Fase 1 acontece no Supabase real:

### Passo 1 — Schema e seed (no SQL Editor do Supabase)

1. Crie projeto novo em [supabase.com](https://supabase.com)
2. SQL Editor → New query → cole `sql/001_schema.sql` → Run
3. New query → cole `sql/002_seed_royal_enfield.sql` → Run
4. (Validação rápida) New query → cole `sql/validacao_fase1.sql` → Run
   - Output esperado: `RESULTADO: TODAS AS VALIDACOES PASSARAM (OK)` no log

### Passo 2 — Bucket e usuários (script automatizado)

```bash
# 1. Configure credenciais
cp .env.exemplo .env
# Edite .env com SUPABASE_URL, ANON_KEY, SERVICE_KEY (Settings > API)

# 2. Configure lista de usuários
cp usuarios.json.exemplo usuarios.json
# Edite usuarios.json com seus mecânicos reais

# 3. Rode setup (cria bucket + usuários via Admin API)
python3 scripts/setup_fase1.py
```

### Passo 3 — Validação completa contra o Supabase real

```bash
python3 tests/test_fase1.py --remote
```

Valida contagens via REST, views acessíveis, bucket privado existente e usuários cadastrados.

---

## Setup inicial

### 1. Supabase

1. Crie projeto novo no [supabase.com](https://supabase.com) (Free tier serve).
2. No SQL Editor, rode `sql/001_schema.sql` (cria tabelas, views, políticas).
3. Em seguida, rode `sql/002_seed_royal_enfield.sql` (popula catálogo).
4. Em Storage, crie um bucket público chamado `inspecoes` (para fotos e PDFs).
5. Em Authentication > Users, crie manualmente os usuários mecânicos (email + senha).

### 2. Configurar o cliente

Edite `src/supabase-client.js`:

```js
const SUPABASE_URL = 'https://SEU_PROJETO.supabase.co';
const SUPABASE_ANON_KEY = 'eyJ...';
```

Pegue os valores em Project Settings > API.

### 3. Deploy no GitHub Pages

```bash
cd revisao-moto
git init
git add .
git commit -m "Fase 0: setup inicial"
git remote add origin git@github.com:mariocezar1971/revisao-moto.git
git push -u origin main
```

No GitHub: Settings > Pages > Source: branch `main`, pasta `/ (root)`. Em ~1 min estará acessível em `https://mariocezar1971.github.io/revisao-moto/`.

### 4. Validar Fase 0

- Acesse a URL no celular
- "Adicionar à tela inicial" (Chrome Android / Safari iOS)
- Faça login com o usuário criado no Supabase
- Dashboard deve carregar com estatísticas (zeradas inicialmente)

---

## Roadmap por fases

### Fase 0 — Setup ✅ (implementado neste pacote)
- [x] Estrutura de pastas
- [x] Schema SQL completo
- [x] Seed Royal Enfield (10 modelos × 7 revisões × 130 itens/modelo)
- [x] index.html com login funcional
- [x] Dashboard com estatísticas e últimas inspeções
- [x] Service Worker básico (cache app shell)
- [x] PWA manifest
- [x] Ícones placeholder
- [x] **Suite de testes automatizada (110 testes, 100% passando)** — rode `./tests/run_tests.sh`

### Fase 1 — Catálogo no banco ✅ (populado pelo seed)
- [x] Tabela `modelos` com 10 modelos RE
- [x] Tabela `revisoes` com 70 revisões (10 × 7)
- [x] Tabela `itens_checklist` com 1300 itens
- [x] View `vw_checklist_completo` para leitura facilitada

### Fase 2 — CRUD de motos (próximo)
Arquivo a criar: `admin.html` + lógica embutida.
- [ ] Listar motos cadastradas
- [ ] Cadastrar nova moto (placa, chassi, modelo, ano, proprietário, telefone)
- [ ] Editar moto existente
- [ ] Filtrar por placa/proprietário
- [ ] Atualizar km atual

### Fase 3 — Execução do checklist (CORE)
Arquivo a criar: `inspecao.html` + `src/inspecao.js` + `src/camera.js`.
- [ ] Seleção da moto (autocomplete por placa)
- [ ] Detecção automática da revisão prevista pelo km
- [ ] Carregamento dinâmico dos itens daquela revisão
- [ ] Renderização agrupada por categoria
- [ ] Para cada item: botões OK / N-OK / N-A
- [ ] Campo observação por item
- [ ] Captura de foto via `getUserMedia` ou `<input capture>`
- [ ] Upload da foto para Storage Supabase
- [ ] Campo de valor medido (quando `exige_medicao = true`)
- [ ] Autosave a cada interação
- [ ] Indicador de progresso (X de Y itens)
- [ ] Bloqueio de finalização se há obrigatório pendente

### Fase 4 — Assinatura + PDF
Arquivos a criar: `src/assinatura.js` + `src/pdf.js`.
- [ ] Canvas HTML5 para assinatura do mecânico
- [ ] Canvas para assinatura do cliente
- [ ] Validação: ambas obrigatórias para finalizar
- [ ] Geração de PDF (jsPDF) com:
  - Cabeçalho (logo, oficina, data)
  - Dados da moto e proprietário
  - Tabela de itens com status e observações
  - Fotos embarcadas (thumbnails)
  - Assinaturas
  - Hash SHA-256 do conteúdo (rodapé)
- [ ] Upload do PDF para Storage
- [ ] Botão "Compartilhar via WhatsApp" (Web Share API)

### Fase 5 — Histórico e relatórios
Arquivo a criar: `historico.html`.
- [ ] Lista de motos com última inspeção
- [ ] Detalhe por moto: timeline de revisões
- [ ] Filtros: período, mecânico, status
- [ ] Indicador de "revisão atrasada"
- [ ] Cálculo de próxima revisão prevista (km + tempo)
- [ ] Export CSV das inspeções

### Fase 6 — Offline completo
Arquivos a evoluir: `service-worker.js` + criar `src/db-local.js`.
- [ ] IndexedDB para cache do catálogo (modelos/revisões/itens) no 1º login
- [ ] Fila de upload de fotos para quando conectividade voltar
- [ ] Sincronização de inspeções iniciadas offline
- [ ] Indicador visual de modo offline (já implementado parcialmente)
- [ ] Resolução de conflitos last-write-wins

### Fase 7 — Polimento
- [ ] Ícones reais (substituir placeholders)
- [ ] Onboarding na primeira abertura
- [ ] Atalho QR Code na moto que abre inspeção direto
- [ ] Tela de torques/specs por modelo (consulta rápida)
- [ ] Notificações de revisão próxima (push)

---

## Modelo de dados resumido

```
modelos (10) ─┬─< revisoes (70) ─< itens_checklist (1300)
              │
              └─< motos (N) ─< inspecoes (M) ─< inspecoes_itens
                                                       │
                                                       └─→ Storage (fotos)
```

Veja `sql/001_schema.sql` para o DDL completo.

---

## Decisões de projeto

| Decisão | Justificativa |
|---|---|
| Vanilla JS sem build step | Padrão RideLink, GitHub Pages servindo direto |
| Tailwind via CDN | Setup zero, suficiente para o escopo |
| Supabase | Já em produção no QualityHub e RideLink |
| PWA em vez de app nativo | Instalação sem app store, atualização imediata |
| Sem multi-tenancy/monetização | Uso interno; RLS simples (qualquer auth lê/escreve) |
| Snapshot do nome do mecânico na inspeção | Histórico imutável mesmo se o usuário for removido |
| Hash SHA-256 no PDF | Trilha de auditoria/integridade |

---

## Comandos úteis no Supabase

```sql
-- Quantas inspeções por mecânico no último mês
SELECT mecanico_nome, COUNT(*) 
FROM inspecoes 
WHERE data_inicio >= NOW() - INTERVAL '30 days'
GROUP BY mecanico_nome 
ORDER BY 2 DESC;

-- Itens mais frequentemente marcados como "nao_ok"
SELECT i.descricao, COUNT(*) AS reprovacoes
FROM inspecoes_itens ii
JOIN itens_checklist i ON i.id = ii.item_id
WHERE ii.status = 'nao_ok'
GROUP BY i.descricao
ORDER BY 2 DESC
LIMIT 20;

-- Motos com revisão atrasada (mais de 6 meses sem inspeção)
SELECT m.placa, mo.nome, MAX(i.data_fim) AS ultima
FROM motos m
JOIN modelos mo ON mo.id = m.modelo_id
LEFT JOIN inspecoes i ON i.moto_id = m.id AND i.status = 'finalizada'
GROUP BY m.placa, mo.nome
HAVING MAX(i.data_fim) < NOW() - INTERVAL '6 months' OR MAX(i.data_fim) IS NULL;
```

---

## Próximos passos

Depois de validar a Fase 0 (login + dashboard funcionando), o passo lógico é a **Fase 2 (CRUD de motos)** — é rápida e desbloqueia a Fase 3, que é o coração do app.

Em paralelo, vale rodar as queries de validação do seed (no fim do arquivo `002_seed_royal_enfield.sql`) para confirmar que os 1300 itens foram inseridos corretamente.

---

## Licença e uso

Projeto de uso interno. Sem garantias. Os intervalos e itens de checklist são derivados do manual oficial Royal Enfield e devem ser confirmados na documentação técnica da concessionária para garantia.
