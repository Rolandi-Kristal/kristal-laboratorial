import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../widgets/kristal_shell.dart';

class EstruturaScreen extends StatefulWidget {
  const EstruturaScreen({super.key});

  @override
  State<EstruturaScreen> createState() => _EstruturaScreenState();
}

class _EstruturaScreenState extends State<EstruturaScreen> {
  String _status = 'Estrutura pronta.';

  final List<String> _paths = <String>[
    AppConstants.dataDirectoryPath,
    AppConstants.driversDirectoryPath,
    AppConstants.sireDirectoryPath,
    AppConstants.hyperTerminalDirectoryPath,
    AppConstants.backupDirectoryPath,
    AppConstants.reportsDirectoryPath,
    AppConstants.exportsDirectoryPath,
    AppConstants.logsDirectoryPath,
  ];

  Future<void> _createAll() async {
    for (final String path in _paths) {
      await Directory(path).create(recursive: true);
    }
    setState(() {
      _status = 'Pastas reais criadas/validadas.';
    });
  }

  Future<void> _open(String path) async {
    await Directory(path).create(recursive: true);
    await Process.run('explorer.exe', <String>[path], runInShell: true);
  }

  @override
  Widget build(BuildContext context) {
    return KristalShell(
      title: 'Estrutura',
      subtitle: 'Pastas reais, drivers, SIRE, relatórios, backups e logs',
      icon: Icons.account_tree,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            ElevatedButton.icon(
              onPressed: _createAll,
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Criar / validar estrutura real'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: _paths.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  final String path = _paths[index];
                  return ListTile(
                    tileColor: const Color(0xFF0D2033),
                    leading: const Icon(Icons.folder, color: Color(0xFFFFC857)),
                    title: Text(
                      path,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      color: const Color(0xFF73D7FF),
                      onPressed: () => _open(path),
                    ),
                  );
                },
              ),
            ),
            Text(
              _status,
              style: const TextStyle(
                color: Color(0xFFFFC857),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
