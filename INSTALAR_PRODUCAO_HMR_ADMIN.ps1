param(
  [string]$Destino = 'D:\kristal_laboratorial',
  [switch]$ConfigurarServidor,
  [switch]$SubstituirBancosPeloSeed,
  [string]$ConfirmacaoSubstituicaoBancos = '',
  [switch]$CriarAtalhoDesktop,
  [string]$ApiKey = '',
  [switch]$SolicitarApiKey,
  [string]$ServerUrl = 'https://10.4.169.64:8787',
  [string]$AuthorizedWindowsUser = '',
  [string]$TrustedCaCertificate = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ExpectedCodeSigningThumbprint = '41A4507029802AC7A0BADBA496F7BD532E03748A'

$PacoteRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppOrigem = Join-Path $PacoteRoot 'app_windows'
$PortalOrigem = Join-Path $PacoteRoot 'portal_web'
$ConfigOrigem = Join-Path $PacoteRoot 'config'
$ScriptsOrigem = Join-Path $PacoteRoot 'scripts'
$LegadoOrigem = Join-Path $PacoteRoot 'dados_legados_kristal'
$CertificadosOrigem = Join-Path $PacoteRoot 'certificados'
$IntegracoesOrigem = Join-Path $PacoteRoot 'integracoes'
$ServerOrigem = Join-Path $PacoteRoot 'server_windows'
$DataSeedOrigem = Join-Path $PacoteRoot 'data_seed'

$AppDestino = Join-Path $Destino 'KRISTAL_LABORATORIAL'
$PortalDestino = Join-Path $Destino 'portal_web'
$ConfigDestino = Join-Path $Destino 'config'
$ScriptsDestino = Join-Path $Destino 'scripts'
$LegadoDestino = Join-Path $Destino 'dados_legados_kristal'
$CertificadosDestino = Join-Path $Destino 'certificados'
$IntegracoesDestino = Join-Path $Destino 'integracoes'
$ServerDestino = Join-Path $Destino 'KRISTAL_SERVIDOR'
$BackupRoot = Join-Path $Destino ('backups\pre_update_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Step {
  param([Parameter(Mandatory = $true)][string]$Message)
  Write-Host "`n[KRISTAL] $Message" -ForegroundColor Cyan
}

function Get-NormalizedPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
}

function Test-SamePath {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )
  return [string]::Equals(
    (Get-NormalizedPath -Path $Source),
    (Get-NormalizedPath -Path $Destination),
    [System.StringComparison]::OrdinalIgnoreCase
  )
}

function Test-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-RobocopyDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [string[]]$AdditionalArguments = @()
  )

  if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    Write-Host "Ignorado; origem inexistente: $Source" -ForegroundColor DarkYellow
    return
  }

  if (Test-SamePath -Source $Source -Destination $Destination) {
    Write-Host "Origem e destino iguais; copia ignorada com seguranca: $Source" -ForegroundColor DarkYellow
    return
  }

  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  $arguments = @($Source, $Destination, '/E', '/COPY:DAT', '/DCOPY:DA', '/R:2', '/W:2', '/XJ')
  $arguments += $AdditionalArguments
  & robocopy @arguments | Out-Host
  $robocopyExitCode = $LASTEXITCODE
  if ($robocopyExitCode -gt 7) {
    throw "Robocopy falhou da origem '$Source' para '$Destination'. Codigo: $robocopyExitCode"
  }
}

function Stop-KristalProcesses {
  Write-Step -Message 'Interrompendo processos da KRISTAL para obter backup consistente'
  Get-Process -Name 'kristal_laboratorial', 'KRISTAL_SERVIDOR' -ErrorAction SilentlyContinue | Stop-Process -Force

  $pythonServers = Get-CimInstance Win32_Process -ErrorAction Stop |
    Where-Object { $null -ne $_.CommandLine -and $_.CommandLine -like '*portal_web*main.py*' }
  foreach ($process in $pythonServers) {
    Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
  }
}

function Backup-ExistingData {
  Write-Step -Message "Criando backup anterior a atualizacao em $BackupRoot"
  New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null

  $items = @(
    'portal_web\.env',
    'portal_web\data',
    'portal_web\logs',
    'portal_web\storage',
    'portal_web\backups',
    'data',
    'logs',
    'exports',
    'certificados',
    'relatorios'
  )

  foreach ($relativePath in $items) {
    $source = Join-Path $Destino $relativePath
    if (-not (Test-Path -LiteralPath $source)) {
      continue
    }

    $backupDestination = Join-Path $BackupRoot $relativePath
    Write-Host "Preservando: $relativePath"
    if (Test-Path -LiteralPath $source -PathType Container) {
      Invoke-RobocopyDirectory -Source $source -Destination $backupDestination
    } else {
      $backupParent = Split-Path -Parent $backupDestination
      New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
      Copy-Item -LiteralPath $source -Destination $backupDestination -Force
    }
  }

  Write-Host 'Backups historicos existentes foram mantidos no local original.' -ForegroundColor Green
}

function Get-EnvValue {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Name
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return ''
  }
  $prefix = $Name + '='
  $line = Get-Content -LiteralPath $Path |
    Where-Object { $_ -like ($prefix + '*') } |
    Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($line)) {
    return ''
  }
  return $line.Substring($prefix.Length).Trim()
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

function Read-ApiKeySecurely {
  $secureValue = Read-Host 'Digite a KRISTAL_API_KEY do servidor' -AsSecureString
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $secureValue.Dispose()
  }
}

function Resolve-AuthorizedUserSid {
  param([string]$RequestedUser)

  $accountName = $RequestedUser.Trim()
  if ([string]::IsNullOrWhiteSpace($accountName)) {
    $computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $accountName = [string]$computerSystem.UserName
  }
  if ([string]::IsNullOrWhiteSpace($accountName)) {
    throw 'Informe -AuthorizedWindowsUser com a conta Windows autorizada a executar a KRISTAL.'
  }
  $account = [Security.Principal.NTAccount]::new($accountName)
  try {
    return $account.Translate([Security.Principal.SecurityIdentifier]).Value
  } catch [Security.Principal.IdentityNotMappedException] {
    throw "Conta Windows autorizada nao localizada: $accountName"
  }
}

function Write-MachineServerConfig {
  param(
    [Parameter(Mandatory = $true)][uri]$Uri,
    [Parameter(Mandatory = $true)][string]$ProtectedKey,
    [Parameter(Mandatory = $true)][string]$AuthorizedUserSid
  )

  if (-not $ProtectedKey.StartsWith('DPAPI_LOCAL_MACHINE_V1:')) {
    throw 'Blob DPAPI corporativo invalido.'
  }
  $programDataRoot = [Environment]::GetFolderPath('CommonApplicationData')
  if ([string]::IsNullOrWhiteSpace($programDataRoot)) {
    throw 'Diretorio ProgramData nao foi localizado.'
  }
  $configDirectory = Join-Path $programDataRoot 'KRISTAL LABORATORIAL'
  $configPath = Join-Path $configDirectory 'server_config.json'
  New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null

  $port = if ($Uri.IsDefaultPort) {
    if ($Uri.Scheme -eq 'https') { 443 } else { 80 }
  } else {
    $Uri.Port
  }
  $baseUrl = $Uri.GetLeftPart([System.UriPartial]::Authority).TrimEnd('/')
  $config = [ordered]@{
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
    apiKeyProtegida = $ProtectedKey
    syncEnabled = '1'
    sincronizacaoAtiva = '1'
    syncIntervalMinutes = '1'
    intervaloMinutos = '1'
    usarCriptografia = '1'
    observacao = 'Configuracao corporativa protegida pelo Windows DPAPI.'
  }
  $json = $config | ConvertTo-Json -Depth 4
  [IO.File]::WriteAllText($configPath, $json, [Text.UTF8Encoding]::new($false))

  $userGrant = '*' + $AuthorizedUserSid + ':(OI)(CI)R'
  & icacls.exe $configDirectory /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' $userGrant | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao proteger a configuracao corporativa: $configPath"
  }
  return $configPath
}

function Sync-PackageDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [string[]]$AdditionalArguments = @()
  )
  Write-Step -Message "Atualizando $Name"
  Invoke-RobocopyDirectory -Source $Source -Destination $Destination -AdditionalArguments $AdditionalArguments
}

if (-not (Test-Admin)) {
  throw 'Execute este script como Administrador no servidor ou estacao do HMR.'
}
if ($SubstituirBancosPeloSeed -and -not $ConfigurarServidor) {
  throw '-SubstituirBancosPeloSeed exige -ConfigurarServidor.'
}
if ($SubstituirBancosPeloSeed -and
    $ConfirmacaoSubstituicaoBancos -cne 'SUBSTITUIR_BANCOS_KRISTAL') {
  throw "Para substituir bancos, informe -ConfirmacaoSubstituicaoBancos 'SUBSTITUIR_BANCOS_KRISTAL'."
}

if ($SolicitarApiKey -and -not [string]::IsNullOrWhiteSpace($ApiKey)) {
  throw 'Use somente -SolicitarApiKey; nao informe -ApiKey na mesma execucao.'
}
if ($SolicitarApiKey -and $ConfigurarServidor) {
  throw 'O servidor usa automaticamente a chave gerada no .env; -SolicitarApiKey e exclusivo das estacoes.'
}

if (-not (Test-Path -LiteralPath (Join-Path $AppOrigem 'kristal_laboratorial.exe') -PathType Leaf)) {
  throw "Aplicativo Windows nao encontrado em $AppOrigem"
}
if (-not (Test-Path -LiteralPath (Join-Path $PortalOrigem 'main.py') -PathType Leaf)) {
  throw "Portal web nao encontrado em $PortalOrigem"
}
if (-not (Get-Command robocopy -ErrorAction SilentlyContinue)) {
  throw 'Robocopy nao foi encontrado no Windows.'
}
if ($ConfigurarServidor -and
    -not (Test-Path -LiteralPath (Join-Path $ServerOrigem 'KRISTAL_SERVIDOR.exe') -PathType Leaf)) {
  throw "Servidor Windows compilado nao encontrado em $ServerOrigem"
}

Write-Step -Message "Iniciando atualizacao. Pacote: $PacoteRoot | Destino: $Destino"
New-Item -ItemType Directory -Path $Destino -Force | Out-Null

Stop-KristalProcesses
Backup-ExistingData

Sync-PackageDirectory -Name 'aplicativo Windows' -Source $AppOrigem -Destination $AppDestino
Sync-PackageDirectory -Name 'portal web' -Source $PortalOrigem -Destination $PortalDestino -AdditionalArguments @(
  '/XF', '.env', '*.db', '*.sqlite', '*.sqlite3', '*.log', '*.pid',
  'SEGREDOS_INICIAIS_ADMIN.txt', 'senha admin.txt', '*.pyc',
  '/XD', '.venv', '__pycache__', 'data', 'logs', 'storage', 'backups'
)
Sync-PackageDirectory -Name 'configuracoes' -Source $ConfigOrigem -Destination $ConfigDestino
Sync-PackageDirectory -Name 'scripts operacionais' -Source $ScriptsOrigem -Destination $ScriptsDestino
Sync-PackageDirectory -Name 'dados legados preservados' -Source $LegadoOrigem -Destination $LegadoDestino
Sync-PackageDirectory -Name 'certificados publicos' -Source $CertificadosOrigem -Destination $CertificadosDestino
Sync-PackageDirectory -Name 'integracoes laboratoriais' -Source $IntegracoesOrigem -Destination $IntegracoesDestino
if ($ConfigurarServidor) {
  Sync-PackageDirectory -Name 'servidor Windows compilado' -Source $ServerOrigem -Destination $ServerDestino
}

foreach ($directory in @('data', 'logs', 'exports', 'exports\sire', 'backups', 'certificados', 'drivers', 'relatorios')) {
  New-Item -ItemType Directory -Path (Join-Path $Destino $directory) -Force | Out-Null
}
foreach ($directory in @('data', 'logs', 'storage', 'backups')) {
  New-Item -ItemType Directory -Path (Join-Path $PortalDestino $directory) -Force | Out-Null
}

if ($ConfigurarServidor -and (Test-Path -LiteralPath $DataSeedOrigem -PathType Container)) {
  Write-Step -Message 'Instalando bancos-semente com validacao SHA-256 e rollback'
  $seedInstaller = Join-Path $ScriptsOrigem 'instalar_bancos_seed_servidor.ps1'
  if (-not (Test-Path -LiteralPath $seedInstaller -PathType Leaf)) {
    throw "Instalador seguro de bancos ausente: $seedInstaller"
  }
  $seedArguments = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $seedInstaller,
    '-PacoteRoot', $PacoteRoot,
    '-DestinoData', (Join-Path $Destino 'data'),
    '-BackupRoot', $BackupRoot
  )
  if ($SubstituirBancosPeloSeed) {
    $seedArguments += '-SubstituirExistentes'
  }
  & powershell.exe @seedArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Falha na instalacao validada dos bancos. Codigo: $LASTEXITCODE"
  }
}

Write-Step -Message 'Validando configuracao unica do superusuario'
$superEnv = Join-Path $ConfigDestino 'superusuario.env'
if (-not (Test-Path -LiteralPath $superEnv -PathType Leaf)) {
  throw "Configuracao unica do superusuario nao encontrada: $superEnv"
}
$superPasswordLine = Get-Content -LiteralPath $superEnv |
  Where-Object { $_ -like 'KRISTAL_SUPERUSER_PASSWORD=*' } |
  Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($superPasswordLine)) {
  throw "KRISTAL_SUPERUSER_PASSWORD nao definida em $superEnv"
}
$superPassword = $superPasswordLine.Substring('KRISTAL_SUPERUSER_PASSWORD='.Length)
if ([string]::IsNullOrWhiteSpace($superPassword)) {
  throw "KRISTAL_SUPERUSER_PASSWORD vazia em $superEnv"
}

$envPath = Join-Path $PortalDestino '.env'
if ($ConfigurarServidor) {
  if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
    $envExample = Join-Path $PortalDestino '.env.example'
    if (-not (Test-Path -LiteralPath $envExample -PathType Leaf)) {
      throw "Nem .env nem .env.example foram encontrados em $PortalDestino"
    }
    Copy-Item -LiteralPath $envExample -Destination $envPath -Force
  }

  $envLines = @(Get-Content -LiteralPath $envPath)
  $envLines = @($envLines | Where-Object { $_ -notmatch '^KRISTAL_SUPERUSER_PASSWORD=' })
  $envLines += ('KRISTAL_SUPERUSER_PASSWORD=' + $superPassword)
  Set-Content -LiteralPath $envPath -Value $envLines -Encoding UTF8

  $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
  if ($null -eq $pythonCommand) {
    throw 'Python nao foi encontrado no PATH do servidor.'
  }

  Write-Step -Message 'Gerando e validando segredos do portal'
  Push-Location $PortalDestino
  try {
    & $pythonCommand.Source 'gerar_segredos_portal.py'
    if ($LASTEXITCODE -ne 0) {
      throw "Falha ao gerar segredos do portal. Codigo: $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

if ($ConfigurarServidor) {
  & icacls.exe $envPath /inheritance:r /grant:r '*S-1-5-18:F' '*S-1-5-32-544:F' | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao restringir o arquivo de segredos: $envPath"
  }
}

$serverUri = $null
if (-not [Uri]::TryCreate($ServerUrl, [UriKind]::Absolute, [ref]$serverUri) -or
    $serverUri.Scheme -ne 'https' -or
    [string]::IsNullOrWhiteSpace($serverUri.Host)) {
  throw 'ServerUrl invalida. A producao exige uma URL HTTPS absoluta.'
}

$trustedCaPath = ''
if ($ConfigurarServidor) {
  $serverAddress = $null
  if (-not [Net.IPAddress]::TryParse($serverUri.Host, [ref]$serverAddress)) {
    throw 'A instalacao do servidor exige que ServerUrl use o IP fixo do servidor HMR.'
  }
  $tlsDirectory = Join-Path $CertificadosDestino 'tls'
  $tlsGenerator = Join-Path $PortalDestino 'gerar_certificado_tls.py'
  if (-not (Test-Path -LiteralPath $tlsGenerator -PathType Leaf)) {
    throw "Gerador TLS nao encontrado: $tlsGenerator"
  }
  New-Item -ItemType Directory -Path $tlsDirectory -Force | Out-Null
  Write-Step -Message 'Gerando ou preservando certificado TLS privado do servidor'
  & $pythonCommand.Source $tlsGenerator --output $tlsDirectory --server-ip $serverUri.Host --dns-name 'kristal-laboratorial.hmr.local'
  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao preparar certificado TLS. Codigo: $LASTEXITCODE"
  }
  $tlsCertFile = Join-Path $tlsDirectory 'KRISTAL_HMR_SERVIDOR.cert.pem'
  $tlsKeyFile = Join-Path $tlsDirectory 'KRISTAL_HMR_SERVIDOR.key.pem'
  $trustedCaPath = Join-Path $tlsDirectory 'KRISTAL_HMR_CA.cer'
  foreach ($requiredTlsFile in @($tlsCertFile, $tlsKeyFile, $trustedCaPath)) {
    if (-not (Test-Path -LiteralPath $requiredTlsFile -PathType Leaf)) {
      throw "Arquivo TLS obrigatorio ausente: $requiredTlsFile"
    }
  }
  $envLines = @(Get-Content -LiteralPath $envPath)
  $envLines = @($envLines | Where-Object {
    $_ -notmatch '^(KRISTAL_TLS_CERT_FILE|KRISTAL_TLS_KEY_FILE|KRISTAL_REQUIRE_TLS)='
  })
  $envLines += ('KRISTAL_TLS_CERT_FILE=' + $tlsCertFile)
  $envLines += ('KRISTAL_TLS_KEY_FILE=' + $tlsKeyFile)
  $envLines += 'KRISTAL_REQUIRE_TLS=1'
  Set-Content -LiteralPath $envPath -Value $envLines -Encoding UTF8
  & icacls.exe $tlsDirectory /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao proteger as chaves TLS em $tlsDirectory"
  }
  Copy-Item -LiteralPath $trustedCaPath -Destination (Join-Path $CertificadosDestino 'KRISTAL_HMR_CA.cer') -Force
} else {
  $trustedCaPath = $TrustedCaCertificate.Trim()
  if ([string]::IsNullOrWhiteSpace($trustedCaPath)) {
    $trustedCaPath = Join-Path $CertificadosDestino 'KRISTAL_HMR_CA.cer'
  }
  if (-not (Test-Path -LiteralPath $trustedCaPath -PathType Leaf)) {
    throw 'CA TLS do servidor ausente. Informe -TrustedCaCertificate com KRISTAL_HMR_CA.cer exportado do servidor.'
  }
}
Import-Certificate -FilePath $trustedCaPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
Write-Host "CA TLS confiavel instalada: $trustedCaPath" -ForegroundColor Green

$authorizedUserSid = Resolve-AuthorizedUserSid -RequestedUser $AuthorizedWindowsUser
$authorizedUserGrant = '*' + $authorizedUserSid + ':R'
& icacls.exe $superEnv /inheritance:r /grant:r '*S-1-5-18:F' '*S-1-5-32-544:F' $authorizedUserGrant | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Falha ao restringir a configuracao do superusuario: $superEnv"
}
$effectiveApiKey = if ($SolicitarApiKey) { Read-ApiKeySecurely } else { $ApiKey.Trim() }
if ([string]::IsNullOrWhiteSpace($effectiveApiKey) -and $ConfigurarServidor) {
  $effectiveApiKey = Get-EnvValue -Path $envPath -Name 'KRISTAL_API_KEY'
}
$existingMachineConfig = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'KRISTAL LABORATORIAL\server_config.json'
if ([string]::IsNullOrWhiteSpace($effectiveApiKey) -and
    -not (Test-Path -LiteralPath $existingMachineConfig -PathType Leaf)) {
  $effectiveApiKey = Read-ApiKeySecurely
}
$protectedApiKey = ''
if (-not [string]::IsNullOrWhiteSpace($effectiveApiKey)) {
  if ($effectiveApiKey.Length -lt 32) {
    throw 'Chave API corporativa invalida: tamanho minimo de 32 caracteres.'
  }
  $protectedApiKey = Protect-MachineSecret -Secret $effectiveApiKey
} elseif (Test-Path -LiteralPath $existingMachineConfig -PathType Leaf) {
  $existingConfig = Get-Content -LiteralPath $existingMachineConfig -Raw | ConvertFrom-Json
  $protectedApiKey = [string]$existingConfig.apiKeyProtegida
}
if ([string]::IsNullOrWhiteSpace($protectedApiKey) -or
    -not $protectedApiKey.StartsWith('DPAPI_LOCAL_MACHINE_V1:')) {
  throw 'Credencial corporativa ausente ou invalida.'
}

Write-Step -Message 'Gravando configuracao corporativa protegida por Windows DPAPI'
$machineConfigPath = Write-MachineServerConfig -Uri $serverUri -ProtectedKey $protectedApiKey -AuthorizedUserSid $authorizedUserSid
Write-Host "Configuracao corporativa: $machineConfigPath" -ForegroundColor Green
$effectiveApiKey = ''
$protectedApiKey = ''
Write-Step -Message 'Validando assinatura digital do aplicativo'
$certificatePath = Join-Path $CertificadosDestino 'KRISTAL_LABORATORIAL_ASSINATURA_PUBLICA.cer'
if (-not (Test-Path -LiteralPath $certificatePath -PathType Leaf)) {
  throw "Certificado publico de assinatura ausente: $certificatePath"
}
$codeSigningCertificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($certificatePath)
if ($codeSigningCertificate.Thumbprint -ne $ExpectedCodeSigningThumbprint) {
  throw "Certificado de assinatura rejeitado: thumbprint inesperado $($codeSigningCertificate.Thumbprint)."
}
if ($codeSigningCertificate.HasPrivateKey) {
  throw 'Certificado de assinatura rejeitado: o pacote nao pode conter chave privada.'
}
if ((Get-Date) -lt $codeSigningCertificate.NotBefore -or (Get-Date) -gt $codeSigningCertificate.NotAfter) {
  throw 'Certificado de assinatura rejeitado: periodo de validade invalido.'
}
Import-Certificate -FilePath $certificatePath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
Import-Certificate -FilePath $certificatePath -CertStoreLocation Cert:\LocalMachine\TrustedPublisher | Out-Null

$applicationPath = Join-Path $AppDestino 'kristal_laboratorial.exe'
$signature = Get-AuthenticodeSignature -FilePath $applicationPath
if ($signature.Status -ne 'Valid') {
  throw "Assinatura do EXE invalida: $($signature.Status) - $($signature.StatusMessage)"
}
if ($null -eq $signature.SignerCertificate -or
    $signature.SignerCertificate.Thumbprint -ne $ExpectedCodeSigningThumbprint) {
  throw 'Assinatura do EXE rejeitada: certificado assinante inesperado.'
}
if ($ConfigurarServidor) {
  $serverApplicationPath = Join-Path $ServerDestino 'KRISTAL_SERVIDOR.exe'
  $serverSignature = Get-AuthenticodeSignature -FilePath $serverApplicationPath
  if ($serverSignature.Status -ne 'Valid') {
    throw "Assinatura do servidor invalida: $($serverSignature.Status) - $($serverSignature.StatusMessage)"
  }
  if ($null -eq $serverSignature.SignerCertificate -or
      $serverSignature.SignerCertificate.Thumbprint -ne $ExpectedCodeSigningThumbprint) {
    throw 'Assinatura do servidor rejeitada: certificado assinante inesperado.'
  }
}

if ($CriarAtalhoDesktop) {
  Write-Step -Message 'Criando atalho na area de trabalho publica'
  $desktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
  $shortcutPath = Join-Path $desktop 'KRISTAL LABORATORIAL.lnk'
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $applicationPath
  $shortcut.WorkingDirectory = $AppDestino
  $shortcut.IconLocation = $applicationPath
  $shortcut.Save()
}

if ($ConfigurarServidor) {
  Write-Step -Message 'Configurando firewall, backup automatico e inicializacao do servidor'
  foreach ($scriptName in @(
    'configurar_firewall_hmr.ps1',
    'instalar_backup_automatico_windows.ps1',
    'instalar_autostart_windows.ps1'
  )) {
    $scriptPath = Join-Path $PortalDestino $scriptName
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
      throw "Script obrigatorio do servidor nao encontrado: $scriptPath"
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    if ($LASTEXITCODE -ne 0) {
      throw "Falha na execucao de $scriptName. Codigo: $LASTEXITCODE"
    }
  }
}

Write-Host "`nKRISTAL LABORATORIAL instalada e atualizada com sucesso." -ForegroundColor Green
Write-Host "Backup anterior: $BackupRoot" -ForegroundColor Green
Write-Host "Aplicativo: $applicationPath" -ForegroundColor Green
Write-Host "Servidor web: $PortalDestino" -ForegroundColor Green
Write-Host 'Execute a carga de dados somente depois desta mensagem de sucesso.' -ForegroundColor Yellow
