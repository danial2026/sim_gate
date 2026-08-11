import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('debug scroll positions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<ConfigProvider>(
              create: (_) => ConfigProvider(
                configService: getIt<ConfigService>(),
                tokenService: getIt<TokenService>(),
              )..load(),
            ),
            ChangeNotifierProvider<LogsProvider>(
              create: (_) =>
                  LogsProvider(logsRepository: getIt<LogsRepository>()),
            ),
          ],
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pump();

    final scrollable = find.byType(Scrollable).first;
    debugPrint('scrollables: ${tester.widgetList(find.byType(Scrollable)).length}');
    debugPrint('CLEAR initially: ${find.text('CLEAR').evaluate().length}');

    await tester.scrollUntilVisible(
      find.text('CLEAR'),
      200,
      scrollable: scrollable,
    );
    debugPrint('CLEAR after scrollUntilVisible: ${find.text('CLEAR').evaluate().length}');

    final pos = tester.state<ScrollableState>(scrollable).position;
    debugPrint('scroll offset after scrollUntilVisible: ${pos.pixels} / ${pos.maxScrollExtent}');

    void dumpTexts(String label) {
      const names = ['Generated', 'Regenerate Token', 'Server Settings', 'Port', 'IP Address',
        'Start API on app launch', 'API Docs (Swagger)', 'LOGGING', 'Log Level', 'Clear All Logs',
        'CLEAR', 'EXPORT LOGS', 'General', 'Theme', 'About', 'App Version', 'Permissions'];
      final parts = <String>[];
      for (final n in names) {
        final f = find.text(n);
        if (f.evaluate().isNotEmpty) {
          try {
            parts.add('$n@${tester.getRect(f.first)}');
          } catch (_) {
            parts.add('$n@?');
          }
        } else {
          parts.add('$n@NONE');
        }
      }
      debugPrint('$label:');
      debugPrint('  ${parts.join('\n  ')}');
    }

    dumpTexts('TEXTS after scrollUntilVisible');

    debugPrint('--- settling WITHOUT drag ---');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      final ipRect = find.text('IP Address').evaluate().isNotEmpty
          ? tester.getRect(find.text('IP Address').first).top.toStringAsFixed(1)
          : 'NONE';
      final expRect = find.text('EXPORT LOGS').evaluate().isNotEmpty
          ? tester.getRect(find.text('EXPORT LOGS').first).top.toStringAsFixed(1)
          : 'NONE';
      debugPrint('pump $i: offset=${pos.pixels.toStringAsFixed(1)}, max=${pos.maxScrollExtent.toStringAsFixed(1)}, IP@$ipRect, EXPORT@$expRect, CLEAR=${find.text('CLEAR').evaluate().length}');
    }
    await tester.pumpAndSettle();
    dumpTexts('TEXTS after settle-no-drag');

    final allTexts = tester.widgetList<Text>(find.byType(Text)).map((t) {
      final data = t.data ?? t.textSpan?.toPlainText() ?? '';
      try {
        final rect = tester.getRect(find.ancestor(of: find.byWidget(t), matching: find.byType(Text)).first);
        return '$data@${tester.getRect(find.byWidget(t))}';
      } catch (_) {
        return '$data@?';
      }
    }).toList();
    debugPrint('ALL texts after scrollUntilVisible:\n${allTexts.join('\n')}');

    if (find.text('CLEAR').evaluate().isNotEmpty) {
      final center = tester.getCenter(find.text('CLEAR'));
      debugPrint('CLEAR center: $center, viewport size: ${tester.view.physicalSize / tester.view.devicePixelRatio}');
    }

    await tester.drag(scrollable, const Offset(0, -120));
    debugPrint('scrollables after drag: ${tester.widgetList(find.byType(Scrollable)).length}');
    final freshPos = tester.state<ScrollableState>(scrollable).position;
    debugPrint('FRESH pos after drag: ${freshPos.pixels}, stale pos: ${pos.pixels}');
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      debugPrint('pump $i: offset=${pos.pixels}, CLEAR=${find.text('CLEAR').evaluate().length}, EXPORT=${find.text('EXPORT LOGS').evaluate().length}');
    }
    await tester.pumpAndSettle();
    dumpTexts('TEXTS after drag');
    debugPrint('CLEAR after drag: ${find.text('CLEAR').evaluate().length}');
    debugPrint('scroll offset after drag: ${pos.pixels}');
    if (find.text('EXPORT LOGS').evaluate().isNotEmpty) {
      debugPrint('EXPORT rect: ${tester.getRect(find.text('EXPORT LOGS'))}');
    }
    final vp = tester.renderObject<RenderViewport>(find.byType(Viewport).first);
    debugPrint('viewport offset: ${vp.offset}, viewport dims: ${vp.size}, cacheExtent: ${vp.cacheExtent}');
    final sliver = tester.renderObject<RenderSliverList>(
      find.descendant(of: find.byType(ListView), matching: find.byType(SliverList)),
    );
    debugPrint('RenderSliverList childCount=${sliver.childCount}');
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText())
        .whereType<String>()
        .toList();
    debugPrint('visible texts after drag: $texts');
  });
}
