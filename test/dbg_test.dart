import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/main.dart';
import 'package:sim_gate/services/platform_channel_service.dart';
import 'package:sim_gate/services/sim_service.dart';

import 'test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
    final platform = getIt<PlatformChannelService>() as FakePlatformService;
    platform.setSims([]);
    await getIt<SimService>().refresh();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('debug app boot', (tester) async {
    await tester.pumpWidget(const SimGateApp());
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    print('PERMISSIONS_TEXT=' + find.text('Grant Permissions').evaluate().length.toString());
    print('PERMISSIONS_TITLE=' + find.text('PERMISSIONS').evaluate().length.toString());
    print('LOADING=' + find.byType(CircularProgressIndicator).evaluate().length.toString());
    print('APPBAR=' + find.byType(AppBar).evaluate().length.toString());
  });
}
