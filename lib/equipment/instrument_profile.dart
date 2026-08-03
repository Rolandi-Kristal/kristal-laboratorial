class InstrumentProfile {
  final String fabricante, modelo, protocolo, observacao;
  const InstrumentProfile(this.fabricante, this.modelo, this.protocolo, this.observacao);
  static const perfis = [
    InstrumentProfile('Roche','Cobas','HL7/ASTM','Configurar mapa de testes conforme manual do equipamento.'),
    InstrumentProfile('Abbott','Architect/Alinity','HL7/ASTM','Requer homologação em bancada antes do uso assistencial.'),
    InstrumentProfile('Sysmex','XN/XS','ASTM/HL7','Hematologia com flags e histogramas conforme driver.'),
    InstrumentProfile('Mindray','BC/BS','ASTM/CSV','Ajustar separadores e códigos locais.'),
    InstrumentProfile('Siemens','Atellica/Dimension','HL7','Integração por ORU/ORM.'),
  ];
}
