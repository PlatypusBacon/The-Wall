import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'route_model.dart';

class RouteDatabase {
  static final RouteDatabase instance = RouteDatabase._();
  static Database? _db;
  RouteDatabase._();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      join(dir, 'routes.db'),
      version: 4, // bumped to 3 to force onUpgrade on existing v2 installs
      onCreate: (db, version) async {
        await _createTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Always fetch a fresh column list inside the transaction
        final columns = await db.rawQuery('PRAGMA table_info(routes);');
        final columnNames = columns.map((c) => c['name'] as String).toSet();

        // v1 → v2: rename 'holds' → 'selected_holds'
        if (!columnNames.contains('selected_holds') &&
            columnNames.contains('holds')) {
          await db.execute(
              'ALTER TABLE routes RENAME COLUMN holds TO selected_holds;');
          // Refresh after rename
          columnNames
            ..remove('holds')
            ..add('selected_holds');
        }

        // v1/v2 → v3: add missing columns
        if (!columnNames.contains('all_holds')) {
          // Use NULL default so existing rows don't violate NOT NULL
          await db.execute(
              'ALTER TABLE routes ADD COLUMN all_holds TEXT;');
          // Back-fill: copy selected_holds into all_holds for legacy rows
          await db.execute(
              'UPDATE routes SET all_holds = selected_holds WHERE all_holds IS NULL;');
        }

        if (!columnNames.contains('is_sequence_climb')) {
          await db.execute(
              'ALTER TABLE routes ADD COLUMN is_sequence_climb INTEGER NOT NULL DEFAULT 0;');
        }

        if (!columnNames.contains('image_width')) {
          await db.execute(
              'ALTER TABLE routes ADD COLUMN image_width REAL NOT NULL DEFAULT 0;');
          await db.execute(
              'ALTER TABLE routes ADD COLUMN image_height REAL NOT NULL DEFAULT 0;');
        }
        if (!columnNames.contains('image_bytes')) {
          await db.execute('ALTER TABLE routes ADD COLUMN image_bytes TEXT;');
        }
      },
    );
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE routes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        all_holds TEXT,
        selected_holds TEXT NOT NULL,
        image_path TEXT NOT NULL,
        image_bytes TEXT,
        annotated_image_path TEXT,
        created_at TEXT NOT NULL,
        image_width REAL NOT NULL DEFAULT 0,
        image_height REAL NOT NULL DEFAULT 0,
        is_sequence_climb INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> insertRoute(SavedRoute route) async {
    final db = await database;
    await db.insert(
      'routes',
      route.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SavedRoute>> getAllRoutes() async {
    final db = await database;
    final maps = await db.query('routes', orderBy: 'created_at DESC');
    return maps.map(SavedRoute.fromMap).toList();
  }

  Future<void> deleteRoute(String id) async {
    final db = await database;
    await db.delete('routes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateAnnotatedPath(String id, String path) async {
    final db = await database;
    await db.update(
      'routes',
      {'annotated_image_path': path},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Call this when the user saves an edited route.
  Future<void> updateRoute(SavedRoute route) async {
    final db = await database;
    await db.update(
      'routes',
      route.toMap(),
      where: 'id = ?',
      whereArgs: [route.id],
    );
  }
}