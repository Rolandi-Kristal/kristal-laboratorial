import 'dart:convert';

import 'package:crypto/crypto.dart';

class LaudoHashService {
  LaudoHashService._();

  static String gerarHash(Map<String, dynamic> dados) {
    final String normalized = jsonEncode(
      Map<String, dynamic>.fromEntries(
        dados.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      ),
    );

    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static String gerarCodigoValidacao(Map<String, dynamic> dados) {
    return gerarHash(dados).substring(0, 16).toUpperCase();
  }
}
