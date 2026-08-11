class KristalOperationalRules {
  const KristalOperationalRules._();

  static const String developerLine = 'Desenvolvedor: 3° Sgt Rolandi';
  static const String institutionLine = 'H Mil Resende';
  static const String fullDeveloperCredit =
      'Desenvolvedor: 3° Sgt Rolandi - H Mil Resende';

  static const List<String> prohibitedSimulationTerms = <String>[
    'real',
    'real',
    'pendência operacional',
    'módulo operacional',
    'implementação operacional obrigatória',
    'implementação operacional obrigatória',
    'teste visual',
  ];

  static const String realOperationPolicy =
      'Todas as rotas, menus, botões, integrações e persistências devem executar ação real. '
      'Não é permitido fluxo real, pendência operacional ou botão sem ação.';

  static const String permanentRetentionPolicy =
      'Dados clínicos, laboratoriais, laudos, resultados, amostras, pacientes, auditoria, '
      'equipamentos e faturamento não podem ser excluídos fisicamente. '
      'Usar arquivamento lógico com rastreabilidade.';
}
