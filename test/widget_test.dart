import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w_link_join/main.dart';

void main() {
  testWidgets('W-Link Join app launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: WLinkJoinApp(),
      ),
    );

    expect(find.text('W-Link Join'), findsOneWidget);
  });
}
