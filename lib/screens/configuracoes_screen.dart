import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../services/backup_scheduler_service.dart';
import '../services/config_service.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  final TextEditingController laboratorioController = TextEditingController();
  final TextEditingController responsavelController = TextEditingController();
  final TextEditingController conselhoController = TextEditingController();
  final TextEditingController portalController = TextEditingController();
  final TextEditingController backupHoraController = TextEditingController();

  bool loading = true;
  String mensagem = 'Configurações do sistema.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    laboratorioController.dispose();
    responsavelController.dispose();
    conselhoController.dispose();
    portalController.dispose();
    backupHoraController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ConfigService config = ConfigService.instance;

    laboratorioController.text = await config.getValue(
      'laboratorio_nome',
      defaultValue: AppConstants.institutionName,
    );
    responsavelController.text = await config.getValue(
      'responsavel_tecnico',
      defaultValue: '',
    );
    conselhoController.text = await config.getValue(
      'responsavel_conselho',
      defaultValue: '',
    );
    portalController.text = await config.getValue(
      'portal_paciente_url',
      defaultValue: '',
    );
    backupHoraController.text = await config.getValue(
      'backup_automatico_hora',
      defaultValue: '23:00',
    );

    if (!mounted) return;

    setState(() => loading = false);
  }

  Future<void> _save() async {
    final ConfigService config = ConfigService.instance;
    final String horarioBackup = backupHoraController.text.trim();
    try {
      BackupSchedulerService.parseAllowedTime(horarioBackup);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => mensagem = error.message);
      return;
    }

    await config.setValue(
        'laboratorio_nome', laboratorioController.text.trim());
    await config.setValue(
      'responsavel_tecnico',
      responsavelController.text.trim(),
    );
    await config.setValue(
        'responsavel_conselho', conselhoController.text.trim());
    await config.setValue('portal_paciente_url', portalController.text.trim());
    await config.setValue(
      'backup_automatico_hora',
      horarioBackup,
    );

    BackupSchedulerService.instance.configureDaily(
      enabled: true,
      horario: horarioBackup,
    );

    if (!mounted) return;

    setState(() => mensagem = 'Configurações salvas com sucesso.');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações salvas.')),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: <Widget>[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Configurações gerais'),
                    subtitle: Text(mensagem),
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  controller: laboratorioController,
                  label: 'Nome do laboratório / instituição',
                  icon: Icons.business,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: responsavelController,
                  label: 'Responsável técnico',
                  icon: Icons.verified_user,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: conselhoController,
                  label: 'Conselho / Registro profissional',
                  icon: Icons.badge,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: portalController,
                  label: 'URL do portal do paciente',
                  icon: Icons.language,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: backupHoraController,
                  label: 'Horário do backup automático (18:00 a 03:59)',
                  icon: Icons.schedule,
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar configurações'),
                ),
              ],
            ),
    );
  }
}
