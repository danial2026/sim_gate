import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/config/theme.dart';
import 'package:sim_gate/models/configuration.dart';
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
    testWidgets('renders the token, server and logging sections', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const SettingsPage(),
        providers: defaultProviders(),
      );

      expect(find.text('ACCESS TOKEN'), findsOneWidget);
      expect(find.text('SERVER SETTINGS'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('LOGGING'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('LOGGING'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('ABOUT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ABOUT'), findsOneWidget);
    });

    testWidgets('regenerate token shows the warning dialog', (tester) async {
      await pumpPage(
        tester,
        const SettingsPage(),
        providers: defaultProviders(),
      );

      await tester.tap(find.text('REGENERATE TOKEN'));
      await tester.pumpAndSettle();

      expect(find.text('WARNING'), findsOneWidget);
      expect(find.textContaining('invalidate'), findsWidgets);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('REGENERATE'), findsOneWidget);
    });

    testWidgets('cancelling the regeneration dialog keeps the token', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const SettingsPage(),
        providers: defaultProviders(),
      );

      await tester.tap(find.text('REGENERATE TOKEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(find.text('WARNING'), findsNothing);
    });

    testWidgets('clear logs asks for confirmation', (tester) async {
      await pumpPage(
        tester,
        const SettingsPage(),
        providers: defaultProviders(),
      );

      await tester.scrollUntilVisible(
        find.text('CLEAR'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Nudge the tile fully into view so the trailing button is hittable.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLEAR'));
      await tester.pumpAndSettle();

      expect(find.text('CLEAR LOGS'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
    });

    testWidgets('shows package version from package_info', (tester) async {
      await pumpPage(
        tester,
        const SettingsPage(),
        providers: defaultProviders(),
      );

      await tester.scrollUntilVisible(
        find.text('ABOUT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('App Version'), findsOneWidget);
      // Loading state (no package_info plugin in tests) or a version string.
      expect(
        find.text('Loading...').evaluate().isNotEmpty ||
            find.textContaining('0.0.1').evaluate().isNotEmpty,
        isTrue,
      );
    });
    testWidgets('swagger toggle enables and persists the docs flag', (
      tester,
    ) async {
      final configProvider = ConfigProvider(
        configService: getIt<ConfigService>(),
        tokenService: getIt<TokenService>(),
      )..load();
      await pumpPage(
        tester,
        const SettingsPage(),
        providers: [
          ChangeNotifierProvider<ConfigProvider>.value(value: configProvider),
          ChangeNotifierProvider<LogsProvider>(
            create: (_) => LogsProvider(logsRepository: getIt<LogsRepository>()),
          ),
        ],
      );

      expect(find.text('API Docs (Swagger)'), findsOneWidget);
      final docsSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('API Docs (Swagger)'),
          matching: find.byType(Container),
        ),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(docsSwitch).value, isFalse);

      await tester.tap(docsSwitch);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(docsSwitch).value, isTrue);
      expect(
        getIt<ConfigService>().load().enableSwagger,
        isTrue,
      );

      // Disable again to keep the default for later tests.
      await tester.tap(docsSwitch);
      await tester.pumpAndSettle();
      expect(getIt<ConfigService>().load().enableSwagger, isFalse);
    });

    testWidgets('switching theme to light flips the app brightness', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      // Mirror main.dart wiring: themeMode follows the ConfigProvider.
      await tester.pumpWidget(
        MultiProvider(
          providers: defaultProviders(),
          child: Consumer<ConfigProvider>(
            builder: (context, config, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: config.config.appTheme.toMaterial(),
              home: const SettingsPage(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.dark,
      );

      await tester.scrollUntilVisible(
        find.text('Theme'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byType(DropdownButton<AppThemeMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<AppThemeMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LIGHT').last);
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.light,
      );
      expect(
        AppTheme.of(tester.element(find.byType(SettingsPage))).background,
        AppPalette.light.background,
      );
    });
  });
}
