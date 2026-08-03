class LgpdService {
  LgpdService._();

  static String maskCpf(String cpf) {
    final String digits = cpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 11) return '***.***.***-**';

    return '***.${digits.substring(3, 6)}.${digits.substring(6, 9)}-**';
  }

  static String maskCns(String cns) {
    final String digits = cns.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return '***************';

    return '${digits.substring(0, 3)}*********${digits.substring(digits.length - 3)}';
  }

  static String maskPhone(String phone) {
    final String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return '****';

    return '${digits.substring(0, 2)}*****${digits.substring(digits.length - 4)}';
  }

  static String maskName(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '';

    if (parts.length == 1) {
      return '${parts.first[0]}***';
    }

    return '${parts.first} ${parts.last[0]}***';
  }

  static String maskByField(String field, dynamic value) {
    final String text = value?.toString() ?? '';
    final String lower = field.toLowerCase();

    if (lower.contains('cpf')) return maskCpf(text);
    if (lower.contains('cns')) return maskCns(text);
    if (lower.contains('telefone')) return maskPhone(text);
    if (lower.contains('nome')) return maskName(text);
    if (lower.contains('endereco')) return 'ENDEREÇO PROTEGIDO';
    if (lower.contains('senha')) return '********';

    return text;
  }
}
