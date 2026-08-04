# KRISTAL LABORATORIAL - Segurança de Produção

## Chave API

O servidor exige `KRISTAL_API_KEY` em `portal_web\.env` para rotas técnicas protegidas.

Header obrigatório:

```http
X-API-Key: valor_configurado_em_KRISTAL_API_KEY
```

Rota validada:

```http
GET /api/server/status
```

Sem chave ou com chave inválida, a rota retorna `401`.

## Segredos fortes

O arquivo `portal_web\.env` foi endurecido com:

- `KRISTAL_SECRET_KEY` forte para assinatura dos tokens.
- `KRISTAL_SUPERUSER_PASSWORD` forte para login administrativo inicial.
- `KRISTAL_API_KEY` válida para integração.

As credenciais iniciais foram gravadas em `portal_web\SEGREDOS_INICIAIS_ADMIN.txt`. Esse arquivo deve ficar restrito ao responsável autorizado.

## Assinatura digital

O executável Windows foi assinado com certificado de assinatura de código instalado no Windows.

Validação:

```powershell
Get-AuthenticodeSignature D:\kristal_laboratorial\build\windows\x64\runner\Release\kristal_laboratorial.exe
```

Status esperado: `Valid`.

Para reassinar após recompilar:

```powershell
powershell -ExecutionPolicy Bypass -File D:\kristal_laboratorial\assinar_release.ps1
```

## HASH automática

Após salvar exame/laudo no portal, o servidor gera `laudo_hash` SHA-256 automaticamente e grava o horário em `hash_criado_em`.

O hash é retornado na criação do exame e incluído nas exportações.

## Criptografia

O sistema mantém snapshots/exportações operacionais criptografados pelos serviços locais existentes e usa PBKDF2-HMAC-SHA256 para senhas e HMAC-SHA256 para tokens do portal.

## Blindagem operacional

O sistema não deve simular integração. Quando credencial, rota, driver, arquivo ou permissão oficial não estiver configurado, a operação deve retornar erro rastreável, sem criar sucesso fictício.
