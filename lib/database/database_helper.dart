import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Helper para gestionar la base de datos SQLite
/// Implementa patrón Singleton para tener una única instancia
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Obtiene la instancia de la base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('suraypos.db');
    return _database!;
  }

  /// Inicializa la base de datos
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Crea todas las tablas de la base de datos
  Future _createDB(Database db, int version) async {
    // Tabla de cierres diarios
    await db.execute('''
      CREATE TABLE daily_closings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        day INTEGER NOT NULL,
        day_of_week TEXT NOT NULL,
        total_pasajes REAL NOT NULL DEFAULT 0,
        total_correspondencias REAL NOT NULL DEFAULT 0,
        total_anulaciones REAL NOT NULL DEFAULT 0,
        grand_total REAL NOT NULL DEFAULT 0,
        transaction_count INTEGER NOT NULL DEFAULT 0,
        ticket_id TEXT,
        status TEXT NOT NULL DEFAULT 'closed',
        created_at INTEGER NOT NULL,
        closed_at INTEGER NOT NULL,
        pdf_filename TEXT
      )
    ''');

    // Índices para daily_closings
    await db.execute('''
      CREATE INDEX idx_daily_closings_date ON daily_closings(date)
    ''');

    await db.execute('''
      CREATE INDEX idx_daily_closings_year_month ON daily_closings(year, month)
    ''');

    // Tabla de transacciones
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        daily_closing_id INTEGER NOT NULL,
        transaction_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        valor REAL NOT NULL,
        comprobante TEXT NOT NULL,
        dia TEXT NOT NULL,
        mes TEXT NOT NULL,
        ano TEXT NOT NULL,
        hora TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        category TEXT NOT NULL,
        is_cancellation INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (daily_closing_id) REFERENCES daily_closings(id) ON DELETE CASCADE
      )
    ''');

    // Índices para transactions
    await db.execute('''
      CREATE INDEX idx_transactions_daily_closing ON transactions(daily_closing_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_category ON transactions(category)
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_timestamp ON transactions(timestamp)
    ''');

    // Tabla de cierres semanales
    await db.execute('''
      CREATE TABLE weekly_closings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        week_number INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        total_pasajes REAL NOT NULL DEFAULT 0,
        total_correspondencias REAL NOT NULL DEFAULT 0,
        total_anulaciones REAL NOT NULL DEFAULT 0,
        grand_total REAL NOT NULL DEFAULT 0,
        transaction_count INTEGER NOT NULL DEFAULT 0,
        daily_closing_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        pdf_filename TEXT,
        UNIQUE(year, week_number)
      )
    ''');

    // Índice para weekly_closings
    await db.execute('''
      CREATE INDEX idx_weekly_closings_year_week ON weekly_closings(year, week_number)
    ''');

    // Tabla de cierres mensuales
    await db.execute('''
      CREATE TABLE monthly_closings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        month_name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        total_pasajes REAL NOT NULL DEFAULT 0,
        total_correspondencias REAL NOT NULL DEFAULT 0,
        total_anulaciones REAL NOT NULL DEFAULT 0,
        grand_total REAL NOT NULL DEFAULT 0,
        transaction_count INTEGER NOT NULL DEFAULT 0,
        daily_closing_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        pdf_filename TEXT,
        UNIQUE(year, month)
      )
    ''');

    // Índice para monthly_closings
    await db.execute('''
      CREATE INDEX idx_monthly_closings_year_month ON monthly_closings(year, month)
    ''');
  }

  /// Actualiza la base de datos cuando cambia la versión
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Para futuras migraciones
    // Ejemplo:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE daily_closings ADD COLUMN new_field TEXT');
    // }
  }

  /// Cierra la base de datos
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
