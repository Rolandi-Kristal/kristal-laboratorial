import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/update_service.dart';

class UpdateScreen extends StatefulWidget {
  final AuthSession session;

  const UpdateScreen({
    super.key,
    required this.session,
  });

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  final TextEditingController packagePath = TextEditingController();

  List<UpdatePackageInfo> packages = <UpdatePackageInfo>[];
  String mensagem = 'Nenhum pacote registrado nesta sessão.';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    packagePath.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final List<UpdatePackageInfo> data =
        await UpdateService.instance.listarPacotes();

    if (!mounted) return;

    setState(() {
      packages = data;
      loading = false;
    });
  }

  Future<void> _registrar() async {
    if (!widget.session.isSuperUser) {
      setState(() {
        mensagem = 'Somente o Superusuário pode registrar atualização.';
      });
      return;
    }

    try {
      final String path = await UpdateService.instance.registrarPacote(
        sourcePath: packagePath.text.trim(),
        usuario: widget.session.login,
      );

      if (!mounted) return;

      setState(() {
        mensagem = 'Pacote registrado em: $path';
      });

      await _load();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        mensagem = 'Erro ao registrar pacote: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool permitido = widget.session.isSuperUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atualizações do Sistema'),
        actions: <Widget>[
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update),
              title: const Text('Atualização controlada'),
              subtitle: Text(
                permitido
                    ? 'Registre pacotes de atualização locais para instalação controlada.'
                    : 'Acesso restrito ao Superusuário.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: packagePath,
            enabled: permitido,
            decoration: const InputDecoration(
              labelText: 'Caminho do pacote .zip/.msi/.msix/.exe',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: permitido ? _registrar : null,
            icon: const Icon(Icons.save),
            label: const Text('Registrar pacote'),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(mensagem),
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else
            ...packages.map(
              (UpdatePackageInfo package) => Card(
                child: ListTile(
                  leading: const Icon(Icons.archive),
                  title: Text('Versão: ${package.version}'),
                  subtitle: Text('${package.path}\nRegistrado em: ${package.createdAt}'),
                  isThreeLine: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
