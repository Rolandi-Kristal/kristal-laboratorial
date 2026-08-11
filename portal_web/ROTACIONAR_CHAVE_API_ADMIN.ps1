param(
  [switch]$ConfirmarRotacao,
  [string]$ServerUrl = 'https://10.4.169.64:8787'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Protect-MachineSecret {
  param([Parameter(Mandatory = $true)][string]$Secret)

  Add-Type -AssemblyName System.Security
  $clearBytes = [Text.Encoding]::UTF8.GetBytes($Secret)
  try {
    $protectedBytes = [Security.Cryptography.ProtectedData]::Protect(
      $clearBytes,
      $null,
      [Security.Cryptography.DataProtectionScope]::LocalMachine
    )
    return 'DPAPI_LOCAL_MACHINE_V1:' + [Convert]::ToBase64String($protectedBytes)
  } finally {
    [Array]::Clear($clearBytes, 0, $clearBytes.Length)
  }
}

function Write-AtomicUtf8 {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )

  $temporary = $Path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
  try {
    [IO.File]::WriteAllText($temporary, $Content, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $Path -Force
  } finally {
    if (Test-Path -LiteralPath $temporary) {
      Remove-Item -LiteralPath $temporary -Force
    }
  }
}

if (-not (Test-Administrator)) {
  throw 'Execute este script em um PowerShell aberto como Administrador no servidor KRISTAL.'
}
if (-not $ConfirmarRotacao) {
  throw 'A rotacao exige o parametro -ConfirmarRotacao.'
}

$serverUri = $null
if (-not [Uri]::TryCreate($ServerUrl, [UriKind]::Absolute, [ref]$serverUri) -or
    $serverUri.Scheme -ne 'https' -or
    [string]::IsNullOrWhiteSpace($serverUri.Host)) {
  throw 'ServerUrl invalida. A producao exige uma URL HTTPS absoluta.'
}

$taskName = 'KRISTAL LABORATORIAL Servidor HMR'
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -eq $task) {
  throw "Tarefa de inicializacao do servidor nao encontrada: $taskName"
}

$envPath = Join-Path $PSScriptRoot '.env'
if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
  throw "Arquivo .env do servidor nao encontrado: $envPath"
}

$prefix = 'KRISTAL_API_KEY='
$lines = [Collections.Generic.List[string]]::new()
$lines.AddRange([string[]](Get-Content -LiteralPath $envPath))
$indexes = @()
for ($index = 0; $index -lt $lines.Count; $index++) {
  if ($lines[$index] -clike ($prefix + '*')) {
    $indexes += $index
  }
}
if ($indexes.Count -ne 1) {
  throw "O .env deve possuir exatamente uma definicao de KRISTAL_API_KEY; encontradas: $($indexes.Count)."
}

$randomBytes = New-Object byte[] 40
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$newApiKey = ''
try {
  $rng.GetBytes($randomBytes)
  $token = [Convert]::ToBase64String($randomBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
  $newApiKey = 'klab_' + $token
  if ($newApiKey.Length -lt 32) {
    throw 'Falha ao gerar chave API com o tamanho minimo exigido.'
  }

  $lines[$indexes[0]] = $prefix + $newApiKey
  Write-AtomicUtf8 -Path $envPath -Content (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
  & icacls.exe $envPath /inheritance:r /grant:r '*S-1-5-18:F' '*S-1-5-32-544:F' | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao proteger o arquivo de segredos: $envPath"
  }

  $machineConfigPath = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'KRISTAL LABORATORIAL\server_config.json'
  if (Test-Path -LiteralPath $machineConfigPath -PathType Leaf) {
    $machineConfig = Get-Content -LiteralPath $machineConfigPath -Raw | ConvertFrom-Json
    $protectedKey = Protect-MachineSecret -Secret $newApiKey
    if ($null -eq $machineConfig.PSObject.Properties['apiKeyProtegida']) {
      $machineConfig | Add-Member -NotePropertyName 'apiKeyProtegida' -NotePropertyValue $protectedKey
    } else {
      $machineConfig.apiKeyProtegida = $protectedKey
    }
    Write-AtomicUtf8 -Path $machineConfigPath -Content ($machineConfig | ConvertTo-Json -Depth 10)
    $protectedKey = $null
  }

  if ($task.State -eq 'Running') {
    Stop-ScheduledTask -TaskName $taskName
  }
  Get-Process -Name 'KRISTAL_SERVIDOR' -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-ScheduledTask -TaskName $taskName

  $serverProcess = $null
  for ($attempt = 1; $attempt -le 30; $attempt++) {
    Start-Sleep -Seconds 1
    $serverProcess = Get-Process -Name 'KRISTAL_SERVIDOR' -ErrorAction SilentlyContinue
    if ($null -ne $serverProcess) {
      break
    }
  }
  if ($null -eq $serverProcess) {
    throw 'O servidor nao iniciou em ate 30 segundos depois da rotacao.'
  }

  $statusUri = $serverUri.GetLeftPart([UriPartial]::Authority).TrimEnd('/') + '/api/server/status'
  $status = $null
  for ($attempt = 1; $attempt -le 30; $attempt++) {
    Start-Sleep -Seconds 1
    try {
      $status = Invoke-RestMethod -Method Get -Uri $statusUri -Headers @{'X-API-Key' = $newApiKey}
      break
    } catch [System.Net.WebException] {
      if ($attempt -eq 30) {
        throw
      }
    } catch [System.Net.Http.HttpRequestException] {
      if ($attempt -eq 30) {
        throw
      }
    }
  }
  if ($null -eq $status -or [string]$status.status -ne 'ok') {
    throw 'A rota protegida do servidor nao confirmou a nova chave API.'
  }

  Write-Warning 'A chave anterior foi revogada. Atualize todas as estacoes autorizadas.'
  Write-Host 'NOVA KRISTAL_API_KEY:' -ForegroundColor Cyan
  [Console]::Out.WriteLine($newApiKey)
  Write-Host "Servidor validado em $statusUri. Feche este PowerShell apos configurar as estacoes." -ForegroundColor Green
} finally {
  $rng.Dispose()
  [Array]::Clear($randomBytes, 0, $randomBytes.Length)
  $newApiKey = $null
  $lines.Clear()
}
