import 'package:flutter_test/flutter_test.dart';
import 'package:wastefood/main.dart';

void main() {
  testWidgets('Smoke test app build', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const MyApp());

    // Expect to find 'Login' text
    expect(find.text('Login'), findsOneWidget);
  });
}
