// widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wazibot_mobile/main.dart';

void main() {
  testWidgets('WaziBot app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WaziBotApp()));
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
