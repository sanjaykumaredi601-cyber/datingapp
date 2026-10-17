import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/main.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aura_app/injection_container.dart' as di;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({
    'auth_token': 'dummy_jwt',
    'is_profile_complete': 'true',
  });

  testWidgets('Aura app boots smoke test', (WidgetTester tester) async {
    await di.configureDependencies();
    await tester.pumpWidget(const AuraApp());
    expect(find.byType(AuraApp), findsOneWidget);

    // Verify initial splash state renders cleanly
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AuraApp), findsOneWidget);
  });
}
