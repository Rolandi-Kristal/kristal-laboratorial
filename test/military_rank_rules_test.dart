import 'package:flutter_test/flutter_test.dart';
import 'package:kristal_laboratorial/core/military_rank_rules.dart';

void main() {
  group('MilitaryRankRules', () {
    test('monta graduações sem posto', () {
      expect(MilitaryRankRules.montar(graduacao: 'Soldado'), 'Soldado');
      expect(MilitaryRankRules.montar(graduacao: 'Cabo'), 'Cabo');
      expect(MilitaryRankRules.montar(graduacao: 'Subtenente'), 'Subtenente');
    });

    test('monta postos de sargento e tenente', () {
      expect(
        MilitaryRankRules.montar(graduacao: 'Sargento', posto: '3º'),
        '3º Sargento',
      );
      expect(
        MilitaryRankRules.montar(graduacao: 'Tenente', posto: '1º'),
        '1º Tenente',
      );
    });

    test('monta postos de general', () {
      expect(
        MilitaryRankRules.montar(graduacao: 'General', posto: 'Brigada'),
        'General de Brigada',
      );
      expect(
        MilitaryRankRules.montar(graduacao: 'General', posto: 'Exército'),
        'General de Exército',
      );
    });

    test('parseia valores cadastrados anteriormente', () {
      final MilitaryRankSelection sargento = MilitaryRankRules.parse('2º Sargento');
      expect(sargento.graduacao, 'Sargento');
      expect(sargento.posto, '2º');

      final MilitaryRankSelection general = MilitaryRankRules.parse('General de Divisão');
      expect(general.graduacao, 'General');
      expect(general.posto, 'Divisão');
    });
  });
}