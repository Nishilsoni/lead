import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_crm/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const OceanCRMApp());
    // Basic smoke test
    expect(find.byType(OceanCRMApp), findsOneWidget);
  });
}
