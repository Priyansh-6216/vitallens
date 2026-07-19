import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/heart_rate_data_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'vitallens.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE heart_rate_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        heart_rate INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        sdnn REAL,
        rmssd REAL,
        pnn50 REAL
      )
    ''');
  }

  Future<int> insertHeartRateData(HeartRateDataModel data) async {
    final db = await database;
    return await db.insert('heart_rate_data', data.toMap());
  }

  Future<List<HeartRateDataModel>> getAllHeartRateData() async {
    final db = await database;
    final result = await db.query(
      'heart_rate_data',
      orderBy: 'timestamp DESC',
    );
    return result.map((e) => HeartRateDataModel.fromMap(e)).toList();
  }

  Future<int> deleteAllHeartRateData() async {
    final db = await database;
    return await db.delete('heart_rate_data');
  }

  Future<int> getCount() async {
    final db = await database;
    final result = await db.query('heart_rate_data');
    return result.length;
  }
}
