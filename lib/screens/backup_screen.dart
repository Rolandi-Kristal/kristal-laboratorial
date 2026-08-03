import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/backup_restore_service.dart';
import '../services/backup_scheduler_service.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  final AuthSession session;

  const BackupScreen({
    super.key,
    required this.session,
  });

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final TextEditingController restorePath = TextEditingController();
  final TextEditingController intervaloHoras = TextEditingController(text: '24');

  bool automatico = BackupSchedulerService.instance.enabled;
  String mensagem = 'Nenhum backup executado nesta sessão.';

  @override
  void dispose() {
    restorePath.dispose();
    intervaloHoras.dispose();
    super.dispose();
  }

  Future<void> _backupManual() async {
    final file = await BackupService.instance.criarBackupManual();

    if (!mounted) return;

    setState(() {
      mensagem = 'Backup criptografado criado em: ${file.path}';
    });
  }

  void _toggleAutomatico(bool value) {
    final int horas = int.tryParse(intervaloHoras.text.trim()) ?? 24;
    BackupSchedulerService.instance.configure(
      enabled: value,
      interval: Duration(hours: horas <= 0 ? 24 : horas),
    );

    setState(() {
      automatico = value;
      mensagem = value
          ? 'Backup automático ativado a cada ${horas <= 0 ? 24 : horas} hora(s).'
          : 'Backup automático desativado.';
    });
  }

  Future<void> _restaurar() async {
    try {
      await BackupRestoreService.instance.restaurarBackup(
        session: widget.session,
        backupPath: restorePath.text.trim(),
      );

      if (!mounted) return;

      setState(() => mensagem = 'Backup restaurado com sucesso.');
    } catch (e) {
      if (!mounted) return;

      setState(() => mensagem = 'Falha ao restaurar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canRestore = widget.session.isSuperUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup e Restauração'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup manual criptografado'),
              subtitle: const Text('Gera arquivo .krbak protegido.'),
              trailing: ElevatedButton.icon(
                onPressed: _backupManual,
                icon: const Icon(Icons.save),
                label: const Text('Gerar agora'),
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: intervaloHoras,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Intervalo do backup automático em horas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Backup automático'),
                    subtitle: const Text('Executa cópias criptografadas em segundo plano enquanto o app estiver aberto.'),
                    value: automatico,
                    onChanged: _toggleAutomatico,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(mensagem),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Restauração de backup',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: restorePath,
                    enabled: canRestore,
                    decoration: const InputDecoration(
                      labelText: 'Caminho do arquivo .krbak',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: canRestore ? _restaurar : null,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurar backup'),
                  ),
                  if (!canRestore)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Somente o Superusuário pode restaurar backup.',
                        style: TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
