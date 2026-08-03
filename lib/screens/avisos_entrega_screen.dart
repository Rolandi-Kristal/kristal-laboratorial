import 'package:flutter/material.dart';

import 'kristal_real_module_screen.dart';

class AvisosEntregaScreen extends StatelessWidget {
  const AvisosEntregaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KristalRealModuleScreen(
      title: 'Avisos e Entrega',
      subtitle:
          'E-mail, SMS, portal do paciente, QR Code e rastreio de entrega',
      icon: Icons.mark_email_read_rounded,
      module: 'avisos_entrega',
      actionLabel: 'Registrar aviso',
      fields: <KristalModuleField>[
        KristalModuleField(
          key: 'paciente',
          label: 'Paciente',
          icon: Icons.person_rounded,
        ),
        KristalModuleField(
          key: 'cpf',
          label: 'CPF',
          icon: Icons.badge_rounded,
        ),
        KristalModuleField(
          key: 'laudoId',
          label: 'Laudo / Pedido',
          icon: Icons.picture_as_pdf_rounded,
        ),
        KristalModuleField(
          key: 'canal',
          label: 'Canal (EMAIL, SMS, PORTAL, QR_CODE)',
          icon: Icons.hub_rounded,
        ),
        KristalModuleField(
          key: 'destinatario',
          label: 'E-mail ou celular',
          icon: Icons.contact_mail_rounded,
        ),
        KristalModuleField(
          key: 'portalUrl',
          label: 'URL do portal / QR Code',
          icon: Icons.qr_code_rounded,
        ),
        KristalModuleField(
          key: 'endpointEnvio',
          label: 'Endpoint oficial do provedor',
          icon: Icons.api_rounded,
          required: false,
        ),
        KristalModuleField(
          key: 'protocoloEnvio',
          label: 'Protocolo de envio',
          icon: Icons.confirmation_number_rounded,
          required: false,
        ),
        KristalModuleField(
          key: 'statusEntrega',
          label: 'Status da entrega',
          icon: Icons.verified_rounded,
        ),
        KristalModuleField(
          key: 'mensagem',
          label: 'Mensagem enviada',
          icon: Icons.notes_rounded,
          maxLines: 3,
        ),
      ],
      primaryColumns: <String>[
        'paciente',
        'canal',
        'destinatario',
        'statusEntrega',
      ],
    );
  }
}
