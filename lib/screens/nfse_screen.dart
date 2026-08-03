import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class NfseScreen extends StatelessWidget {
  const NfseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'NFS-e',
      subtitle:
          'Notas Fiscais de Serviço Eletrônicas com dados fiscais oficiais',
      icon: Icons.receipt_long_rounded,
      module: 'nfse',
      actionLabel: 'Registrar NFS-e',
      fields: <KristalModuleField>[
        KristalModuleField(
          key: 'numero',
          label: 'Número da NFS-e',
          icon: Icons.numbers_rounded,
          required: false,
        ),
        KristalModuleField(
          key: 'rps',
          label: 'RPS',
          icon: Icons.article_rounded,
        ),
        KristalModuleField(
          key: 'prestadorCnpj',
          label: 'CNPJ do prestador',
          icon: Icons.business_rounded,
        ),
        KristalModuleField(
          key: 'tomadorCpfCnpj',
          label: 'CPF/CNPJ do tomador',
          icon: Icons.badge_rounded,
        ),
        KristalModuleField(
          key: 'municipioCodigo',
          label: 'Código IBGE do município',
          icon: Icons.location_city_rounded,
        ),
        KristalModuleField(
          key: 'servicoCodigo',
          label: 'Código do serviço',
          icon: Icons.medical_services_rounded,
        ),
        KristalModuleField(
          key: 'valorServico',
          label: 'Valor do serviço',
          icon: Icons.payments_rounded,
        ),
        KristalModuleField(
          key: 'aliquotaIss',
          label: 'Alíquota ISS',
          icon: Icons.percent_rounded,
        ),
        KristalModuleField(
          key: 'endpointPrefeitura',
          label: 'Endpoint prefeitura / provedor NFS-e',
          icon: Icons.api_rounded,
        ),
        KristalModuleField(
          key: 'protocolo',
          label: 'Protocolo de autorização',
          icon: Icons.verified_user_rounded,
          required: false,
        ),
        KristalModuleField(
          key: 'status',
          label: 'Status fiscal',
          icon: Icons.fact_check_rounded,
        ),
        KristalModuleField(
          key: 'xmlPath',
          label: 'Caminho XML autorizado',
          icon: Icons.code_rounded,
          required: false,
        ),
      ],
      primaryColumns: <String>[
        'rps',
        'tomadorCpfCnpj',
        'valorServico',
        'status',
      ],
    );
  }
}
