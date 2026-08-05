param(
  [ValidatePattern('^(?:[01]\\d|2[0-3]):[0-5]\\d$')]
  [string]$Horario = '23:00'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName = 'KRISTAL_LABORATORIAL_BACKUP_AUTOMATICO'
$scriptPath = Join-Path $PSScriptRoot 'executar_backup_servidor.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
  throw "Script de backup não encontrado: $scriptPath"
}

$time = [TimeSpan]::ParseExact($Horario, 'hh\:mm', [Globalization.CultureInfo]::InvariantCulture)
if ($time.Hours -lt 18 -and $time.Hours -ge 4) {
  throw 'O backup deve ser agendado entre 18:00 e 03:59.'
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Daily -At $Horario
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 4)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Backup diário integral da KRISTAL LABORATORIAL dentro da janela operacional HMR.'
Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
Write-Host "Backup automático instalado: $taskName às $Horario (conta SYSTEM)."
