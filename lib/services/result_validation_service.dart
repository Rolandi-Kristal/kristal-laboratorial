class ResultValidationService {
  ResultValidationService._();

  static bool isCritical(String valor, String referencia) {
    final double? numericValue = _extractFirstNumber(valor);
    if (numericValue == null) return false;

    final String ref = referencia.toLowerCase();

    if (ref.contains('critico') || ref.contains('crítico')) {
      return true;
    }

    final RegExp intervalRegex = RegExp(
      r'(-?\d+(?:[,.]\d+)?)\s*(?:a|-|até)\s*(-?\d+(?:[,.]\d+)?)',
      caseSensitive: false,
    );

    final Match? match = intervalRegex.firstMatch(ref);
    if (match != null) {
      final double? min = _parseNumber(match.group(1));
      final double? max = _parseNumber(match.group(2));

      if (min != null && max != null) {
        final double toleranceMin = min - ((max - min).abs() * 0.25);
        final double toleranceMax = max + ((max - min).abs() * 0.25);

        return numericValue < toleranceMin || numericValue > toleranceMax;
      }
    }

    if (ref.contains('>') || ref.contains('maior')) {
      final double? limit = _extractFirstNumber(ref);
      if (limit != null) return numericValue <= limit;
    }

    if (ref.contains('<') || ref.contains('menor')) {
      final double? limit = _extractFirstNumber(ref);
      if (limit != null) return numericValue >= limit;
    }

    return false;
  }

  static double? _extractFirstNumber(String input) {
    final RegExp regex = RegExp(r'-?\d+(?:[,.]\d+)?');
    final Match? match = regex.firstMatch(input);
    if (match == null) return null;
    return _parseNumber(match.group(0));
  }

  static double? _parseNumber(String? input) {
    if (input == null) return null;
    return double.tryParse(input.replaceAll(',', '.'));
  }
}
