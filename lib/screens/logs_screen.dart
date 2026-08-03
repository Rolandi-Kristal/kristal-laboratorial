import 'dart:io';

import 'package:flutter/material.dart';

import '../services/log_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String folder = '';
  List<File> files = <File>[];
  String selectedContent = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    folder = await LogService.instance.logFolderPath();

    final Directory dir = Directory(folder);
    final List<FileSystemEntity> entities = await dir.list().toList();

    files = entities.whereType<File>().toList()
      ..sort(
        (File a, File b) =>
            b.statSync().modified.compareTo(a.statSync().modified),
      );

    if (!mounted) return;

    setState(() => loading = false);
  }

  Future<void> _open(File file) async {
    final String content = await file.readAsString();

    if (!mounted) return;

    setState(() {
      selectedContent = content;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs do Sistema'),
        actions: <Widget>[
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: <Widget>[
                SizedBox(
                  width: 360,
                  child: Column(
                    children: <Widget>[
                      Card(
                        child: ListTile(
                          title: const Text('Pasta de logs'),
                          subtitle: Text(folder),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: files.length,
                          itemBuilder: (BuildContext context, int index) {
                            final File file = files[index];

                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.description),
                                title: Text(file.path.split(Platform.pathSeparator).last),
                                subtitle: Text(
                                  'Alterado: ${file.statSync().modified}',
                                ),
                                onTap: () => _open(file),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: TextEditingController(text: selectedContent),
                      readOnly: true,
                      expands: true,
                      maxLines: null,
                      decoration: const InputDecoration(
                        labelText: 'Conteúdo do log',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
