import '../../database/database_service.dart';
import '../../database/models/daily_closing_entity.dart';
import '../../database/models/transaction_entity.dart';

/// Servicio que maneja la fusión de cierres del mismo día
class MergeService {
  final DatabaseService _dbService;

  MergeService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Verifica si existe un cierre para una fecha específica
  Future<bool> hasClosingForDate(String date) async {
    final existing = await _dbService.getDailyClosingByDate(date);
    return existing != null;
  }

  /// Fusiona dos cierres del mismo día combinando todas las transacciones
  ///
  /// [existingClosing] - El cierre que ya existe en la base de datos
  /// [newTransactions] - Las nuevas transacciones del segundo cierre del día
  ///
  /// Retorna el cierre actualizado con todas las transacciones combinadas
  Future<DailyClosingEntity> mergeDailyClosings(
    DailyClosingEntity existingClosing,
    List<Map<String, dynamic>> newTransactions,
  ) async {
    print('MergeService: Fusionando cierre del ${existingClosing.date}');
    print('MergeService: Transacciones existentes: ${existingClosing.transactionCount}');
    print('MergeService: Nuevas transacciones: ${newTransactions.length}');

    return await _dbService.runInTransaction((txn) async {
      // 1. Obtener todas las transacciones existentes del cierre
      final existingTransactions = await _dbService.getTransactionsByClosingId(
        existingClosing.id!,
      );

      print('MergeService: Transacciones existentes cargadas: ${existingTransactions.length}');

      // 2. Convertir nuevas transacciones a entities
      final newTransactionEntities = newTransactions
          .map((t) => TransactionEntity.fromReporteCaja(t, existingClosing.id!))
          .toList();

      // 3. Insertar nuevas transacciones en la base de datos
      await _dbService.insertTransactionBatch(newTransactionEntities);

      print('MergeService: Nuevas transacciones insertadas: ${newTransactionEntities.length}');

      // 4. Combinar todas las transacciones para recalcular totales
      final allTransactions = [
        ...existingTransactions,
        ...newTransactionEntities,
      ];

      // 5. Recalcular totales por categoría
      final totals = _calculateTotals(allTransactions);

      print('MergeService: Totales recalculados - Pasajes: ${totals['pasajes']}, '
          'Correspondencias: ${totals['correspondencias']}, '
          'Anulaciones: ${totals['anulaciones']}, '
          'Total: ${totals['total']}');

      // 6. Actualizar el cierre diario con los nuevos totales
      final updatedClosing = existingClosing.copyWith(
        totalPasajes: totals['pasajes']!,
        totalCorrespondencias: totals['correspondencias']!,
        totalAnulaciones: totals['anulaciones']!,
        grandTotal: totals['total']!,
        transactionCount: allTransactions.length,
        closedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await _dbService.updateDailyClosing(updatedClosing);

      print('MergeService: Cierre actualizado - Total final: ${updatedClosing.grandTotal}, '
          'Transacciones totales: ${updatedClosing.transactionCount}');

      return updatedClosing;
    });
  }

  /// Calcula los totales por categoría de un conjunto de transacciones
  ///
  /// Retorna un Map con las claves: 'pasajes', 'correspondencias', 'anulaciones', 'total'
  Map<String, double> _calculateTotals(List<TransactionEntity> transactions) {
    double totalPasajes = 0.0;
    double totalCorrespondencias = 0.0;
    double totalAnulaciones = 0.0;

    for (var transaction in transactions) {
      switch (transaction.category) {
        case TransactionCategory.pasaje:
          totalPasajes += transaction.valor;
          break;
        case TransactionCategory.correspondencia:
          totalCorrespondencias += transaction.valor;
          break;
        case TransactionCategory.anulacion:
          totalAnulaciones += transaction.valor; // Ya es negativo
          break;
      }
    }

    final grandTotal = totalPasajes + totalCorrespondencias + totalAnulaciones;

    return {
      'pasajes': totalPasajes,
      'correspondencias': totalCorrespondencias,
      'anulaciones': totalAnulaciones,
      'total': grandTotal,
    };
  }

  /// Calcula los totales por categoría desde transacciones de ReporteCaja
  ///
  /// Usado cuando aún no se han convertido a entities
  Map<String, double> calculateTotalsFromReporteCaja(
    List<Map<String, dynamic>> transactions,
  ) {
    double totalPasajes = 0.0;
    double totalCorrespondencias = 0.0;
    double totalAnulaciones = 0.0;

    for (var transaction in transactions) {
      final nombre = transaction['nombre'] as String;
      final valor = (transaction['valor'] as num).toDouble();

      if (nombre.startsWith('Anulación:')) {
        totalAnulaciones += valor; // Ya es negativo
      } else if (nombre.startsWith('Cargo:')) {
        totalCorrespondencias += valor;
      } else {
        totalPasajes += valor;
      }
    }

    final grandTotal = totalPasajes + totalCorrespondencias + totalAnulaciones;

    return {
      'pasajes': totalPasajes,
      'correspondencias': totalCorrespondencias,
      'anulaciones': totalAnulaciones,
      'total': grandTotal,
    };
  }
}
