import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../models/ReporteCaja.dart';
import '../../database/database_service.dart';
import '../../database/models/daily_closing_entity.dart';
import '../../database/models/transaction_entity.dart';
import '../closing/merge_service.dart';

/// Servicio para manejar el cierre automático al cambiar de día
class AutoClosingService {
  static const String _lastTransactionDateKey = 'last_transaction_date';

  final DatabaseService _dbService;
  final MergeService _mergeService;

  AutoClosingService({
    DatabaseService? dbService,
    MergeService? mergeService,
  })  : _dbService = dbService ?? DatabaseService(),
        _mergeService = mergeService ?? MergeService();

  /// Verifica si hay un cambio de día y cierra la caja automáticamente si es necesario
  /// Retorna true si se realizó un cierre automático
  Future<bool> checkAndAutoClose(ReporteCaja reporteCaja) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final lastTransactionDate = prefs.getString(_lastTransactionDateKey);

      // Si no hay fecha previa o es el mismo día, no hacer nada
      if (lastTransactionDate == null || lastTransactionDate == today) {
        return false;
      }

      // Verificar si hay transacciones pendientes del día anterior
      if (!reporteCaja.hasActiveTransactions()) {
        // No hay transacciones, solo actualizar la fecha
        await prefs.setString(_lastTransactionDateKey, today);
        return false;
      }

      // Hay transacciones de un día anterior, hacer cierre automático
      print(
          'AutoClosingService: Detectado cambio de día ($lastTransactionDate -> $today)');
      print('AutoClosingService: Realizando cierre automático...');

      final success = await _performAutoClose(reporteCaja, lastTransactionDate);

      if (success) {
        // Actualizar la fecha de última transacción
        await prefs.setString(_lastTransactionDateKey, today);
        print('AutoClosingService: Cierre automático completado');
      }

      return success;
    } catch (e) {
      print('AutoClosingService: Error en verificación de auto-cierre: $e');
      return false;
    }
  }

  /// Actualiza la fecha de la última transacción al día actual
  Future<void> updateLastTransactionDate() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString(_lastTransactionDateKey, today);
  }

  /// Realiza el cierre automático de la caja
  Future<bool> _performAutoClose(
      ReporteCaja reporteCaja, String closingDate) async {
    try {
      final transactions = reporteCaja.getOrderedTransactions();

      if (transactions.isEmpty) {
        return false;
      }

      // Parsear la fecha del cierre
      final dateParts = closingDate.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      // Verificar si ya existe un cierre para esa fecha
      final existingClosing =
          await _dbService.getDailyClosingByDate(closingDate);

      if (existingClosing != null) {
        // Fusionar con el cierre existente
        await _mergeService.mergeDailyClosings(existingClosing, transactions);
      } else {
        // Crear nuevo cierre
        await _createNewClosing(transactions, closingDate, year, month, day);
      }

      // Limpiar las transacciones del ReporteCaja
      await reporteCaja.clearTransactions();

      return true;
    } catch (e) {
      print('AutoClosingService: Error al realizar cierre automático: $e');
      return false;
    }
  }

  /// Crea un nuevo cierre diario
  Future<void> _createNewClosing(
    List<Map<String, dynamic>> transactions,
    String date,
    int year,
    int month,
    int day,
  ) async {
    // Calcular totales
    double totalPasajes = 0;
    double totalCorrespondencias = 0;
    double totalAnulaciones = 0;

    for (var t in transactions) {
      final nombre = t['nombre'].toString().toLowerCase();
      final valor = (t['valor'] as num).toDouble();

      if (nombre.startsWith('anulación:')) {
        totalAnulaciones += valor;
      } else if (nombre.contains('cargo:') ||
          nombre.contains('correspondencia')) {
        totalCorrespondencias += valor;
      } else {
        totalPasajes += valor;
      }
    }

    final grandTotal = totalPasajes + totalCorrespondencias + totalAnulaciones;

    // Obtener día de la semana
    final closingDateTime = DateTime(year, month, day);
    final dayOfWeek = _getDayOfWeek(closingDateTime.weekday);
    final now = DateTime.now();

    // Crear el cierre diario
    final closing = DailyClosingEntity(
      date: date,
      year: year,
      month: month,
      day: day,
      dayOfWeek: dayOfWeek,
      totalPasajes: totalPasajes,
      totalCorrespondencias: totalCorrespondencias,
      totalAnulaciones: totalAnulaciones,
      grandTotal: grandTotal,
      transactionCount: transactions.length,
      status: ClosingStatus.closed,
      createdAt: now.millisecondsSinceEpoch,
      closedAt: now.millisecondsSinceEpoch,
    );

    final closingId = await _dbService.insertDailyClosing(closing);

    // Insertar las transacciones
    final transactionEntities = transactions.map((t) {
      return TransactionEntity.fromReporteCaja(t, closingId);
    }).toList();

    await _dbService.insertTransactionBatch(transactionEntities);
  }

  /// Verifica si es necesario mostrar alerta de cambio de día
  Future<bool> shouldShowDayChangeAlert(ReporteCaja reporteCaja) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastTransactionDate = prefs.getString(_lastTransactionDateKey);

    if (lastTransactionDate == null || lastTransactionDate == today) {
      return false;
    }

    return reporteCaja.hasActiveTransactions();
  }

  /// Obtiene la fecha de la última transacción
  Future<String?> getLastTransactionDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastTransactionDateKey);
  }

  /// Obtiene el nombre del día de la semana en español
  String _getDayOfWeek(int weekday) {
    const days = [
      'LUNES',
      'MARTES',
      'MIÉRCOLES',
      'JUEVES',
      'VIERNES',
      'SÁBADO',
      'DOMINGO'
    ];
    return days[weekday - 1];
  }
}
