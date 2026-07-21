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
    
    // Create index on timestamp for faster queries
    await db.execute('''
      CREATE INDEX idx_timestamp ON heart_rate_data(timestamp)
    ''');
  }

  Future<int> insertHeartRateData(HeartRateDataModel data) async {
    final db = await database;
    return await db.insert('heart_rate_data', data.toMap());
  }

  Future<int> insertHeartRateDataBatch(List<HeartRateDataModel> dataList) async {
    if (dataList.isEmpty) return 0;
    
    final db = await database;
    return await db.transaction((txn) async {
      int total = 0;
      for (var data in dataList) {
        await txn.insert('heart_rate_data', data.toMap());
        total++;
      }
      return total;
    });
  }

  Future<List<HeartRateDataModel>> getAllHeartRateData({int limit = 1000}) async {
    final db = await database;
    final result = await db.query(
      'heart_rate_data',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((e) => HeartRateDataModel.fromMap(e)).toList();
  }

  Future<List<HeartRateDataModel>> getHeartRateDataInRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.query(
      'heart_rate_data',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String()
      ],
      orderBy: 'timestamp ASC',
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
