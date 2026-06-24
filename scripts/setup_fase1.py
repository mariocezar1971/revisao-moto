#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Setup automatico da Fase 1
========================================================================
Cria:
  - Bucket 'inspecoes' no Supabase Storage (privado, com URLs assinadas)
  - Usuarios mecanicos a partir de usuarios.json

Pre-requisitos:
  1. Schema e seed ja aplicados no Supabase (SQL Editor)
  2. Arquivo .env com SUPABASE_URL e SUPABASE_SERVICE_KEY preenchidos
  3. Arquivo usuarios.json com lista de usuarios a criar

Uso:
  python3 scripts/setup_fase1.py

Sem dependencias externas - usa apenas urllib da stdlib.
========================================================================
"""

import json
import os
import sys
import urllib.request
import urllib.error
from pathlib import Path

# Cores ANSI
class Cor:
    VERDE   = '\033[92m'
    VERMELHO= '\033[91m'
    AMARELO = '\033[93m'
    AZUL    = '\033[94m'
    NEGRITO = '\033[1m'
    RESET   = '\033[0m'

RAIZ = Path(__file__).parent.parent.resolve()

# ============================================================
# CONFIG: carrega .env
# ============================================================
def carregar_env():
    """Le o arquivo .env e retorna dict com as variaveis."""
    env_file = RAIZ / '.env'
    if not env_file.exists():
        print(f"{Cor.VERMELHO}ERRO: arquivo .env nao encontrado em {env_file}{Cor.RESET}")
        print(f"\nCopie .env.exemplo para .env e preencha:")
        print(f"  cp .env.exemplo .env")
        sys.exit(1)

    config = {}
    for linha in env_file.read_text().splitlines():
        linha = linha.strip()
        if not linha or linha.startswith('#') or '=' not in linha:
            continue
        chave, valor = linha.split('=', 1)
        config[chave.strip()] = valor.strip().strip('"').strip("'")

    obrigatorios = ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY']
    faltando = [k for k in obrigatorios if not config.get(k) or 'SEU_' in config.get(k, '')]
    if faltando:
        print(f"{Cor.VERMELHO}ERRO: variaveis nao preenchidas em .env: {faltando}{Cor.RESET}")
        sys.exit(1)

    return config

# ============================================================
# HTTP HELPER
# ============================================================
def request_api(url, method='GET', headers=None, data=None):
    """Faz request HTTP e retorna (status_code, response_json)."""
    req = urllib.request.Request(url, method=method)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    if data is not None:
        body = json.dumps(data).encode('utf-8')
        req.add_header('Content-Type', 'application/json')
        req.data = body
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            corpo = resp.read().decode('utf-8')
            return resp.status, (json.loads(corpo) if corpo else {})
    except urllib.error.HTTPError as e:
        corpo = e.read().decode('utf-8')
        try:
            return e.code, json.loads(corpo)
        except json.JSONDecodeError:
            return e.code, {'message': corpo}
    except urllib.error.URLError as e:
        return 0, {'message': str(e)}

# ============================================================
# ETAPA 1: BUCKET DE STORAGE
# ============================================================
def criar_bucket(config):
    """Cria o bucket 'inspecoes' no Supabase Storage."""
    print(f"\n{Cor.NEGRITO}[1/2] Criando bucket 'inspecoes'...{Cor.RESET}")

    url = f"{config['SUPABASE_URL']}/storage/v1/bucket"
    headers = {
        'Authorization': f"Bearer {config['SUPABASE_SERVICE_KEY']}",
        'apikey': config['SUPABASE_SERVICE_KEY']
    }
    body = {
        'id': 'inspecoes',
        'name': 'inspecoes',
        'public': False,
        # Limite por arquivo (10MB - suficiente para fotos comprimidas)
        'file_size_limit': 10485760,
        'allowed_mime_types': ['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
    }

    status, resp = request_api(url, 'POST', headers, body)

    if status in (200, 201):
        print(f"  {Cor.VERDE}OK{Cor.RESET}   Bucket 'inspecoes' criado (privado, max 10MB/arquivo)")
        return True
    elif status == 409 or 'already exists' in str(resp).lower() or 'duplicate' in str(resp).lower():
        print(f"  {Cor.AMARELO}--{Cor.RESET}   Bucket 'inspecoes' ja existia (ok)")
        return True
    else:
        print(f"  {Cor.VERMELHO}FAIL{Cor.RESET} Erro {status}: {resp.get('message', resp)}")
        return False

# ============================================================
# ETAPA 2: USUARIOS MECANICOS
# ============================================================
def criar_usuarios(config):
    """Cria usuarios mecanicos a partir de usuarios.json."""
    print(f"\n{Cor.NEGRITO}[2/2] Criando usuarios mecanicos...{Cor.RESET}")

    arquivo = RAIZ / 'usuarios.json'
    if not arquivo.exists():
        print(f"  {Cor.AMARELO}AVISO{Cor.RESET} usuarios.json nao existe")
        print(f"  Copie usuarios.json.exemplo para usuarios.json e edite com seus usuarios")
        return False

    try:
        usuarios = json.loads(arquivo.read_text(encoding='utf-8'))
    except json.JSONDecodeError as e:
        print(f"  {Cor.VERMELHO}FAIL{Cor.RESET} usuarios.json invalido: {e}")
        return False

    if not isinstance(usuarios, list) or not usuarios:
        print(f"  {Cor.VERMELHO}FAIL{Cor.RESET} usuarios.json deve ser uma lista nao-vazia")
        return False

    url = f"{config['SUPABASE_URL']}/auth/v1/admin/users"
    headers = {
        'Authorization': f"Bearer {config['SUPABASE_SERVICE_KEY']}",
        'apikey': config['SUPABASE_SERVICE_KEY']
    }

    sucessos = 0
    falhas = 0

    for u in usuarios:
        if 'email' not in u or 'senha' not in u:
            print(f"  {Cor.VERMELHO}FAIL{Cor.RESET} usuario sem email/senha: {u}")
            falhas += 1
            continue

        body = {
            'email': u['email'],
            'password': u['senha'],
            'email_confirm': True,
            'user_metadata': {
                'nome_completo': u.get('nome_completo', ''),
                'perfil': u.get('perfil', 'mecanico'),
                'telefone': u.get('telefone', '')
            }
        }

        status, resp = request_api(url, 'POST', headers, body)

        if status in (200, 201):
            print(f"  {Cor.VERDE}OK{Cor.RESET}   {u['email']} ({u.get('perfil', 'mecanico')})")
            sucessos += 1
        elif 'already' in str(resp).lower() or 'registered' in str(resp).lower() or status == 422:
            print(f"  {Cor.AMARELO}--{Cor.RESET}   {u['email']} ja existia (ok)")
            sucessos += 1
        else:
            print(f"  {Cor.VERMELHO}FAIL{Cor.RESET} {u['email']}: {resp.get('message', resp)}")
            falhas += 1

    return falhas == 0

# ============================================================
# MAIN
# ============================================================
def main():
    print(f"{Cor.AZUL}{Cor.NEGRITO}===== SETUP FASE 1 - Bucket + Usuarios ====={Cor.RESET}")

    config = carregar_env()
    print(f"  Supabase: {config['SUPABASE_URL']}")

    ok_bucket = criar_bucket(config)
    ok_usuarios = criar_usuarios(config)

    print(f"\n{Cor.NEGRITO}===== RESULTADO ====={Cor.RESET}")
    if ok_bucket and ok_usuarios:
        print(f"  {Cor.VERDE}{Cor.NEGRITO}Setup Fase 1 concluido com sucesso!{Cor.RESET}")
        print(f"\n  Proximo passo: rode os testes para validar tudo:")
        print(f"  {Cor.AZUL}python3 tests/test_fase1.py{Cor.RESET}")
        return 0
    else:
        print(f"  {Cor.VERMELHO}{Cor.NEGRITO}Setup parcial - verifique os erros acima{Cor.RESET}")
        return 1

if __name__ == '__main__':
    sys.exit(main())
