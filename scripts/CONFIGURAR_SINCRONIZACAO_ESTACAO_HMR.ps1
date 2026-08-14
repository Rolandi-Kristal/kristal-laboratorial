param(
  [string]$ServerUrl = 'https://10.4.169.64:8787',
  [Parameter(Mandatory = $true)][string]$TrustedCaCertificate,
  [string]$AuthorizedWindowsUser = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Read-ApiKeySecurely {
  $secureValue = Read-Host 'Digite a KRISTAL_API_KEY do servidor' -AsSecureString
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
  try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    if ([string]::IsNullOrWhiteSpace($plain) -or $plain.Length -lt 32) {
      throw 'KRISTAL_API_KEY invalida: tamanho minimo de 32 caracteres.'
    }
    return $plain
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $secureValue.Dispose()
  }
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

function Resolve-AuthorizedUserSid {
  param([string]$RequestedUser)

  $accountName = $RequestedUser.Trim()
  if ([string]::IsNullOrWhiteSpace($accountName)) {
    $accountName = [string](Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName
  }
  if ([string]::IsNullOrWhiteSpace($accountName)) {
    throw 'Informe -AuthorizedWindowsUser com a conta que executara a KRISTAL.'
  }
  try {
    return [Security.Principal.NTAccount]::new($accountName).Translate(
      [Security.Principal.SecurityIdentifier]
    ).Value
  } catch [Security.Principal.IdentityNotMappedException] {
    throw "Conta Windows nao localizada: $accountName"
  }
}

function Write-MachineConfig {
  param(
    [Parameter(Mandatory = $true)][uri]$Uri,
    [Parameter(Mandatory = $true)][string]$ProtectedApiKey,
    [Parameter(Mandatory = $true)][string]$AuthorizedUserSid
  )

  if (-not $ProtectedApiKey.StartsWith('DPAPI_LOCAL_MACHINE_V1:')) {
    throw 'Credencial DPAPI invalida.'
  }
  $directory = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'KRISTAL LABORATORIAL'
  $configPath = Join-Path $directory 'server_config.json'
  New-Item -ItemType Directory -Path $directory -Force | Out-Null
  $port = if ($Uri.IsDefaultPort) { 443 } else { $Uri.Port }
  $baseUrl = $Uri.GetLeftPart([UriPartial]::Authority).TrimEnd('/')
  $payload = [ordered]@{
    modo = 'HIBRIDO'
    connectionMode = 'HIBRIDO'
    servidorLocalHost = $Uri.Host
    servidorLocalPorta = [string]$port
    localServerUrl = $baseUrl
    portalUrl = $baseUrl
    cloudBaseUrl = ''
    nuvemBaseUrl = ''
    cloudApiToken = ''
    nuvemApiKey = ''
    apiKeyProtegida = $ProtectedApiKey
    syncEnabled = '1'
    sincronizacaoAtiva = '1'
    syncIntervalMinutes = '1'
    intervaloMinutos = '1'
    usarCriptografia = '1'
    observacao = 'Servidor HMR validado por HTTPS; chave protegida por DPAPI LocalMachine.'
  }
  $temporary = $configPath + '.tmp'
  [IO.File]::WriteAllText(
    $temporary,
    ($payload | ConvertTo-Json -Depth 5),
    [Text.UTF8Encoding]::new($false)
  )
  Move-Item -LiteralPath $temporary -Destination $configPath -Force
  $userGrant = '*' + $AuthorizedUserSid + ':(OI)(CI)R'
  & icacls.exe $directory /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' $userGrant | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao restringir a configuracao: $configPath"
  }
  return $configPath
}

if (-not (Test-Administrator)) {
  throw 'Execute este script como Administrador.'
}
$serverUri = $null
if (-not [Uri]::TryCreate($ServerUrl, [UriKind]::Absolute, [ref]$serverUri) -or
    $serverUri.Scheme -ne 'https' -or
    [string]::IsNullOrWhiteSpace($serverUri.Host)) {
  throw 'ServerUrl invalida; informe uma URL HTTPS absoluta.'
}
$caPath = [IO.Path]::GetFullPath($TrustedCaCertificate)
if (-not (Test-Path -LiteralPath $caPath -PathType Leaf)) {
  throw "Certificado CA nao encontrado: $caPath"
}
$ca = [Security.Cryptography.X509Certificates.X509Certificate2]::new($caPath)
if ($ca.HasPrivateKey) {
  throw 'O arquivo CA da estacao nao pode conter chave privada.'
}
Import-Certificate -FilePath $caPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null

$apiKey = Read-ApiKeySecurely
try {
  $baseUrl = $serverUri.GetLeftPart([UriPartial]::Authority).TrimEnd('/')
  $health = Invoke-RestMethod -Method Get -Uri ($baseUrl + '/health') -TimeoutSec 15
  if ([string]$health.status -ne 'ok') {
    throw 'Servidor nao confirmou status de saude ok.'
  }
  $headers = @{ 'X-API-Key' = $apiKey }
  $status = Invoke-RestMethod -Method Get -Uri ($baseUrl + '/api/server/sync/status') -Headers $headers -TimeoutSec 30
  foreach ($field in @('record_count', 'history_count', 'client_count', 'server_version')) {
    if ($null -eq $status.$field -or [long]$status.$field -lt 0) {
      throw "Resposta de sincronizacao invalida: campo $field."
    }
  }
  $sid = Resolve-AuthorizedUserSid -RequestedUser $AuthorizedWindowsUser
  $protected = Protect-MachineSecret -Secret $apiKey
  $config = Write-MachineConfig -Uri $serverUri -ProtectedApiKey $protected -AuthorizedUserSid $sid
  Write-Host 'SINCRONIZACAO CONFIGURADA COM SUCESSO.' -ForegroundColor Green
  Write-Host "Servidor: $baseUrl" -ForegroundColor Green
  Write-Host "Registros corporativos disponíveis: $($status.record_count)" -ForegroundColor Green
  Write-Host "Versao corporativa: $($status.server_version)" -ForegroundColor Green
  Write-Host "Configuracao protegida: $config" -ForegroundColor Green
  Write-Host 'Feche e abra a KRISTAL LABORATORIAL para iniciar a carga automática.' -ForegroundColor Yellow
} finally {
  $apiKey = $null
  $headers = $null
  $protected = $null
}