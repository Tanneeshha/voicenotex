import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_fyp/main.dart';
import 'package:my_fyp/core/services/style_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test renders without throwing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StyleService.init();

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.byType(MyApp), findsOneWidget);
  });
}
