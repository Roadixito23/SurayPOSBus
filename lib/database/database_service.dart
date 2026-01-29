import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'models/daily_closing_entity.dart';
import 'models/transaction_entity.dart';
import 'models/weekly_closing_entity.dart';
import 'models/monthly_closing_entity.dart';

/// Servicio que proporciona operaciones CRUD para todas las tablas
class DatabaseService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ============================================================================
  // DAILY CLOSINGS - Operaciones CRUD
  // ============================================================================

  /// Inserta un nuevo cierre diario
  Future<int> insertDailyClosing(DailyClosingEntity closing) async {
    final db = await _dbHelper.database;
    return await db.insert('daily_closings', closing.toMap());
  }

  /// Actualiza un cierre diario existente
  Future<int> updateDailyClosing(DailyClosingEntity closing) async {
    final db = await _dbHelper.database;
    return await db.update(
      'daily_closings',
      closing.toMap(),
      where: 'id = ?',
      whereArgs: [closing.id],
    );
  }

  /// Obtiene un cierre diario por fecha
  Future<DailyClosingEntity?> getDailyClosingByDate(String date) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_closings',
      where: 'date = ?',
      whereArgs: [date],
    );

    if (maps.isEmpty) return null;
    return DailyClosingEntity.fromMap(maps.first);
  }

  /// Obtiene un cierre diario por ID
  Future<DailyClosingEntity?> getDailyClosingById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_closings',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return DailyClosingEntity.fromMap(maps.first);
  }

  /// Obtiene todos los cierres diarios en un rango de fechas
  Future<List<DailyClosingEntity>> getDailyClosingsInRange(
    String startDate,
    String endDate,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_closings',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );

    return maps.map((map) => DailyClosingEntity.fromMap(map)).toList();
  }

  /// Obtiene todos los cierres diarios
  Future<List<DailyClosingEntity>> getAllDailyClosings() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_closings',
      orderBy: 'date DESC',
    );

    return maps.map((map) => DailyClosingEntity.fromMap(map)).toList();
  }

  /// Obtiene cierres diarios por año y mes
  Future<List<DailyClosingEntity>> getDailyClosingsByYearMonth(
    int year,
    int month,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_closings',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
      orderBy: 'day ASC',
    );

    return maps.map((map) => DailyClosingEntity.fromMap(map)).toList();
  }

  /// Elimina un cierre diario (también eliminará sus transacciones por CASCADE)
  Future<int> deleteDailyClosing(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'daily_closings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // TRANSACTIONS - Operaciones CRUD
  // ============================================================================

  /// Inserta una nueva transacción
  Future<int> insertTransaction(TransactionEntity transaction) async {
    final db = await _dbHelper.database;
    return await db.insert('transactions', transaction.toMap());
  }

  /// Inserta múltiples transacciones en una sola operación
  Future<void> insertTransactionBatch(
    List<TransactionEntity> transactions,
  ) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (var transaction in transactions) {
      batch.insert('transactions', transaction.toMap());
    }

    await batch.commit(noResult: true);
  }

  /// Obtiene todas las transacciones de un cierre diario
  Future<List<TransactionEntity>> getTransactionsByClosingId(
    int dailyClosingId,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'daily_closing_id = ?',
      whereArgs: [dailyClosingId],
      orderBy: 'transaction_id ASC',
    );

    return maps.map((map) => TransactionEntity.fromMap(map)).toList();
  }

  /// Obtiene transacciones por categoría
  Future<List<TransactionEntity>> getTransactionsByCategory(
    int dailyClosingId,
    TransactionCategory category,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'daily_closing_id = ? AND category = ?',
      whereArgs: [dailyClosingId, category.toString().split('.').last],
      orderBy: 'transaction_id ASC',
    );

    return maps.map((map) => TransactionEntity.fromMap(map)).toList();
  }

  /// Obtiene el total de transacciones de un cierre diario
  Future<int> getTransactionCount(int dailyClosingId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE daily_closing_id = ?',
      [dailyClosingId],
    );

    return result.first['count'] as int;
  }

  /// Calcula totales por categoría para un cierre diario
  Future<Map<String, double>> getTotalsByCategory(int dailyClosingId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT
        category,
        SUM(valor) as total
      FROM transactions
      WHERE daily_closing_id = ?
      GROUP BY category
    ''', [dailyClosingId]);

    final totals = <String, double>{
      'pasaje': 0.0,
      'correspondencia': 0.0,
      'anulacion': 0.0,
    };

    for (var row in result) {
      final category = row['category'] as String;
      final total = (row['total'] as num).toDouble();
      totals[category] = total;
    }

    return totals;
  }

  // ============================================================================
  // WEEKLY CLOSINGS - Operaciones CRUD
  // ============================================================================

  /// Inserta un nuevo cierre semanal
  Future<int> insertWeeklyClosing(WeeklyClosingEntity closing) async {
    final db = await _dbHelper.database;
    return await db.insert('weekly_closings', closing.toMap());
  }

  /// Actualiza un cierre semanal existente
  Future<int> updateWeeklyClosing(WeeklyClosingEntity closing) async {
    final db = await _dbHelper.database;
    return await db.update(
      'weekly_closings',
      closing.toMap(),
      where: 'id = ?',
      whereArgs: [closing.id],
    );
  }

  /// Obtiene un cierre semanal por año y número de semana
  Future<WeeklyClosingEntity?> getWeeklyClosingByYearWeek(
    int year,
    int weekNumber,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'weekly_closings',
      where: 'year = ? AND week_number = ?',
      whereArgs: [year, weekNumber],
    );

    if (maps.isEmpty) return null;
    return WeeklyClosingEntity.fromMap(maps.first);
  }

  /// Obtiene todos los cierres semanales de un año
  Future<List<WeeklyClosingEntity>> getWeeklyClosingsByYear(int year) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'weekly_closings',
      where: 'year = ?',
      whereArgs: [year],
      orderBy: 'week_number ASC',
    );

    return maps.map((map) => WeeklyClosingEntity.fromMap(map)).toList();
  }

  /// Obtiene todos los cierres semanales
  Future<List<WeeklyClosingEntity>> getAllWeeklyClosings() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'weekly_closings',
      orderBy: 'year DESC, week_number DESC',
    );

    return maps.map((map) => WeeklyClosingEntity.fromMap(map)).toList();
  }

  /// Elimina un cierre semanal
  Future<int> deleteWeeklyClosing(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'weekly_closings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // MONTHLY CLOSINGS - Operaciones CRUD
  // ============================================================================

  /// Inserta un nuevo cierre mensual
  Future<int> insertMonthlyClosing(MonthlyClosingEntity closing) async {
    final db = await _dbHelper.database;
    return await db.insert('monthly_closings', closing.toMap());
  }

  /// Actualiza un cierre mensual existente
  Future<int> updateMonthlyClosing(MonthlyClosingEntity closing) async {
    final db = await _dbHelper.database;
    return await db.update(
      'monthly_closings',
      closing.toMap(),
      where: 'id = ?',
      whereArgs: [closing.id],
    );
  }

  /// Obtiene un cierre mensual por año y mes
  Future<MonthlyClosingEntity?> getMonthlyClosingByYearMonth(
    int year,
    int month,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'monthly_closings',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );

    if (maps.isEmpty) return null;
    return MonthlyClosingEntity.fromMap(maps.first);
  }

  /// Obtiene todos los cierres mensuales de un año
  Future<List<MonthlyClosingEntity>> getMonthlyClosingsByYear(int year) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'monthly_closings',
      where: 'year = ?',
      whereArgs: [year],
      orderBy: 'month ASC',
    );

    return maps.map((map) => MonthlyClosingEntity.fromMap(map)).toList();
  }

  /// Obtiene todos los cierres mensuales
  Future<List<MonthlyClosingEntity>> getAllMonthlyClosings() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'monthly_closings',
      orderBy: 'year DESC, month DESC',
    );

    return maps.map((map) => MonthlyClosingEntity.fromMap(map)).toList();
  }

  /// Elimina un cierre mensual
  Future<int> deleteMonthlyClosing(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'monthly_closings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // UTILIDADES
  // ============================================================================

  /// Ejecuta una transacción de base de datos (para operaciones atómicas)
  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await _dbHelper.database;
    return await db.transaction(action);
  }

  /// Cierra la base de datos
  Future<void> close() async {
    await _dbHelper.close();
  }
}
