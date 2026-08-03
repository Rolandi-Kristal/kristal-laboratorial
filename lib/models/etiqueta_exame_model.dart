class EtiquetaExameModel {
  final String id, pacienteId, pedidoId, exameId, amostraId, codigoBarras, codigoManual, tipoLeitura, imagemPath, status, criadoEm, criadoPor, observacao;
  const EtiquetaExameModel({required this.id, required this.pacienteId, required this.pedidoId, required this.exameId, required this.amostraId, required this.codigoBarras, required this.codigoManual, required this.tipoLeitura, required this.imagemPath, required this.status, required this.criadoEm, required this.criadoPor, required this.observacao});
  Map<String, dynamic> toMap() => {'id':id,'pacienteId':pacienteId,'pedidoId':pedidoId,'exameId':exameId,'amostraId':amostraId,'codigoBarras':codigoBarras,'codigoManual':codigoManual,'tipoLeitura':tipoLeitura,'imagemPath':imagemPath,'status':status,'criadoEm':criadoEm,'criadoPor':criadoPor,'observacao':observacao};
}
