import 'package:flutter_test/flutter_test.dart';
import 'package:calendar_frontend/main.dart';

void main() {
  testWidgets('DayCrafter smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DayCrafterApp());

    // Verify that DayCrafter is present
    expect(find.textContaining('DayCrafter'), findsWidgets);
    expect(find.textContaining('Welcome to'), findsOneWidget);
  });
}
