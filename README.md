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
| **Fase 0** | Setup: schema, seed, PWA, login | OK | 110 |
| **Fase 1** | Catalogo, bucket, usuarios | OK | 24 |
| **Fase 2** | CRUD de motos, soft delete | OK | 61 |
| **Fase 3** | Execucao do checklist, fotos, autosave | OK | 69 |
| **Fase 4** | Assinaturas digitais e PDF assinado | OK | 83 |
| **Fase 5** | Historico, filtros, CSV, relatorios | OK | 80 |
| **Fase 6** | Offline completo (IndexedDB, sync queue) | OK | 83 |
| **Fase 7** | Polimento: icones, onboarding, QR, specs, notifs, dark mode, i18n | OK | 122 |

**Total: 633 testes automatizados** via `./tests/run_tests.sh`.

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
