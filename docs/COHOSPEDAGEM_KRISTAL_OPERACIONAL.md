# Cohospedagem com KRISTAL OPERACIONAL`r`n`r`n## Servidor real definido`r`n`r`n- IP: `10.4.169.64` `r`n- KRISTAL LABORATORIAL: `https://10.4.169.64:8787`

A KRISTAL LABORATORIAL esta preparada para rodar no mesmo servidor da KRISTAL OPERACIONAL.

## Modelo correto

| Sistema | IP | Pasta | Porta |
|---|---|---|---|
| KRISTAL OPERACIONAL | 10.4.169.64 | Pasta propria da Operacional | Porta da Operacional |
| KRISTAL LABORATORIAL | 10.4.169.64 | `D:\kristal_laboratorial` | `8787` |

## Condicao tecnica

Dois sistemas podem compartilhar o mesmo IP desde que usem portas diferentes.

Exemplo:

```text
http://IP_DO_SERVIDOR:PORTA_OPERACIONAL
https://10.4.169.64:8787
```

## Isolamento

A KRISTAL LABORATORIAL usa:

- Banco proprio em `D:\kristal_laboratorial\portal_web\data`.
- Storage proprio em `D:\kristal_laboratorial\portal_web\storage`.
- Configuracao propria em `D:\kristal_laboratorial\portal_web\.env`.
- Chave API propria.
- Servidor FastAPI proprio.

## Quando mudar a porta

Altere `KRISTAL_PORTAL_PORT` se a porta `8787` ja estiver ocupada no servidor.

Arquivo:

```text
D:\kristal_laboratorial\portal_web\.env
```

Campo:

```env
KRISTAL_PORTAL_PORT=8787
```

Depois de alterar, reinicie `iniciar_servidor_rede_hmr.bat`.

## Inicializacao automatica do Windows

A inicializacao automatica esta configurada por atalho na pasta Startup do usuario atual do Windows.

Atalho instalado:

```text
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\KRISTAL LABORATORIAL Servidor HMR.lnk
```

Script executado pelo atalho:

```text
D:\kristal_laboratorial\portal_web\iniciar_servidor_background.ps1
```

Esse modo inicia o servidor automaticamente ao entrar no Windows.

Para instalar novamente:

```powershell
powershell -ExecutionPolicy Bypass -File D:\kristal_laboratorial\portal_web\instalar_autostart_usuario.ps1
```

Para remover:

```powershell
powershell -ExecutionPolicy Bypass -File D:\kristal_laboratorial\portal_web\remover_autostart_usuario.ps1
```

Opcionalmente, se houver permissao administrativa, pode ser usada Tarefa Agendada com:

```powershell
powershell -ExecutionPolicy Bypass -File D:\kristal_laboratorial\portal_web\instalar_autostart_windows.ps1
```
