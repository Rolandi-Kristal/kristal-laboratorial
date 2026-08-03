import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class AmostrasScreen extends StatelessWidget {
  const AmostrasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Amostras / Coleta de Exames',
      subtitle:
          'Coleta, identificação completa do exame, tubo, etiqueta e rastreabilidade',
      icon: Icons.qr_code_2_rounded,
      module: 'amostras',
      fields: <KristalModuleField>[
        KristalModuleField(
          key: 'atendimento',
          label: 'Número do atendimento / guia',
          icon: Icons.confirmation_number_rounded,
          maxLines: 1,
          required: true,
        ),
        KristalModuleField(
          key: 'etiqueta',
          label: 'Etiqueta / código de barras da amostra',
          icon: Icons.qr_code_rounded,
          maxLines: 1,
          required: true,
        ),
        KristalModuleField(
          key: 'paciente',
          label: 'Paciente',
          icon: Icons.person_rounded,
          maxLines: 1,
          required: true,
        ),
        KristalModuleField(
          key: 'cpf_preccp',
          label: 'CPF / PREC-CP / identificação militar',
          icon: Icons.badge_rounded,
          maxLines: 1,
          required: false,
        ),
        KristalModuleField(
          key: 'exames',
          label: 'Exames solicitados - MNE, descrição e código SIRE',
          icon: Icons.biotech_rounded,
          maxLines: 3,
          required: true,
        ),
        KristalModuleField(
          key: 'material',
          label: 'Material biológico',
          icon: Icons.science_rounded,
          maxLines: 1,
          required: true,
        ),
        KristalModuleField(
          key: 'tubo',
          label: 'Tubo / recipiente / conservante',
          icon: Icons.bloodtype_rounded,
          maxLines: 1,
          required: true,
        ),
        KristalModuleField(
          key: 'setor',
          label: 'Setor técnico',
          icon: Icons.account_tree_rounded,
          maxLines: 1,
          required: true,
        ),
        KristalModuleField(
          key: 'data_hora_coleta',
          label: 'Data e hora da coleta',
          icon: Icons.event_available_rounded,
          maxLines: 1,
          required: true,
        ),
        KristalModuleField(
          key: 'coletador',
          label: 'Profissional coletador',
          icon: Icons.assignment_ind_rounded,
          maxLines: 1,
          required: true,
        ),
        KristalModuleField(
          key: 'status',
          label: 'Status da amostra',
          icon: Icons.fact_check_rounded,
          maxLines: 1,
          required: true,
        ),
        KristalModuleField(
          key: 'observacao',
          label: 'Observações de coleta / preparo / restrições',
          icon: Icons.notes_rounded,
          maxLines: 3,
          required: false,
        ),
      ],
      primaryColumns: <String>[
        'atendimento',
        'etiqueta',
        'paciente',
        'exames',
        'material',
        'tubo',
        'status',
      ],
    );
  }
}
