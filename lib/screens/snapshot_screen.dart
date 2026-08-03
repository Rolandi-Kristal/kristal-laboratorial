import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/database_export_snapshot_service.dart';

class SnapshotScreen extends StatefulWidget {
  final AuthSession session;

  const SnapshotScreen({
    super.key,
    required this.session,
  });

  @override
  State<SnapshotScreen> createState() => _SnapshotScreenState();
}

class _SnapshotScreenState extends State<SnapshotScreen> {
  bool running = false;
  String mensagem = 'Nenhum snapshot exportado nesta sessão.';

  Future<void> _exportar() async {
    if (!widget.session.isAdmin) {
      setState(() {
        mensagem = 'Acesso restrito ao Superusuário e Administrador.';
      });
      return;
    }

    setState(() {
      running = true;
      mensagem = 'Exportando snapshot criptografado...';
    });

    try {
      final String path =
          await DatabaseExportSnapshotService.instance.exportarSnapshotCriptografado(
        usuario: widget.session.login,
      );

      if (!mounted) return;

      setState(() {
        mensagem = 'Snapshot criptografado criado em: $path';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        mensagem = 'Erro ao exportar snapshot: $e';
      });
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool permitido = widget.session.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snapshot Criptografado'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Exportação completa criptografada'),
              subtitle: Text(
                permitido
                    ? 'Gera arquivo .krsnap com dados do sistema protegidos por AES-GCM.'
                    : 'Acesso restrito ao Superusuário e Administrador.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: permitido && !running ? _exportar : null,
            icon: running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.enhanced_encryption),
            label: Text(running ? 'Exportando...' : 'Exportar snapshot'),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(mensagem),
            ),
          ),
        ],
      ),
    );
  }
}
