import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('db under fake async', (tester) async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      'file:dbg?mode=memory',
      options: OpenDatabaseOptions(version: 1, onCreate: (db, v) async {
        print('onCreate start');
        await db.execute('CREATE TABLE t1 (id INTEGER)');
        print('onCreate done');
      }),
    );
    print('db opened');
    await db.insert('t1', {'id': 1});
    print('inserted');
    final rows = await db.query('t1');
    print('rows: $rows');
    await db.close();
    print('closed');
  });
}
