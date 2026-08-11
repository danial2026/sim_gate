// Device integration test: drives the real app through the setup flow.
//
// Run with:  flutter test integration_test/app_flow_test.dart -d <device>
//
// Note: this requires a running Android emulator/device. The unit/e2e suite
// in test/ covers the same logic on the host without a device.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sim_gate/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boots and renders the permissions gate', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Grant Permissions'), findsOneWidget);
  });

  testWidgets('navigates to the server setup screen', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Skip past permissions via the secondary action.
    await tester.tap(find.text('CONTINUE ANYWAY'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Configure Server'), findsOneWidget);
  });
}
