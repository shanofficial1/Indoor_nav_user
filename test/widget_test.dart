import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_user/main.dart';

void main() {
  testWidgets('Indoor Navigation app loads successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(const IndoorNavUserApp());
    await tester.pumpAndSettle();

    expect(find.byType(IndoorNavUserApp), findsOneWidget);
  });
}