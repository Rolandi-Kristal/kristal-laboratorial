import 'dart:io';
class SerialInstrumentService {
  Future<void> open(String comPort) async {
  final String normalizedPort = comPort.trim().toUpperCase();

  if (normalizedPort.isEmpty) {
    throw ArgumentError('Porta COM obrigatÃ³ria.');
  }

  final ProcessResult result = await Process.run(
    'cmd',
    <String>['/c', 'mode', normalizedPort],
    runInShell: true,
  );

  if (result.exitCode != 0) {
    throw FileSystemException(
      'Porta serial nÃ£o encontrada, indisponÃ­vel ou sem permissÃ£o.',
      normalizedPort,
    );
  }
}
}
