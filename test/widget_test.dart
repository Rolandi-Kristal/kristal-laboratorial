import 'package:flutter_test/flutter_test.dart';

import 'package:kristal_laboratorial/main.dart';

void main() {
  testWidgets('KRISTAL LABORATORIAL inicia sem erro básico', (WidgetTester tester) async {
    await tester.pumpWidget(const KristalLaboratorialApp());
    await tester.pump();

    expect(find.text('ACESSO AO SISTEMA'), findsOneWidget);
  });
}
