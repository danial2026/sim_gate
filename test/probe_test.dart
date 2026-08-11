import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('shared-cache memory DBs with unique names are isolated', () async {
    sqfliteFfiInit();
    for (var i = 0; i < 3; i++) {
      final db = await databaseFactoryFfi.openDatabase(
        'file:probe_$i?mode=memory&cache=shared',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, v) async {
            await db.execute('CREATE TABLE t1 (id INTEGER)');
            await db.execute('CREATE INDEX idx_t1 ON t1(id)');
          },
        ),
      );
      expect(db.isOpen, true, reason: 'iteration $i failed');
      await db.close();
    }
  });

  test('plain unique memory paths are isolated', () async {
    sqfliteFfiInit();
    for (var i = 0; i < 3; i++) {
      final db = await databaseFactoryFfi.openDatabase(
        'file:plain_$i?mode=memory',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, v) async {
            await db.execute('CREATE TABLE t1 (id INTEGER)');
            await db.execute('CREATE INDEX idx_t1 ON t1(id)');
          },
        ),
      );
      expect(db.isOpen, true, reason: 'iteration $i failed');
      await db.close();
    }
  });
}
