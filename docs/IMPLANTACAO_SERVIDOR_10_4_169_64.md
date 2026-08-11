# Implantacao no Servidor Real HMR - KRISTAL LABORATORIAL

## Servidor definido

A KRISTAL LABORATORIAL deve ser instalada no mesmo computador servidor da KRISTAL OPERACIONAL.

- IP do servidor: `10.4.169.64`
- URL base da KRISTAL OPERACIONAL: `http://10.4.169.64`
- URL base da KRISTAL LABORATORIAL: `https://10.4.169.64:8787`
- Pasta da KRISTAL LABORATORIAL no servidor: `D:\kristal_laboratorial`
- Pasta do servidor web LABORATORIAL: `D:\kristal_laboratorial\portal_web`
- Porta LABORATORIAL padrao: `8787`

## Regra de co-hospedagem

O IP sera o mesmo da KRISTAL OPERACIONAL. A pasta e a porta da LABORATORIAL sao proprias.

Nao copie arquivos da LABORATORIAL para dentro da pasta da KRISTAL OPERACIONAL.
Nao copie arquivos da KRISTAL OPERACIONAL para dentro da pasta da LABORATORIAL.

## Enderecos finais

- Portal do paciente: `https://10.4.169.64:8787`
- Painel administrativo: `https://10.4.169.64:8787/admin.html`
- Health check: `https://10.4.169.64:8787/health`
- Status API protegido: `https://10.4.169.64:8787/api/server/status`

## Instalacao no servidor 10.4.169.64

1. Copiar o pacote `KRISTAL_LABORATORIAL_WINDOWS_RELEASE.zip` para o servidor `10.4.169.64`.
2. Extrair em `D:\kristal_laboratorial`.
3. No servidor, executar:

```bat
D:\kristal_laboratorial\portal_web\iniciar_servidor_rede_hmr.bat
```

4. No primeiro start, o sistema gera localmente:

```text
D:\kristal_laboratorial\portal_web\.env
D:\kristal_laboratorial\portal_web\SEGREDOS_INICIAIS_ADMIN.txt
```

5. Guardar `SEGREDOS_INICIAIS_ADMIN.txt` em local restrito.

## Inicializacao automatica no servidor real

No servidor `10.4.169.64`, execute uma das opcoes:

### Sem administrador, ao entrar no Windows

```powershell
powershell -ExecutionPolicy Bypass -File D:\kristal_laboratorial\portal_web\instalar_autostart_usuario.ps1
```

### Como Administrador, via Tarefa Agendada

```powershell
powershell -ExecutionPolicy Bypass -File D:\kristal_laboratorial\portal_web\instalar_autostart_windows.ps1
```

## Validacao de porta

No servidor `10.4.169.64`, valide se a porta `8787` esta livre:

```powershell
powershell -ExecutionPolicy Bypass -File D:\kristal_laboratorial\portal_web\validar_porta_laboratorial.ps1
```

Se a porta `8787` estiver ocupada pela KRISTAL OPERACIONAL ou outro servico, altere em:

```text
D:\kristal_laboratorial\portal_web\.env
```

Campo:

```env
KRISTAL_PORTAL_PORT=8787
```

## Firewall

No servidor `10.4.169.64`, se as estacoes nao acessarem, execute como Administrador:

```powershell
powershell -ExecutionPolicy Bypass -File D:\kristal_laboratorial\portal_web\configurar_firewall_hmr.ps1
```

## Apontamento no aplicativo KRISTAL LABORATORIAL

Na tela `Servidor / Nuvem` do aplicativo, configurar:

- Servidor local: `https://10.4.169.64:8787`
- Portal do paciente: `https://10.4.169.64:8787`
- Chave API: usar `KRISTAL_API_KEY` gerada no `.env` do servidor.
