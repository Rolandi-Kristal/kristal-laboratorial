abstract class LabInstrumentAdapter {
  String get protocolo;
  List<Map<String, String>> parseResult(String raw);
  String buildWorklist(Map<String, dynamic> order);
}
