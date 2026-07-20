import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zidash/main.dart';

void main() {
  testWidgets('Zidash app boots to onboarding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Grow your business\nwith Zidash'), findsOneWidget);
    expect(find.text('Sign up with email'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Buy and sell within\nyour community'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Grow, earn and\nthrive'), findsOneWidget);
  });
}
