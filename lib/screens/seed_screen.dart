import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/seed_service.dart';

class SeedScreen extends StatefulWidget {
  final AuthSession session;

  const SeedScreen({
    super.key,
    required this.session,
  });

  @override
  State<SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<SeedScreen> {
  bool running = false;
  String mensagem = 'Base inicial ainda não instalada nesta sessão.';

  Future<void> _instalar() async {
    if (!widget.session.isSuperUser) {
      setState(() {
        mensagem = 'Somente o Superusuário pode instalar a base inicial.';
      });
      return;
    }

    setState(() {
      running = true;
      mensagem = 'Instalando base inicial...';
    });

    try {
      await SeedService.instance.instalarBaseInicial();

      if (!mounted) return;

      setState(() {
        mensagem =
            'Base inicial instalada: exames básicos, equipamentos e materiais.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        mensagem = 'Erro ao instalar base inicial: $e';
      });
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool permitido = widget.session.isSuperUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instalação da Base Inicial'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: const Text('Base inicial operacional'),
              subtitle: Text(
                permitido
                    ? 'Instala exames básicos, perfis de equipamentos e materiais iniciais.'
                    : 'Acesso restrito ao Superusuário.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: permitido && !running ? _instalar : null,
            icon: running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_done),
            label: Text(running ? 'Instalando...' : 'Instalar base inicial'),
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
