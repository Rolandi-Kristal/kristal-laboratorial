import 'package:flutter/material.dart';

import '../services/lab_repository.dart';
import '../services/result_validation_service.dart';

class SimpleCrudScreen extends StatefulWidget {
  final String title;
  final String table;
  final List<String> fields;
  final List<String> visibleFields;

  const SimpleCrudScreen({
    super.key,
    required this.title,
    required this.table,
    required this.fields,
    required this.visibleFields,
  });

  @override
  State<SimpleCrudScreen> createState() => _SimpleCrudScreenState();
}

class _SimpleCrudScreenState extends State<SimpleCrudScreen> {
  final LabRepository repo = LabRepository();
  final TextEditingController filter = TextEditingController();
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> filtered = <Map<String, dynamic>>[];
  int selectedTab = 0;

  static const List<String> protectedTables = <String>[
    'pacientes',
    'pedidos',
    'amostras',
    'resultados',
    'laudos',
    'historico_exames_pacientes',
    'anexos',
    'auditoria',
    'etiquetas',
    'faturamento',
    'integracoes',
  ];

  @override
  void initState() {
    super.initState();
    load();
    filter.addListener(applyFilter);
  }

  @override
  void dispose() {
    filter.dispose();
    super.dispose();
  }

  Future<void> load() async {
    rows = await repo.all(widget.table);
    applyFilter();
  }

  void applyFilter() {
    final String query = filter.text.trim().toLowerCase();
    filtered = query.isEmpty
        ? List<Map<String, dynamic>>.of(rows)
        : rows.where((Map<String, dynamic> row) {
            return row.values.any((Object? value) =>
                value.toString().toLowerCase().contains(query));
          }).toList();

    if (mounted) {
      setState(() {});
    }
  }

  String labelFor(String field) {
    const Map<String, String> labels = <String, String>{
      'id': 'ID',
      'cpf': 'CPF',
      'cns': 'CNS',
      'preccp': 'PREC-CP',
      'criadoEm': 'Criado em',
      'coletadoEm': 'Coletado em',
      'liberadoEm': 'Liberado em',
      'equipamentoId': 'Equipamento',
      'pedidoId': 'Pedido',
      'amostraId': 'Amostra',
      'exameId': 'Exame',
      'valorReferencia': 'Valor de referência',
      'criticoBaixo': 'Crítico baixo',
      'criticoAlto': 'Crítico alto',
      'loinc': 'LOINC',
      'ip': 'IP',
    };

    if (labels.containsKey(field)) {
      return labels[field]!;
    }

    if (field.isEmpty) {
      return field;
    }

    return field[0].toUpperCase() + field.substring(1);
  }

  Future<void> addOrEdit([Map<String, dynamic>? row]) async {
    final Map<String, TextEditingController> controllers =
        <String, TextEditingController>{
      for (final String field in widget.fields)
        field: TextEditingController(text: row?[field]?.toString() ?? ''),
    };

    if (row == null) {
      if (controllers.containsKey('criadoEm')) {
        controllers['criadoEm']!.text = DateTime.now().toIso8601String();
      }
      if (controllers.containsKey('status')) {
        controllers['status']!.text = 'ATIVO';
      }
      if (controllers.containsKey('ativo')) {
        controllers['ativo']!.text = '1';
      }
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(row == null ? 'Novo registro' : 'Editar registro'),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                children: widget.fields
                    .where((String field) => field != 'id')
                    .map((String field) {
                  return SizedBox(
                    width: 350,
                    child: TextField(
                      controller: controllers[field],
                      decoration: InputDecoration(labelText: labelFor(field)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final Map<String, dynamic> data = <String, dynamic>{
        for (final String field in widget.fields)
          field: controllers[field]!.text.trim(),
      };

      if (widget.table == 'resultados') {
        data['critico'] = ResultValidationService.isCritical(
          data['valor']?.toString() ?? '',
          data['referencia']?.toString() ?? '',
        )
            ? 'SIM'
            : (data['critico']?.toString().isEmpty ?? true)
                ? 'NÃO'
                : data['critico'];
        data['status'] = (data['status']?.toString().trim().isEmpty ?? true)
            ? 'DIGITADO'
            : data['status'];
      }

      await repo.upsert(widget.table, data);
      await load();
    }
  }

  Future<void> archiveOrRemove(String id) async {
    final bool protected = protectedTables.contains(widget.table);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(protected ? 'Arquivar registro' : 'Confirmar remoção'),
          content: Text(
            protected
                ? 'Esta tabela clínica/laboratorial não terá exclusão física. O registro será preservado para consulta histórica e removido apenas da consulta recente.'
                : 'Esta ação será registrada em auditoria.',
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: Icon(protected
                  ? Icons.archive_rounded
                  : Icons.delete_outline_rounded),
              label: Text(protected ? 'Arquivar' : 'Remover'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (protected) {
      await repo.archiveWithoutDelete(
        widget.table,
        id,
        motivo: 'Registro preservado permanentemente para consulta histórica.',
      );
    } else {
      await repo.archiveWithoutDelete(widget.table, id, usuario: 'sistema');
    }

    await load();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> tabs = <String>[
      'Registros',
      'Individualizado',
      'Relatório',
      'Anexos',
      'Histórico',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
              tooltip: 'Atualizar',
              onPressed: load,
              icon: const Icon(Icons.refresh_rounded)),
          IconButton(
              tooltip: 'Novo',
              onPressed: () => addOrEdit(),
              icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: Row(
        children: <Widget>[
          _LegacyActionPanel(
            table: widget.table,
            onNew: () => addOrEdit(),
            onRefresh: load,
            onPrint: () => _showInfo('Impressão',
                'Use o módulo Laudos PDF ou relatórios para impressão oficial.'),
            onExport: () => _showInfo('Exportação',
                'Exportação direcionada ao módulo Relatórios/CSV.'),
            onExit: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                _ScreenHeader(
                    title: widget.title,
                    table: widget.table,
                    total: rows.length,
                    filtered: filtered.length),
                _FilterBar(controller: filter),
                _Tabs(
                  tabs: tabs,
                  selectedIndex: selectedTab,
                  onChanged: (int value) => setState(() => selectedTab = value),
                ),
                Expanded(
                  child: IndexedStack(
                    index: selectedTab,
                    children: <Widget>[
                      _RecordsTable(
                        rows: filtered,
                        fields: widget.fields,
                        visibleFields: widget.visibleFields,
                        labelFor: labelFor,
                        onEdit: addOrEdit,
                        onArchive: archiveOrRemove,
                      ),
                      _IndividualView(
                          rows: filtered,
                          visibleFields: widget.visibleFields,
                          labelFor: labelFor),
                      _ReportView(rows: filtered, title: widget.title),
                      const _PlaceholderOperationalTab(
                          icon: Icons.attach_file_rounded,
                          title: 'Anexos',
                          subtitle:
                              'Área preparada para documentos, imagens e PDFs vinculados ao registro selecionado.'),
                      _HistoryView(table: widget.table, rows: rows),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInfo(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        );
      },
    );
  }
}

class _LegacyActionPanel extends StatelessWidget {
  final String table;
  final VoidCallback onNew;
  final VoidCallback onRefresh;
  final VoidCallback onPrint;
  final VoidCallback onExport;
  final VoidCallback onExit;

  const _LegacyActionPanel({
    required this.table,
    required this.onNew,
    required this.onRefresh,
    required this.onPrint,
    required this.onExport,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 142,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF02A8B5),
            Color(0xFF047C8D),
            Color(0xFF073552)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(right: BorderSide(color: Color(0xFF0DBAC8))),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
        children: <Widget>[
          _ActionSection(
            title: 'Operações',
            buttons: <_ActionButtonData>[
              _ActionButtonData(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Novo',
                  onTap: onNew),
              _ActionButtonData(
                  icon: Icons.refresh_rounded,
                  label: 'Atualizar',
                  onTap: onRefresh),
              _ActionButtonData(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Confirmar',
                  onTap: onRefresh),
            ],
          ),
          _ActionSection(
            title: 'Relatório',
            buttons: <_ActionButtonData>[
              _ActionButtonData(
                  icon: Icons.print_rounded, label: 'Imprimir', onTap: onPrint),
              _ActionButtonData(
                  icon: Icons.description_rounded,
                  label: 'Resumo',
                  onTap: onPrint),
            ],
          ),
          _ActionSection(
            title: 'Exportar',
            buttons: <_ActionButtonData>[
              _ActionButtonData(
                  icon: Icons.file_download_rounded,
                  label: 'CSV',
                  onTap: onExport),
              _ActionButtonData(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'PDF',
                  onTap: onPrint),
            ],
          ),
          _ActionSection(
            title: 'Arquivos',
            buttons: <_ActionButtonData>[
              _ActionButtonData(
                  icon: Icons.attach_file_rounded,
                  label: 'Anexos',
                  onTap: onRefresh),
              _ActionButtonData(
                  icon: Icons.local_offer_rounded,
                  label: 'Etiqueta',
                  onTap: onPrint),
            ],
          ),
          const SizedBox(height: 12),
          _ActionSection(
            title: 'Outras opções',
            buttons: <_ActionButtonData>[
              _ActionButtonData(
                  icon: Icons.help_outline_rounded,
                  label: 'Ajuda',
                  onTap: _empty),
              _ActionButtonData(
                  icon: Icons.exit_to_app_rounded,
                  label: 'Sair',
                  onTap: onExit),
            ],
          ),
        ],
      ),
    );
  }

  static void _empty() {}
}

class _ActionSection extends StatelessWidget {
  final String title;
  final List<_ActionButtonData> buttons;

  const _ActionSection({required this.title, required this.buttons});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF83F4FF), width: 1.2),
        color: Colors.black.withOpacity(.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 6),
          for (final _ActionButtonData button in buttons)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: ElevatedButton.icon(
                onPressed: button.onTap,
                icon: Icon(button.icon, size: 16),
                label: Text(button.label, overflow: TextOverflow.ellipsis),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                  alignment: Alignment.centerLeft,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  final String title;
  final String table;
  final int total;
  final int filtered;

  const _ScreenHeader(
      {required this.title,
      required this.table,
      required this.total,
      required this.filtered});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: <Color>[Color(0xFF0CB7BD), Color(0xFF0A6B83)]),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: <Shadow>[
                    Shadow(offset: Offset(1, 1), blurRadius: 2)
                  ]),
            ),
          ),
          Text('Tabela: $table • Total: $total • Exibindo: $filtered',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController controller;

  const _FilterBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded),
          labelText:
              'Pesquisar por paciente, exame, código, pedido ou qualquer dado da tabela',
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _Tabs(
      {required this.tabs,
      required this.selectedIndex,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          final bool selected = selectedIndex == index;
          return ChoiceChip(
            selected: selected,
            label: Text(tabs[index]),
            onSelected: (_) => onChanged(index),
            selectedColor: const Color(0xFF123D63),
            backgroundColor: const Color(0xFF09233D),
            labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFFBFD7EA),
                fontWeight: FontWeight.w800),
            side: const BorderSide(color: Color(0xFF1B5E8F)),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: tabs.length,
      ),
    );
  }
}

class _RecordsTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final List<String> fields;
  final List<String> visibleFields;
  final String Function(String field) labelFor;
  final Future<void> Function([Map<String, dynamic>? row]) onEdit;
  final Future<void> Function(String id) onArchive;

  const _RecordsTable({
    required this.rows,
    required this.fields,
    required this.visibleFields,
    required this.labelFor,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('Nenhum registro cadastrado.'));
    }

    final List<String> tableFields = <String>[
      ...visibleFields,
      ...fields
          .where(
              (String field) => !visibleFields.contains(field) && field != 'id')
          .take(5),
    ];

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1180,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF0A2A4E)),
              columns: <DataColumn>[
                const DataColumn(label: Text('Ações')),
                for (final String field in tableFields)
                  DataColumn(label: Text(labelFor(field))),
              ],
              rows: rows.map((Map<String, dynamic> row) {
                return DataRow(
                  cells: <DataCell>[
                    DataCell(
                      Row(
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            onPressed: () => onEdit(row),
                          ),
                          IconButton(
                            tooltip: 'Arquivar/remover',
                            icon: const Icon(Icons.archive_rounded, size: 20),
                            onPressed: () => onArchive(row['id'].toString()),
                          ),
                        ],
                      ),
                    ),
                    for (final String field in tableFields)
                      DataCell(Text(row[field]?.toString() ?? '',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndividualView extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final List<String> visibleFields;
  final String Function(String field) labelFor;

  const _IndividualView(
      {required this.rows,
      required this.visibleFields,
      required this.labelFor});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('Nenhum registro disponível.'));
    }

    final Map<String, dynamic> row = rows.first;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Visualização individual',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: row.entries.map((MapEntry<String, dynamic> entry) {
                    return SizedBox(
                      width: 290,
                      child: InputDecorator(
                        decoration:
                            InputDecoration(labelText: labelFor(entry.key)),
                        child: Text(entry.value?.toString() ?? ''),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportView extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String title;

  const _ReportView({required this.rows, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Relatório: $title',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text('Total de registros filtrados: ${rows.length}',
                    style: const TextStyle(color: Color(0xFFBFD7EA))),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: rows.isEmpty ? 0 : 1),
                const SizedBox(height: 16),
                const Text(
                    'Área preparada para emissão oficial em PDF/CSV e integração com relatórios gerenciais.',
                    style: TextStyle(color: Color(0xFFE6F4FF))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryView extends StatelessWidget {
  final String table;
  final List<Map<String, dynamic>> rows;

  const _HistoryView({required this.table, required this.rows});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Card(
          child: ListTile(
            leading:
                const Icon(Icons.history_rounded, color: Color(0xFF79D7FF)),
            title: const Text('Histórico permanente'),
            subtitle: Text(
                'Tabela $table • ${rows.length} registro(s) preservado(s). Dados clínicos/laboratoriais não devem ser excluídos fisicamente.'),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderOperationalTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlaceholderOperationalTab(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 54, color: const Color(0xFF79D7FF)),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              SizedBox(
                  width: 460,
                  child: Text(subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFBFD7EA)))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButtonData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButtonData(
      {required this.icon, required this.label, required this.onTap});
}
