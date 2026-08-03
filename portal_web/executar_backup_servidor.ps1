$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot
if (!(Test-Path '.\.venv\Scripts\python.exe')) {
  py -3 -m venv .venv
  .\.venv\Scripts\python.exe -m pip install --upgrade pip
  .\.venv\Scripts\python.exe -m pip install -r requirements.txt
}
.\.venv\Scripts\python.exe .\executar_backup_servidor.py
