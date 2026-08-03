$ErrorActionPreference = 'Stop'
$taskName = 'KRISTAL LABORATORIAL Servidor HMR'
$portalDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startScript = Join-Path $portalDir 'iniciar_servidor_background.ps1'
if (-not (Test-Path $startScript)) {
  throw "Script de inicializacao nao encontrado: $startScript"
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`"" -WorkingDirectory $portalDir
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 0) -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $triggerLogon -Settings $settings -Principal $principal -Description 'Inicia automaticamente o servidor web da KRISTAL LABORATORIAL no servidor HMR.'
Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Write-Host "Tarefa instalada e iniciada: $taskName"
