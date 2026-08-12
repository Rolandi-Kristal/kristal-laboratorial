param(
  [int]$ValidationPid = 14476,
  [string]$ProjectRoot = 'C:\kristal_laboratorial',
  [string]$DataRoot = 'D:\KRISTAL LABORATORIAL SISTEMA\KRISTAL_BUILD_STAGE_20260810\data'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$data = [IO.Path]::GetFullPath($DataRoot)
$project = [IO.Path]::GetFullPath($ProjectRoot)
$operationalDb = Join-Path $data 'kristal_laboratorial.db'
$operationalManifest = Join-Path $data 'MANIFESTO_INTEGRIDADE_BANCO_PRODUCAO.json'
$entitiesManifest = Join-Path $data 'MANIFESTO_ENTIDADES_OPERACIONAIS.json'
$corporateDb = Join-Path $data 'kristal_corporativo.db'
$corporateManifest = Join-Path $data 'MANIFESTO_INTEGRIDADE_BANCO_CORPORATIVO.json'
$logs = Join-Path $data 'finalizacao_automatica'
$lockDirectory = Join-Path $logs 'processo.lock'
$statePath = Join-Path $logs 'ESTADO_FINALIZACAO.json'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$python = Get-Command python.exe -ErrorAction SilentlyContinue
if ($null -eq $python) {
  throw 'Python não encontrado no PATH para a finalização dos bancos.'
}

try {
  New-Item -ItemType Directory -Path $lockDirectory -ErrorAction Stop | Out-Null
} catch [System.IO.IOException] {
  throw "Finalizador já está ativo; trava encontrada em $lockDirectory"
}

function Write-State {
  param(
    [Parameter(Mandatory = $true)][string]$Status,
    [Parameter(Mandatory = $true)][string]$Etapa,
    [string]$Detalhe = ''
  )
  $payload = [ordered]@{
    status = $Status
    etapa = $Etapa
    detalhe = $Detalhe
    atualizado_em = (Get-Date).ToString('o')
    processo = $PID
    validacao_aguardada = $ValidationPid
  }
  $temporary = $statePath + '.tmp'
  [IO.File]::WriteAllText($temporary, ($payload | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath $temporary -Destination $statePath -Force
}

function Invoke-PythonStep {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )
  $stdout = Join-Path $logs ($Name + '.stdout.log')
  $stderr = Join-Path $logs ($Name + '.stderr.log')
  Push-Location $project
  try {
    & $python.Source @Arguments 1> $stdout 2> $stderr
    $exitCode = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  if ($exitCode -ne 0) {
    $detail = if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Tail 20 | Out-String } else { '' }
    throw "$Name falhou com código $exitCode. $detail"
  }
}

try {
  Write-State -Status 'AGUARDANDO' -Etapa 'VALIDACAO_INTEGRAL' -Detalhe "Aguardando PID $ValidationPid"
  $initial = Get-Process -Id $ValidationPid -ErrorAction SilentlyContinue
  if ($null -ne $initial) {
    $initialStart = $initial.StartTime
    while ($true) {
      Start-Sleep -Seconds 30
      $current = Get-Process -Id $ValidationPid -ErrorAction SilentlyContinue
      if ($null -eq $current -or $current.StartTime -ne $initialStart) { break }
    }
  }

  if (-not (Test-Path -LiteralPath $operationalManifest -PathType Leaf)) {
    throw "Validação integral terminou sem manifesto: $operationalManifest"
  }
  $validation = Get-Content -LiteralPath $operationalManifest -Raw | ConvertFrom-Json
  if ([string]$validation.quick_check -ne 'ok' -or
      [string]$validation.integrity_check -ne 'ok' -or
      [long]$validation.completed_sources -ne 8 -or
      [long]$validation.distinct_legacy_tables -ne 185 -or
      [long]$validation.total_rows -ne 35385785) {
    throw 'Manifesto integral operacional rejeitado.'
  }

  Write-State -Status 'PROCESSANDO' -Etapa 'ENTIDADES_OPERACIONAIS'
  Invoke-PythonStep -Name 'validar_entidades_operacionais' -Arguments @(
    '-B', (Join-Path $project 'scripts\validar_entidades_operacionais_kristal.py'),
    '--database', $operationalDb,
    '--manifest', $entitiesManifest
  )

  Write-State -Status 'PROCESSANDO' -Etapa 'BANCO_CORPORATIVO'
  Invoke-PythonStep -Name 'preparar_banco_corporativo' -Arguments @(
    '-B', (Join-Path $project 'scripts\preparar_banco_corporativo_kristal.py'),
    '--operational-db', $operationalDb,
    '--corporate-db', $corporateDb,
    '--batch-size', '500'
  )

  Write-State -Status 'PROCESSANDO' -Etapa 'VALIDACAO_CORPORATIVA'
  Invoke-PythonStep -Name 'validar_banco_corporativo' -Arguments @(
    '-B', (Join-Path $project 'scripts\validar_banco_corporativo_kristal.py'),
    '--database', $corporateDb,
    '--manifest', $corporateManifest
  )

  $corporateValidation = Get-Content -LiteralPath $corporateManifest -Raw | ConvertFrom-Json
  if ([string]$corporateValidation.quick_check -ne 'ok' -or
      [string]$corporateValidation.integrity_check -ne 'ok' -or
      [long]$corporateValidation.current_records -lt 1 -or
      [long]$corporateValidation.payload_hashes_validated -lt [long]$corporateValidation.current_records) {
    throw 'Manifesto corporativo rejeitado após validação.'
  }

  Write-State -Status 'CONCLUIDO' -Etapa 'PRONTO_PARA_RARS' -Detalhe 'Bancos aprovados; senha interativa necessária.'
} catch [System.IO.IOException] {
  Write-State -Status 'FALHA' -Etapa 'ERRO_IO' -Detalhe $_.Exception.Message
  throw
} catch [System.UnauthorizedAccessException] {
  Write-State -Status 'FALHA' -Etapa 'ACESSO_NEGADO' -Detalhe $_.Exception.Message
  throw
} catch [System.Management.Automation.RuntimeException] {
  Write-State -Status 'FALHA' -Etapa 'ERRO_EXECUCAO' -Detalhe $_.Exception.Message
  throw
} finally {
  if (Test-Path -LiteralPath $lockDirectory) {
    Remove-Item -LiteralPath $lockDirectory -Force
  }
}
