# KRISTAL LABORATORIAL — Portal Web Real

Portal web funcional para o KRISTAL LABORATORIAL.

Recursos:
- Portal do paciente.
- Login por CPF e código.
- Consulta de exames recentes e histórico permanente.
- Download e impressão de PDF.
- Painel administrativo.
- Cadastro de pacientes.
- Cadastro de exames com PDF.
- SQLite local.
- Senha protegida por PBKDF2-HMAC-SHA256.
- Token assinado por HMAC-SHA256.
- Auditoria.
- Arquivamento lógico, sem exclusão física.

Instalação:

```bat
install_windows.bat
run_server.bat
```

Acesso:
- Paciente: https://127.0.0.1:8787
- Admin: https://127.0.0.1:8787/admin.html
