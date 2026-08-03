import 'dart:io';
class CsvExportService {
  static String escape(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
  static Future<File> exportRows(String filename, List<Map<String,dynamic>> rows) async {
    final keys = rows.isEmpty ? <String>[] : rows.first.keys.toList();
    final b = StringBuffer()..writeln(keys.map(escape).join(';'));
    for (final r in rows) { b.writeln(keys.map((k)=>escape(r[k])).join(';')); }
    final dir = Directory('${Directory.current.path}/exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final f = File('${dir.path}/$filename');
    return f.writeAsString(b.toString());
  }
}
