import 'package:flutter/material.dart';

import '../models/hematology_driver_profile.dart';
import '../services/hematology_driver_registry_service.dart';
import '../services/hematology_protocol_adapter_service.dart';

class HematologyDriverCompatibilityScreen extends StatefulWidget {
  const HematologyDriverCompatibilityScreen({super.key});

  @override
  State<HematologyDriverCompatibilityScreen> createState() =>
      _HematologyDriverCompatibilityScreenState();
}

class _HematologyDriverCompatibilityScreenState
    extends State<HematologyDriverCompatibilityScreen> {
  final TextEditingController messageController = TextEditingController();
  final HematologyDriverRegistryService registry =
      HematologyDriverRegistryService.instance;
  final HematologyProtocolAdapterService adapter =
      HematologyProtocolAdapterService.instance;

  bool loading = true;
  String status = 'Carregando perfis de hematologia...';
  String parseResult = '';
  List<HematologyDriverProfile> profiles = <HematologyDriverProfile>[];

  @override
  void initState() {
    super.initState();
    loadProfiles();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> loadProfiles() async {
    setState(() => loading = true);

    try {
      final List<HematologyDriverProfile> rows = await registry.loadProfiles();
      final Map<String, Object?> validation = await registry.validateDriverPack();

      if (!mounted) return;

      setState(() {
        profiles = rows;
        status =
            'Perfis: ${rows.length}. Pacote copiado: ${validation['driverPackCopied']}. ExtraÃ­do: ${validation['driverPackExtracted']}.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => status = 'Falha ao carregar perfis: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void parseMessage() {
    final Map<String, Object?> result =
        adapter.parseIncomingMessage(messageController.text);

    setState(() {
      parseResult = adapter.toJson(result);
      status = 'Mensagem processada pelo adaptador de hematologia.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF06111D),
      child: Column(
        children: <Widget>[
          Container(
            height: 96,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            color: const Color(0xFF18344F),
            child: const Row(
              children: <Widget>[
                Icon(Icons.bloodtype_rounded, color: Color(0xFF73D7FF), size: 34),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Compatibilidade Hematologia',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      Text('Drivers 5100, 5180, 5300, 5380, ASTM, HL7, TCP/IP, COM e pasta monitorada',
                          style: TextStyle(color: Color(0xFFB7D7F1), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(18),
                          itemCount: profiles.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            return profileCard(profiles[index]);
                          },
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: <Widget>[
                              TextField(
                                controller: messageController,
                                minLines: 8,
                                maxLines: 14,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Mensagem ASTM / HL7 / TXT / CSV do equipamento',
                                  alignLabelWithHint: true,
                                  filled: true,
                                  fillColor: Color(0xFF071827),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: parseMessage,
                                icon: const Icon(Icons.integration_instructions),
                                label: const Text('Testar leitura da mensagem'),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D2033),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF244B6D)),
                                  ),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      parseResult.isEmpty ? 'Resultado do parser aparecerÃ¡ aqui.' : parseResult,
                                      style: const TextStyle(color: Color(0xFFB7D7F1), fontFamily: 'monospace'),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF06111D),
            child: Text(status, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFFC857), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget profileCard(HematologyDriverProfile profile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2033),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF244B6D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(profile.nome,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Modelo: ${profile.modelo} | Setor: ${profile.setor}',
              style: const TextStyle(color: Color(0xFFB7D7F1), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: profile.protocolos
                .map((String protocolo) => Chip(
                      label: Text(protocolo),
                      backgroundColor: const Color(0xFF071827),
                      labelStyle: const TextStyle(color: Color(0xFF73D7FF)),
                    ))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
