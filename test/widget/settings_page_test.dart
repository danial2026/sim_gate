import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/config/theme.dart';
import 'package:sim_gate/pages/settings_page.dart';
import 'package:sim_gate/providers/config_provider.dart';
import 'package:sim_gate/providers/logs_provider.dart';
import 'package:sim_gate/repositories/logs_repository.dart';
import 'package:sim_gate/services/config_service.dart';
import 'package:sim_gate/services/token_service.dart';

import '../test_harness.dart';

/// Helper that pumps a page wrapped in the providers it needs.
Future<WidgetTester> pumpPage(
  WidgetTester tester,
  Widget page, {
  required List<ChangeNotifierProvider<dynamic>> providers,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MultiProvider(providers: providers, child: page),
    ),
  );
  await tester.pump();
  return tester;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  List<ChangeNotifierProvider<dynamic>> defaultProviders() {
    return [
      ChangeNotifierProvider<ConfigProvider>(
        create: (_) => ConfigProvider(
          configService: getIt<ConfigService>(),
          tokenService: getIt<TokenService>(),
        )..load(),
      ),
      ChangeNotifierProvider<LogsProvider>(
        create: (_) => LogsProvider(logsRepository: getIt<LogsRepository>()),
      ),
    ];
  }

  group('SettingsPage', () {
    testWidgets('renders the token, server and logging sections',
        (tester) async {
      await pumpPage(tester, const SettingsPage(),
          providers: defaultProviders());

      expect(find.text('ACCESS TOKEN'), findsOneWidget);
      expect(find.text('SERVER SETTINGS'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('LOGGING'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('LOGGING'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('ABOUT'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('ABOUT'), findsOneWidget);
    });

    testWidgets('regenerate token shows the warning dialog',
        (tester) async {
      await pumpPage(tester, const SettingsPage(),
          providers: defaultProviders());

      await tester.tap(find.text('REGENERATE TOKEN'));
      await tester.pumpAndSettle();

      expect(find.text('WARNING'), findsOneWidget);
      expect(find.textContaining('invalidate'), findsWidgets);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('REGENERATE'), findsOneWidget);
    });

    testWidgets('cancelling the regeneration dialog keeps the token',
        (tester) async {
      await pumpPage(tester, const SettingsPage(),
          providers: defaultProviders());

      await tester.tap(find.text('REGENERATE TOKEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(find.text('WARNING'), findsNothing);
    });

    testWidgets('clear logs asks for confirmation', (tester) async {
      await pumpPage(tester, const SettingsPage(),
          providers: defaultProviders());

      await tester.scrollUntilVisible(find.text('CLEAR'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('CLEAR'));
      await tester.tap(find.text('CLEAR'));
      await tester.pumpAndSettle();

      expect(find.text('CLEAR LOGS'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
    });

    testWidgets('shows package version from package_info', (tester) async {
      await pumpPage(tester, const SettingsPage(),
          providers: defaultProviders());

      await tester.scrollUntilVisible(find.text('ABOUT'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('App Version'), findsOneWidget);
      // Either loading or the mock platform version (0.0.1 (1)).
      expect(find.textContaining('0.0.1'), findsWidgets);
    });
  });
}
