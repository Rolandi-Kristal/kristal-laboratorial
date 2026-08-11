import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/equipment_connection_config.dart';
import '../services/auth_service.dart';
import '../services/equipment_connection_service.dart';
import '../services/result_import_service.dart';

class ImportarResultadoScreen extends StatefulWidget {
  final AuthSession session;

  const ImportarResultadoScreen({
    super.key,
    required this.session,
  });

  @override
  State<ImportarResultadoScreen> createState() =>
      _ImportarResultadoScreenState();
}

class _ImportarResultadoScreenState extends State<ImportarResultadoScreen> {
  final TextEditingController entrada = TextEditingController();
  final TextEditingController saida = TextEditingController();

  List<EquipmentConnectionConfig> equipments =
      const <EquipmentConnectionConfig>[];
  String? equipmentId;
  bool importing = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadEquipments();
  }

  @override
  void dispose() {
    entrada.dispose();
    saida.dispose();
    super.dispose();
  }

  Future<void> _loadEquipments() async {
    final List<EquipmentConnectionConfig> data =
        await EquipmentConnectionService.instance.listar();
    final List<EquipmentConnectionConfig> active =
        data.where((EquipmentConnectionConfig item) => item.isAtivo).toList();
    if (!mounted) return;
    setState(() {
      equipments = active;
      equipmentId = active.isEmpty ? null : active.first.id;
      loading = false;
    });
  }

  Future<void> _importar() async {
    if (importing) return;
    final EquipmentConnectionConfig? equipment =
        equipments.where((item) => item.id == equipmentId).firstOrNull;
    if (equipment == null) {
      saida.text = 'Selecione um equipamento ativo e configurado.';
      return;
    }

    setState(() => importing = true);
    try {
      final Map<String, dynamic> resultado =
          await ResultImportService.instance.importarMensagem(
        equipmentId: equipment.id,
        protocolo: equipment.protocolo,
        mensagem: entrada.text,
        usuario: widget.session.login,
      );
      saida.text = const JsonEncoder.withIndent('  ').convert(resultado);
    } on ArgumentError catch (error) {
      saida.text = 'Entrada inválida: ${error.message}';
    } on FormatException catch (error) {
      saida.text = 'Mensagem incompatível: ${error.message}';
    } on StateError catch (error) {
      saida.text = 'Importação bloqueada: ${error.message}';
    } on DatabaseException catch (error) {
      saida.text = 'Falha ao persistir o resultado: $error';
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Resultado de Equipamento'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Atualizar equipamentos',
            onPressed: loading ? null : _loadEquipments,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          DropdownButtonFormField<String>(
            value: equipmentId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Equipamento e protocolo',
              prefixIcon: Icon(Icons.precision_manufacturing),
              border: OutlineInputBorder(),
            ),
            items: equipments
                .map(
                  (EquipmentConnectionConfig item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text('${item.nome} • ${item.protocolo}'),
                  ),
                )
                .toList(),
            onChanged: loading
                ? null
                : (String? value) => setState(() => equipmentId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: entrada,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Mensagem recebida do equipamento',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed:
                importing || loading || equipments.isEmpty ? null : _importar,
            icon: importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload),
            label: Text(importing ? 'Importando...' : 'Importar resultado'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: saida,
            readOnly: true,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Rastreabilidade da importação',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
