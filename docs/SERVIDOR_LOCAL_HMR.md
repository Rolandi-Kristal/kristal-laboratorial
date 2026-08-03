# Servidor Local KRISTAL LABORATORIAL - Mesmo Servidor da KRISTAL OPERACIONAL

A KRISTAL LABORATORIAL deve rodar no mesmo servidor fisico/logico da KRISTAL OPERACIONAL, usando o mesmo IP de apontamento da rede HMR, mas em pasta propria e porta propria.

## Topologia definida

- Servidor fisico/logico: mesmo servidor da KRISTAL OPERACIONAL.
- IP de apontamento: o mesmo IP ja usado pela KRISTAL OPERACIONAL na rede HMR.
- Pasta da KRISTAL LABORATORIAL: `D:\kristal_laboratorial`.
- Pasta do portal/servidor web: `D:\kristal_laboratorial\portal_web`.
- Porta da KRISTAL LABORATORIAL: `8787`.
- Bind do servidor: `0.0.0.0`, aceitando conexoes pelo IP da rede HMR.

## Regra obrigatoria

O IP pode ser o mesmo da KRISTAL OPERACIONAL. A porta nao pode conflitar.

Se a KRISTAL OPERACIONAL ja usa a porta `8787`, altere a porta da KRISTAL LABORATORIAL no arquivo:

```text
D:\kristal_laboratorial\portal_web\.env
```

Campo:

```env
KRISTAL_PORTAL_PORT=8787
```

## Acesso das estacoes da rede HMR

Substitua `10.4.169.64` pelo IP ja usado no apontamento do servidor operacional:

- Portal do paciente: `http://10.4.169.64:8787`
- Painel administrativo: `http://10.4.169.64:8787/admin.html`
- Health check: `http://10.4.169.64:8787/health`
- Status API protegido: `http://10.4.169.64:8787/api/server/status`

## Inicializacao do servidor KRISTAL LABORATORIAL

Execute no servidor:

```bat
D:\kristal_laboratorial\portal_web\iniciar_servidor_rede_hmr.bat
```

O script usa a pasta propria da KRISTAL LABORATORIAL e nao interfere na pasta da KRISTAL OPERACIONAL.

## Validacao de porta

Antes de iniciar em producao, valide se a porta esta livre:

```powershell
powershell -ExecutionPolicy Bypass -File D:\kristal_laboratorial\portal_web\validar_porta_laboratorial.ps1
```

## Firewall do Windows

Se as estacoes nao acessarem a porta `8787`, execute como Administrador:

```powershell
powershell -ExecutionPolicy Bypass -File D:\kristal_laboratorial\portal_web\configurar_firewall_hmr.ps1
```

## Seguranca

No primeiro start, o servidor gera localmente:

- `.env`
- `KRISTAL_API_KEY`
- `KRISTAL_SECRET_KEY`
- `KRISTAL_ADMIN_PASSWORD`
- `SEGREDOS_INICIAIS_ADMIN.txt`

Esses arquivos ficam somente na pasta `D:\kristal_laboratorial\portal_web` do servidor e nao sao enviados no ZIP.

## Inicializacao automatica

A KRISTAL LABORATORIAL foi configurada para iniciar automaticamente ao entrar no Windows pelo atalho Startup do usuario atual.

Script principal:

```text
D:\kristal_laboratorial\portal_web\iniciar_servidor_background.ps1
```

Log:

```text
D:\kristal_laboratorial\portal_web\logs\servidor_autostart.log
```
