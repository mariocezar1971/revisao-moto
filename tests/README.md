# Testes da Fase 0

Suite de validação automatizada para a Fase 0 do projeto `revisao-moto`.

## O que é testado

**110 testes em 9 grupos**, todos validados em última execução:

| # | Grupo | Testes | O que valida |
|---|---|---|---|
| 1 | Estrutura de pastas | 15 | Todos os arquivos e diretórios obrigatórios existem |
| 2 | Schema SQL (real) | 19 | Tabelas, views, triggers, RLS, índices criados no Postgres real |
| 3 | Seed Royal Enfield | 25 | 10 modelos, 70 revisões, **1300 itens**, contagens por km |
| 4 | Views funcionais | 3 | `vw_checklist_completo` e `vw_motos_status` retornam dados |
| 5 | Trigger atualizado_em | 2 | Campo `atualizado_em` é alterado em UPDATE |
| 6 | PWA manifest | 13 | JSON válido, campos obrigatórios, ícones acessíveis |
| 7 | Service Worker | 7 | JS válido (node --check), listeners, estratégia de cache |
| 8 | HTML/JS/CSS | 20 | DOCTYPE, viewport, referências de CDN, funções JS, sintaxe |
| 9 | README | 9 | Seções obrigatórias presentes |

## Pré-requisitos

```bash
# PostgreSQL (não precisa ser servidor permanente, o script sobe um efêmero)
sudo apt-get install postgresql postgresql-contrib

# Python 3 (já vem no Ubuntu)
python3 --version

# Node.js (usado apenas para validação sintática de JS)
sudo apt-get install nodejs
```

## Como rodar

### Opção 1: Script automatizado (recomendado)

```bash
cd revisao-moto
./tests/run_tests.sh
```

O script:
1. Cria um cluster Postgres efêmero em `/tmp`
2. Sobe o servidor numa porta livre (5433 por padrão)
3. Executa toda a suite
4. Derruba o servidor e limpa os arquivos temporários

### Opção 2: Rodar manualmente contra um Postgres existente

```bash
# Se voce ja tem um Postgres rodando:
export PGHOST=localhost
export PGPORT=5432
export PGUSER=postgres
export PGDATABASE=revisao_moto_test

python3 tests/test_fase0.py
```

## Output esperado

```
======================================================================
  RESUMO
======================================================================
  Total : 110
  Passou: 110

  Sucesso: 100.0%
```

## Quando rodar

- **Antes de cada commit** que toca em `sql/`, arquivos da raiz, ou JS
- **Após editar o seed** (para garantir que contagens batem)
- **Antes de cada deploy** no GitHub Pages
- Como **pre-push hook** opcionalmente:

```bash
# .git/hooks/pre-push
#!/bin/bash
./tests/run_tests.sh || exit 1
```

## O que NÃO é testado (limitações conhecidas)

Estes itens precisam de validação manual ou ambiente real:

- **Login real com Supabase** — precisa de URL/key reais; pode ser mockado em fase futura
- **Service Worker em runtime** — sintaxe é validada, mas comportamento de cache só num navegador real (DevTools > Application > Service Workers)
- **PWA installability** — testar com Lighthouse no Chrome após deploy
- **Foto via getUserMedia** — só no celular (Fase 3)
- **PDF gerado** — só na Fase 4
- **Comportamento offline real** — só simulando com DevTools > Network > Offline

Para esses, mantenha um checklist de validação manual após cada deploy:

```
[ ] Login funciona no celular
[ ] Dashboard carrega
[ ] Service Worker registra (DevTools)
[ ] Add to Home Screen funciona (iOS e Android)
[ ] Manifest é detectado (Lighthouse > PWA)
[ ] Modo offline mostra banner
```

## Quando adicionar testes novos

A cada fase nova, **adicione um arquivo correspondente**:

- `tests/test_fase2.py` — quando implementar CRUD de motos
- `tests/test_fase3.py` — quando implementar execução do checklist
- `tests/test_fase4.py` — quando implementar PDF e assinatura
- ...

O padrão é o mesmo: cabeçalho + funções `testar_X()` + `resumo()`.

## Histórico de execuções

Última execução: `tests/relatorio_execucao.txt` (sobrescrita a cada run).
