# revisao-moto

**PWA de checklist de revisoes para motocicletas Royal Enfield.**

Aplicativo web progressivo (PWA) para mecanicos executarem inspecoes completas de motos, capturando fotos, coletando assinaturas digitais e gerando relatorios em PDF com hash de integridade.

- **Deploy:** https://mariocezar1971.github.io/revisao-moto/
- **Stack:** HTML/JS vanilla + Tailwind CDN + Supabase (sem build step)

---

## Estrutura

```
revisao-moto/
├── index.html                    # Login + dashboard
├── admin.html                    # CRUD de motos (Fase 2)
├── inspecao.html                 # Execucao de checklist (Fases 3+4)
├── historico.html                # Historico e relatorios (Fase 5)
├── manifest.json                 # PWA
├── service-worker.js             # Cache offline
├── src/
│   ├── supabase-client.js
│   ├── auth.js
│   ├── camera.js
│   ├── inspecao.js
│   ├── assinatura.js
│   ├── pdf.js
│   └── relatorios.js
├── css/styles.css
├── sql/                          # Migrations e validacoes
├── scripts/setup_fase1.py
├── tests/                        # Suite Python (Postgres efemero)
└── assets/                       # Icones PWA
```

---

## Setup

### Pre-requisitos

- WSL Ubuntu (Windows) ou Linux nativo
- PostgreSQL 16+, Python 3, Node.js, unzip, git

### Setup automatizado (recomendado)

```bash
cd revisao-moto
chmod +x orquestrador_fase0.sh
./orquestrador_fase0.sh
```

### Setup manual

```bash
sudo apt install -y postgresql postgresql-contrib python3 nodejs unzip
chmod +x tests/run_tests.sh
./tests/run_tests.sh
```

Depois: configurar `.env` e `usuarios.json`, rodar `scripts/setup_fase1.py`, aplicar migrations no Supabase (SQL Editor).

---

## Roadmap

| Fase | Descricao | Status | Testes |
|---|---|---|---|
| **Fase 0** | Setup: schema, seed, PWA, login | OK | 111 |
| **Fase 1** | Catalogo, bucket, usuarios | OK | 24 |
| **Fase 2** | CRUD de motos, soft delete | OK | 61 |
| **Fase 3** | Execucao do checklist, fotos, autosave | OK | 69 |
| **Fase 4** | Assinaturas digitais e PDF assinado | OK | 83 |
| **Fase 5** | Historico, filtros, CSV, relatorios | OK | 80 |
| **Fase 6** | Offline completo (IndexedDB, sync queue) | OK | 83 |
| **Fase 7** | Polimento: icones, onboarding, QR, specs, notifs, dark mode, i18n | OK | 122 |
| **Fase 8 (P1)** | Operacao real: medicao numerica, queixa do cliente, itens avulsos, orcamento | OK | 145 |
| **Fase 9 (P2)** | Recebimento/avarias, recomendacoes, fotos antes/depois, lembretes ao cliente, numero de OS | OK | 136 |
| **Fase 10 (P3)** | Comparacao entre revisoes, teste de rodagem, garantia, torque aplicado, revisao rapida | OK | 206 |

**Total: 1191 testes automatizados** via `./tests/run_tests.sh` (fases 0 a 10 + sessão).

### Correções transversais

| Item | O que resolve |
|---|---|
| Widget de status cobria o "Sair" | O indicador online/offline era fixo no canto superior direito com `z-index: 60` — exatamente sobre o botão "Sair" do cabeçalho. Um botão coberto não existe para quem usa, e o app passou semanas parecendo não ter logout. Movido para o canto inferior esquerdo, com `z-index` abaixo dos modais e um teste que trava os quatro cantos |
| Menu de sessão (`src/sessao.js`) | O `logout()` existia desde a Fase 0, mas o botão "Sair" só estava no dashboard — nas outras 8 telas autenticadas não havia saída. Agora o menu é injetado em todas, e antes de encerrar confere a fila offline e as fotos pendentes: sair com trabalho não sincronizado passa a pedir confirmação. Tema, idioma e a flag de onboarding sobrevivem ao logout; a fila offline nunca é apagada |

### Fase 10 (P3) em detalhe

| Item | O que resolve |
|---|---|
| Comparacao entre revisoes | O historico mostrava cada revisao isolada. Agora mostra a diferenca item a item (pastilha 4,0 -> 2,8 mm) casando por `chave_medicao`, com grafico de evolucao. A tendencia respeita o tipo do item: faixa (bom eh o meio), desgaste (cair eh piorar) e teto (subir eh piorar) |
| Teste de rodagem estruturado | Era campo de texto livre. Virou checklist de 14 itens com km inicial/final, condicao de pista e responsavel, e o encerramento eh bloqueado com item obrigatorio em branco |
| Garantia | O app cobrava sempre. Agora ha 4 tipos de cobranca, janela de 90 dias aberta ao finalizar (CDC art. 26) somente para trabalho pago ou de garantia de fabrica, e aviso de cobertura na abertura da inspecao |
| Torque efetivamente aplicado | A tela de especificacoes dizia qual torque usar, mas nada registrava o aplicado. Agora cada ponto eh registrado e avaliado contra a spec com tolerancia de 10%, e sai no PDF |
| Revisao rapida vs completa | Abrir 22 itens para uma troca de oleo eh atrito. Tres modos: completa, rapida (so os itens do servico, de um catalogo de 6) e avulsa |

**Bug corrigido nesta fase:** `vw_checklist_completo` expoe a chave como `item_id`, mas
`renderItem()`, `marcarStatus()` e o mapa de respostas usavam `item.id`, que era `undefined`.
Os botoes OK/N-OK/N/A chamavam `marcarStatus(undefined)` e o checklist nao salvava.
Valia para todas as versoes anteriores. Corrigido em `carregarItensDaRevisao()`, com grupo
de regressao dedicado em `tests/test_fase10.py`.

### Fase 8 (P1) em detalhe

| Item | O que resolve |
|---|---|
| Medicao numerica com limites | `valor_medido` era texto livre. Agora o app compara com limite de servico e pinta verde/amarelo/vermelho, e calcula a previsao de troca comparando com a revisao anterior |
| Queixa do cliente | O motivo real da visita ("barulho ao frear") nao estava em checklist nenhum. Agora abre a inspecao e abre o PDF |
| Itens avulsos | O checklist eh fixo por revisao. Agora o mecanico registra achados fora da lista na mesma inspecao |
| Pecas e orcamento | Pecas, mao de obra, total no PDF e assinatura de aprovacao previa separada da de conclusao (CDC art. 40) |

Chave de projeto: `itens_checklist.chave_medicao` identifica o mesmo item fisico entre revisoes.
A descricao muda ("Inspecao de pastilhas dianteiras" no 500 km vira "Pastilhas dianteiras - espessura"
no 5.000 km+), entao casar por texto quebraria o calculo de desgaste.

---

## Uso

Apos deploy no **GitHub Pages** e configuracao do **Supabase**:

1. Acesse a URL no celular
2. Login com credenciais de `usuarios.json`
3. Cadastrar Motos -> nova moto
4. Nova Inspecao -> escolhe moto -> executa checklist -> assinaturas -> PDF
5. Historico -> timeline, filtros, CSV, relatorios

## Tecnologias

- **Frontend:** Vanilla JS + Tailwind CSS (CDN)
- **Backend:** Supabase (Postgres + Auth + Storage + RPC)
- **PDF:** jsPDF, hash SHA-256 via Web Crypto
- **PWA:** Service Worker network-first
- **Testes:** Python + Postgres efemero

## Licenca

MIT
