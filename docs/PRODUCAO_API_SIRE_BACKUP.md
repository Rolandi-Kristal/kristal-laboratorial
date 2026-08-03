# Produção: API, CDM SIRE e Backup

## Chave API

O portal exige `KRISTAL_API_KEY` nas rotas técnicas protegidas. A chave é gerada no servidor pelo script:

```powershell
D:\kristal_laboratorial\portal_web\gerar_segredos_portal.py
```

Ela fica somente em:

```text
D:\kristal_laboratorial\portal_web\.env
D:\kristal_laboratorial\portal_web\SEGREDOS_INICIAIS_ADMIN.txt
```

Esses arquivos não são incluídos no ZIP de distribuição.

## Rotas técnicas reais

Todas as rotas abaixo exigem cabeçalho:

```text
X-API-Key: valor_do_KRISTAL_API_KEY
```

- `GET /api/server/status`: status técnico do servidor.
- `POST /api/server/backup`: backup real do banco SQLite do portal, com SHA-256.
- `POST /api/sire/cdm/automatico`: envio real de CDM ao SIRE via `PostCDM`.

## CDM automático para SIRE

A rota `/api/sire/cdm/automatico` não simula envio. Ela chama o endpoint configurado em `KRISTAL_SIRE_BASE_URL` usando autenticação Basic com:

```text
KRISTAL_SIRE_USERNAME
KRISTAL_SIRE_PASSWORD
```

Se as credenciais não existirem, a rota retorna erro `503`. Se o SIRE recusar, a resposta é registrada como recusada e mantém hash de integridade.

Campos esperados:

```text
beneficiario_id
plano_interno_id
percentual_desconto
procedimentos_json
paciente_id opcional
pedido_id opcional
```

`procedimentos_json` deve conter lista JSON real com `Codigo_CBHPM`, `Codigo_SubGrupoCBHMP`, `ValorUnitario` e `Quantidade`.

## Backup automático

Backup manual via API:

```powershell
D:\kristal_laboratorial\portal_web\executar_backup_servidor.ps1
```

Instalação do backup automático diário no Windows:

```powershell
powershell -ExecutionPolicy Bypass -File D:\kristal_laboratorial\portal_web\instalar_backup_automatico_windows.ps1
```

A tarefa criada é `KRISTAL_LABORATORIAL_BACKUP_AUTOMATICO`, programada para 23:30.
