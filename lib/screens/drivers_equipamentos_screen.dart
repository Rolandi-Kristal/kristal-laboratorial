import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/lab_driver_profile_service.dart';

class DriversEquipamentosScreen extends StatefulWidget {
  final AuthSession session;

  const DriversEquipamentosScreen({
    super.key,
    required this.session,
  });

  @override
  State<DriversEquipamentosScreen> createState() =>
      _DriversEquipamentosScreenState();
}

class _DriversEquipamentosScreenState extends State<DriversEquipamentosScreen> {
  final TextEditingController rootPathController = TextEditingController();

  List<Map<String, dynamic>> drivers = <Map<String, dynamic>>[];
  bool loading = true;
  String mensagem =
      'Cadastre o caminho raiz onde os drivers estão armazenados.';

  @override
  void initState() {
    super.initState();
    _initRoot();
    _load();
  }

  @override
  void dispose() {
    rootPathController.dispose();
    super.dispose();
  }

  Future<void> _initRoot() async {
    final String root =
        await LabDriverProfileService.instance.defaultDriversRootPath();

    if (!mounted) return;

    setState(() {
      rootPathController.text = root;
    });
  }

  Future<void> _load() async {
    final List<Map<String, dynamic>> data =
        await LabDriverProfileService.instance.listarDrivers();

    if (!mounted) return;

    setState(() {
      drivers = data;
      loading = false;
    });
  }

  Future<void> _instalarPerfis() async {
    if (!widget.session.isAdmin) {
      setState(() {
        mensagem = 'Acesso restrito ao Superusuário e Administrador.';
      });
      return;
    }

    setState(() {
      loading = true;
      mensagem = 'Instalando perfis de drivers laboratoriais...';
    });

    await LabDriverProfileService.instance.instalarPerfis(
      rootPath: rootPathController.text.trim(),
      usuario: widget.session.login,
    );

    await _load();

    if (!mounted) return;

    setState(() {
      mensagem = 'Perfis de drivers instalados/atualizados.';
    });
  }

  Future<void> _verificar() async {
    setState(() {
      loading = true;
      mensagem = 'Verificando arquivos de drivers...';
    });

    final List<Map<String, dynamic>> checked =
        await LabDriverProfileService.instance.verificarTodos();

    if (!mounted) return;

    setState(() {
      drivers = checked;
      loading = false;
      mensagem = 'Verificação concluída.';
    });
  }

  Color? _statusColor(Map<String, dynamic> row) {
    final String pasta = row['pastaExiste']?.toString() ?? '';
    final String driver = row['driverExiste']?.toString() ?? '';
    final String exe = row['configuradorExiste']?.toString() ?? '';

    if (pasta == 'SIM' && (driver == 'SIM' || exe == 'SIM')) {
      return Colors.green.withValues(alpha: 0.12);
    }

    if (pasta == 'NÃO') {
      return Colors.red.withValues(alpha: 0.12);
    }

    return Colors.orange.withValues(alpha: 0.12);
  }

  @override
  Widget build(BuildContext context) {
    final bool permitido = widget.session.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivers dos Equipamentos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Atualizar lista',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Verificar arquivos',
            onPressed: _verificar,
            icon: const Icon(Icons.fact_check),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(14),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      mensagem,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rootPathController,
                      enabled: permitido,
                      decoration: const InputDecoration(
                        labelText: 'Caminho raiz dos drivers',
                        hintText: r'D:\kristal_laboratorial\drivers',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: <Widget>[
                        ElevatedButton.icon(
                          onPressed: permitido ? _instalarPerfis : null,
                          icon: const Icon(Icons.install_desktop),
                          label: const Text('Instalar perfis'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _verificar,
                          icon: const Icon(Icons.search),
                          label: const Text('Verificar drivers'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : drivers.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum perfil cadastrado. Clique em Instalar perfis.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: drivers.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Map<String, dynamic> row = drivers[index];

                          return Card(
                            color: _statusColor(row),
                            child: ListTile(
                              leading: const Icon(Icons.memory),
                              title: Text(
                                '${row['nome'] ?? ''} • ${row['modelo'] ?? ''}',
                              ),
                              subtitle: Text(
                                'Protocolo: ${row['protocolo'] ?? ''}\n'
                                'Pasta: ${row['pastaRelativa'] ?? ''}\n'
                                'Driver: ${row['arquivoDriver'] ?? ''} | Config: ${row['executavelConfiguracao'] ?? ''}\n'
                                'Pasta existe: ${row['pastaExiste'] ?? 'não verificado'} | Driver: ${row['driverExiste'] ?? 'não verificado'} | Configurador: ${row['configuradorExiste'] ?? 'não verificado'}',
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
