import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/faturamento_sire_service.dart';

class FaturamentoSireScreen extends StatefulWidget {
  final AuthSession session;

  const FaturamentoSireScreen({
    super.key,
    required this.session,
  });

  @override
  State<FaturamentoSireScreen> createState() => _FaturamentoSireScreenState();
}

class _FaturamentoSireScreenState extends State<FaturamentoSireScreen> {
  final TextEditingController exePathController = TextEditingController();
  final TextEditingController pastaBaseController = TextEditingController();
  final TextEditingController observacaoController = TextEditingController();

  bool ativo = false;
  bool loading = true;
  bool processing = false;
  String status = 'Carregando integração do Faturamento SIRE...';

  bool get canEdit => widget.session.isAdmin;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    exePathController.dispose();
    pastaBaseController.dispose();
    observacaoController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      loading = true;
      status = 'Carregando integração do Faturamento SIRE...';
    });

    try {
      final FaturamentoSireConfig config =
          await FaturamentoSireService.instance.carregar();

      if (!mounted) return;

      setState(() {
        exePathController.text = config.exePath;
        pastaBaseController.text = config.pastaBase;
        observacaoController.text = config.observacao;
        ativo = config.isAtivo;
        loading = false;
        status = 'Integração carregada.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        status = 'Erro ao carregar integração: $e';
      });
    }
  }

  Future<void> _localizarAutomaticamente() async {
    if (!canEdit) {
      setState(() {
        status =
            'Somente Superusuário ou Administrador pode configurar o Faturamento SIRE.';
      });
      return;
    }

    final String pastaBase = pastaBaseController.text.trim();

    if (pastaBase.isEmpty) {
      setState(() {
        status =
            'Informe a pasta base onde os drivers/módulos estão armazenados.';
      });
      return;
    }

    setState(() {
      processing = true;
      status = 'Procurando executável do Faturamento SIRE...';
    });

    try {
      final String encontrado =
          await FaturamentoSireService.instance.localizarExeAutomatico(
        pastaRaiz: pastaBase,
      );

      if (!mounted) return;

      if (encontrado.isEmpty) {
        setState(() {
          processing = false;
          status =
              'Executável do Faturamento SIRE não encontrado na pasta informada.';
        });
        return;
      }

      setState(() {
        exePathController.text = encontrado;
        processing = false;
        status = 'Executável localizado: $encontrado';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        processing = false;
        status = 'Erro ao localizar executável: $e';
      });
    }
  }

  Future<void> _salvar() async {
    if (!canEdit) {
      setState(() {
        status =
            'Somente Superusuário ou Administrador pode salvar esta configuração.';
      });
      return;
    }

    final String exePath = exePathController.text.trim();

    if (ativo && exePath.isEmpty) {
      setState(() {
        status =
            'Informe o caminho do executável antes de ativar a integração.';
      });
      return;
    }

    if (ativo) {
      final bool valido =
          await FaturamentoSireService.instance.validarExecutavel(exePath);

      if (!valido) {
        setState(() {
          status = 'Executável inválido ou inexistente: $exePath';
        });
        return;
      }
    }

    setState(() {
      processing = true;
      status = 'Salvando configuração do Faturamento SIRE...';
    });

    try {
      await FaturamentoSireService.instance.salvar(
        session: widget.session,
        config: FaturamentoSireConfig(
          exePath: exePathController.text.trim(),
          pastaBase: pastaBaseController.text.trim(),
          ativo: ativo ? '1' : '0',
          observacao: observacaoController.text.trim(),
        ),
      );

      if (!mounted) return;

      setState(() {
        processing = false;
        status = 'Configuração do Faturamento SIRE salva com sucesso.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        processing = false;
        status = 'Erro ao salvar configuração: $e';
      });
    }
  }

  Future<void> _abrirSire() async {
    setState(() {
      processing = true;
      status = 'Abrindo Faturamento SIRE...';
    });

    try {
      await FaturamentoSireService.instance.abrir(
        session: widget.session,
      );

      if (!mounted) return;

      setState(() {
        processing = false;
        status = 'Faturamento SIRE aberto.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        processing = false;
        status = 'Erro ao abrir Faturamento SIRE: $e';
      });
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled && !processing,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _statusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            if (processing) ...<Widget>[
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
            ] else ...<Widget>[
              const Icon(Icons.info_outline),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                status,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faturamento SIRE'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Recarregar',
            onPressed: processing ? null : _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: <Widget>[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.payments),
                    title: const Text('Integração com Faturamento SIRE'),
                    subtitle: Text(
                      canEdit
                          ? 'Configure o executável do FaturamentoSIRE_Externos.exe.'
                          : 'Configuração restrita ao Superusuário e Administrador.',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _field(
                  controller: pastaBaseController,
                  label:
                      r'Pasta base dos módulos/drivers. Ex: D:\kristal_laboratorial\drivers',
                  icon: Icons.folder,
                  enabled: canEdit,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: exePathController,
                  label: 'Caminho do FaturamentoSIRE_Externos.exe',
                  icon: Icons.terminal,
                  enabled: canEdit,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Integração ativa'),
                  subtitle: const Text(
                    'Quando ativo, o sistema permite abrir o Faturamento SIRE.',
                  ),
                  value: ativo,
                  onChanged: canEdit && !processing
                      ? (bool value) {
                          setState(() => ativo = value);
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: observacaoController,
                  label: 'Observações técnicas',
                  icon: Icons.notes,
                  enabled: canEdit,
                  maxLines: 3,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    ElevatedButton.icon(
                      onPressed: canEdit && !processing
                          ? _localizarAutomaticamente
                          : null,
                      icon: const Icon(Icons.search),
                      label: const Text('Localizar automaticamente'),
                    ),
                    ElevatedButton.icon(
                      onPressed: canEdit && !processing ? _salvar : null,
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar'),
                    ),
                    ElevatedButton.icon(
                      onPressed: processing ? null : _abrirSire,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir SIRE'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _statusCard(),
              ],
            ),
    );
  }
}
