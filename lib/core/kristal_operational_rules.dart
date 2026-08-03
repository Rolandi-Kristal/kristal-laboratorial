class KristalOperationalRules {
  const KristalOperationalRules._();

  static const String developerLine = 'Desenvolvedor: 3° Sgt Rolandi';
  static const String institutionLine = 'H Mil Resende';
  static const String fullDeveloperCredit =
      'Desenvolvedor: 3° Sgt Rolandi - H Mil Resende';

  static const List<String> prohibitedSimulationTerms = <String>[
    'real',
    'real',
    'pendÃªncia operacional',
    'mÃ³dulo operacional',
    'implementaÃ§Ã£o operacional obrigatÃ³ria',
    'implementaÃ§Ã£o operacional obrigatÃ³ria',
    'teste visual',
  ];

  static const String realOperationPolicy =
      'Todas as rotas, menus, botÃµes, integraÃ§Ãµes e persistÃªncias devem executar aÃ§Ã£o real. '
      'NÃ£o Ã© permitido fluxo real, pendÃªncia operacional ou botÃ£o sem aÃ§Ã£o.';

  static const String permanentRetentionPolicy =
      'Dados clÃ­nicos, laboratoriais, laudos, resultados, amostras, pacientes, auditoria, '
      'equipamentos e faturamento nÃ£o podem ser excluÃ­dos fisicamente. '
      'Usar arquivamento lÃ³gico com rastreabilidade.';
}
