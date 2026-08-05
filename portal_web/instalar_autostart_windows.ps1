Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName = 'KRISTAL LABORATORIAL Servidor HMR'
$portalDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startScript = Join-Path $portalDir 'iniciar_servidor_background.ps1'
if (-not (Test-Path -LiteralPath $startScript -PathType Leaf)) {
  throw "Script de inicialização não encontrado: $startScript"
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`"" -WorkingDirectory $portalDir
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 0) -MultipleInstances IgnoreNew -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Inicia automaticamente o servidor da KRISTAL LABORATORIAL com o Windows.'
Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Write-Host "Tarefa instalada e iniciada: $taskName (inicialização do Windows, conta SYSTEM)."
