import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/subscription.dart';
import '../models/payment_record.dart';

class DatabaseHelper {
  // Singleton паттерн
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  
  // Приватный конструктор с опциональным путём к БД
  DatabaseHelper._internal({this._databasePath});
  
  // Фабричный конструктор для тестов
  factory DatabaseHelper.forTesting({String? databasePath}) {
    return DatabaseHelper._internal(databasePath: databasePath);
  }

  final String? _databasePath;
  Database? _database;

  // Получаем базу данных (создаём если нет)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Инициализация базы данных
  Future<Database> _initDatabase() async {
    // Если путь задан (для тестов) — используем его
    if (_databasePath != null) {
      return await openDatabase(
        _databasePath,
        version: 1,
        onCreate: _onCreate,
      );
    }
    
    // Иначе — стандартный путь к БД
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'subscriptions.db');

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

    await db.execute('''
    CREATE TABLE payment_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subscriptionId INTEGER NOT NULL,
      paymentDate TEXT NOT NULL,
      amount REAL NOT NULL,
      FOREIGN KEY (subscriptionId) REFERENCES subscriptions(id)
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
  Future<double> getTotalMonthlySpending() async {
    final subscriptions = await getActiveSubscriptions();
    return subscriptions.fold<double>(0.0, (sum, sub) => sum + sub.monthlyPrice);
  }
  
  // Закрыть базу данных (для тестов)
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // CRUD для PaymentRecord:
  Future<int> insertPaymentRecord(PaymentRecord record) async {
  final db = await database;
  return await db.insert('payment_records', record.toMap());
  }

  Future<List<PaymentRecord>> getPaymentHistory(int subscriptionId) async {
  final db = await database;
  final maps = await db.query(
    'payment_records',
    where: 'subscriptionId = ?',
    whereArgs: [subscriptionId],
    orderBy: 'paymentDate DESC',
  );
  return List.generate(maps.length, (i) => PaymentRecord.fromMap(maps[i]));
  }
}