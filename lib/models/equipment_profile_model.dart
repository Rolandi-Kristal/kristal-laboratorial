class EquipmentProfileModel {
  final String id,
      modelo,
      fabricante,
      protocolo,
      conexao,
      porta,
      ip,
      diretorioCsv,
      ativo,
      observacao;
  const EquipmentProfileModel(
      {required this.id,
      required this.modelo,
      required this.fabricante,
      required this.protocolo,
      required this.conexao,
      required this.porta,
      required this.ip,
      required this.diretorioCsv,
      required this.ativo,
      required this.observacao});
}
