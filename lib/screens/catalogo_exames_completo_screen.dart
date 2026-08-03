import 'package:flutter/material.dart';

import '../models/lab_exam_definition.dart';
import '../services/lab_exam_catalog_service.dart';
import '../widgets/kristal_shell.dart';

class CatalogoExamesCompletoScreen extends StatefulWidget {
  const CatalogoExamesCompletoScreen({super.key});

  @override
  State<CatalogoExamesCompletoScreen> createState() =>
      _CatalogoExamesCompletoScreenState();
}

class _CatalogoExamesCompletoScreenState
    extends State<CatalogoExamesCompletoScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<LabExamDefinition> _items = LabExamCatalogService.instance.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() {
      _items = LabExamCatalogService.instance.search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return KristalShell(
      title: 'Catálogo Completo de Exames',
      subtitle: 'Exames laboratoriais por MNE, setor, material e código SIRE',
      icon: Icons.biotech,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: _search,
              decoration: const InputDecoration(
                labelText: 'Buscar exame, MNE, setor, material ou código SIRE',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Color(0xFF071827),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  final LabExamDefinition exam = _items[index];
                  return ListTile(
                    tileColor: const Color(0xFF0D2033),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFF244B6D)),
                    ),
                    leading: const Icon(Icons.science, color: Color(0xFF73D7FF)),
                    title: Text(
                      '${exam.code} • ${exam.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${exam.sector} • ${exam.material} • SIRE: ${exam.sireCode}',
                      style: const TextStyle(color: Color(0xFFB7D7F1)),
                    ),
                    trailing: exam.isCriticalTrackable
                        ? const Icon(Icons.warning, color: Color(0xFFFFC857))
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
