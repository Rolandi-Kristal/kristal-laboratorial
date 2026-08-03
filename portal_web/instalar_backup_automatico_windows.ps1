$ErrorActionPreference = "Stop"
$taskName = "KRISTAL_LABORATORIAL_BACKUP_AUTOMATICO"
$scriptPath = Join-Path $PSScriptRoot "executar_backup_servidor.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Daily -At 23:30
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Backup automatico diario do portal KRISTAL LABORATORIAL" -Force | Out-Null
Write-Host "Backup automatico instalado: $taskName"
