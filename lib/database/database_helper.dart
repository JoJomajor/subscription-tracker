import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/subscription.dart';

class DatabaseHelper {
  // Singleton паттерн - один экземпляр БД на всё приложение
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  // Получаем базу данных (создаём если нет)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Инициализация базы данных
  Future<Database> _initDatabase() async {
    // Получаем путь к папке документов приложения
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'subscriptions.db');

    // Открываем (или создаём) базу данных
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Создание таблиц при первом запуске
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        currency TEXT NOT NULL,
        cycle INTEGER NOT NULL,
        startDate TEXT NOT NULL,
        category TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  // ========== CRUD ОПЕРАЦИИ ==========

  // CREATE - Добавить подписку
  Future<int> insertSubscription(Subscription subscription) async {
    final db = await database;
    return await db.insert(
      'subscriptions',
      subscription.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // READ - Получить все подписки
  Future<List<Subscription>> getAllSubscriptions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('subscriptions');
    
    return List.generate(maps.length, (i) {
      return Subscription.fromMap(maps[i]);
    });
  }

  // READ - Получить одну подписку по ID
  Future<Subscription?> getSubscriptionById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'subscriptions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Subscription.fromMap(maps.first);
  }

  // UPDATE - Обновить подписку
  Future<int> updateSubscription(Subscription subscription) async {
    final db = await database;
    return await db.update(
      'subscriptions',
      subscription.toMap(),
      where: 'id = ?',
      whereArgs: [subscription.id],
    );
  }

  // DELETE - Удалить подписку
  Future<int> deleteSubscription(int id) async {
    final db = await database;
    return await db.delete(
      'subscriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Получить только активные подписки
  Future<List<Subscription>> getActiveSubscriptions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'subscriptions',
      where: 'isActive = ?',
      whereArgs: [1],
    );

    return List.generate(maps.length, (i) {
      return Subscription.fromMap(maps[i]);
    });
  }

  // Подсчитать общую сумму трат в месяц
  // Подсчитать общую сумму трат в месяц
Future<double> getTotalMonthlySpending() async {
  final subscriptions = await getActiveSubscriptions();
  
  // Явно указываем тип <double> для fold
  return subscriptions.fold<double>(0.0, (sum, sub) => sum + sub.monthlyPrice);
}
}