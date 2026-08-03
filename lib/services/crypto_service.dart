import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoService {
  CryptoService._();
  static final CryptoService instance = CryptoService._();
  static const String _pepper = 'KRISTAL_LAB_HMR_2026_LOCAL_PEPPER';

  String hashPassword(String password, String salt) => sha256.convert(utf8.encode('$salt::$password::$_pepper')).toString();
  String newSalt([String seed = '']) => sha256.convert(utf8.encode('${DateTime.now().microsecondsSinceEpoch}::$seed')).toString().substring(0, 32);
  String hashText(String text) => sha256.convert(utf8.encode(text)).toString();

  String encryptText(String plain) {
    if (plain.isEmpty) return '';
    final bytes = utf8.encode(plain);
    final key = utf8.encode(_pepper);
    final out = <int>[];
    for (var i = 0; i < bytes.length; i++) { out.add(bytes[i] ^ key[i % key.length]); }
    return 'KLX:${base64UrlEncode(out)}';
  }

  String decryptText(String cipher) {
    if (!cipher.startsWith('KLX:')) return cipher;
    final bytes = base64Url.decode(cipher.substring(4));
    final key = utf8.encode(_pepper);
    final out = <int>[];
    for (var i = 0; i < bytes.length; i++) { out.add(bytes[i] ^ key[i % key.length]); }
    return utf8.decode(out);
  }
}
