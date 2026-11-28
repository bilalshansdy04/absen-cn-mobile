import 'package:flutter_test/flutter_test.dart';
import 'package:absen_mobile/main.dart';

void main() {
  testWidgets('PresensiApp builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PresensiApp());
    expect(find.byType(PresensiApp), findsOneWidget);
  });
}
