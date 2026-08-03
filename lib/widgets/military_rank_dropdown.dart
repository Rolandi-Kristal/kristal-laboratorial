import 'package:flutter/material.dart';

import '../core/military_rank_rules.dart';

class MilitaryRankDropdown extends StatefulWidget {
  const MilitaryRankDropdown({
    super.key,
    required this.controller,
    this.label = 'Posto / Graduação',
    this.icon = Icons.military_tech_rounded,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String>? onChanged;

  @override
  State<MilitaryRankDropdown> createState() => _MilitaryRankDropdownState();
}

class _MilitaryRankDropdownState extends State<MilitaryRankDropdown> {
  late String _graduacao;
  late String _posto;

  @override
  void initState() {
    super.initState();
    final MilitaryRankSelection selection =
        MilitaryRankRules.parse(widget.controller.text);
    _graduacao = MilitaryRankRules.graduacoes.contains(selection.graduacao)
        ? selection.graduacao
        : '';
    _posto = selection.posto;
  }

  @override
  void didUpdateWidget(covariant MilitaryRankDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final MilitaryRankSelection selection =
          MilitaryRankRules.parse(widget.controller.text);
      _graduacao = MilitaryRankRules.graduacoes.contains(selection.graduacao)
          ? selection.graduacao
          : '';
      _posto = selection.posto;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> postos = MilitaryRankRules.postos(_graduacao);
    final bool showPosto = postos.isNotEmpty;

    return Column(
      children: <Widget>[
        DropdownButtonFormField<String>(
          value: _graduacao.isEmpty ? null : _graduacao,
          menuMaxHeight: 320,
          isExpanded: true,
          dropdownColor: const Color(0xFF0D2033),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon),
            filled: true,
            fillColor: const Color(0xFF071827),
            border: const OutlineInputBorder(),
          ),
          items: MilitaryRankRules.graduacoes
              .map(
                (String item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(growable: false),
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            setState(() {
              _graduacao = value;
              final List<String> allowedPostos =
                  MilitaryRankRules.postos(value);
              _posto = allowedPostos.contains(_posto) ? _posto : '';
            });
            _emit();
          },
        ),
        if (showPosto) ...<Widget>[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _posto.isEmpty ? null : _posto,
            menuMaxHeight: 240,
            isExpanded: true,
            dropdownColor: const Color(0xFF0D2033),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Posto',
              prefixIcon: Icon(Icons.workspace_premium_rounded),
              filled: true,
              fillColor: Color(0xFF071827),
              border: OutlineInputBorder(),
            ),
            items: postos
                .map(
                  (String item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() {
                _posto = value;
              });
              _emit();
            },
          ),
        ],
      ],
    );
  }

  void _emit() {
    final String value = MilitaryRankRules.montar(
      graduacao: _graduacao,
      posto: _posto,
    );
    widget.controller.text = value;
    widget.onChanged?.call(value);
  }
}
