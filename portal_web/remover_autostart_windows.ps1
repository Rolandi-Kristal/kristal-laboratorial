$ErrorActionPreference = 'Stop'
$taskName = 'KRISTAL LABORATORIAL Servidor HMR'
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -ne $task) {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
  Write-Host "Tarefa removida: $taskName"
} else {
  Write-Host "Tarefa nao encontrada: $taskName"
}
