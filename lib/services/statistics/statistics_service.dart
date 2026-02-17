import '../../database/database_service.dart';
import '../../database/models/transaction_entity.dart';

/// Servicio para obtener estadísticas de ventas
class StatisticsService {
  final DatabaseService _dbService;

  StatisticsService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Obtiene estadísticas de ventas de los últimos N días
  Future<Map<String, dynamic>> getSalesStatistics({int days = 30}) async {
    try {
      final closings = await _dbService.getAllDailyClosings();

      if (closings.isEmpty) {
        return _emptyStats();
      }

      // Filtrar solo los últimos N días
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: days));

      final recentClosings = closings.where((c) {
        final closingDate = DateTime(c.year, c.month, c.day);
        return closingDate.isAfter(cutoffDate) ||
            closingDate.isAtSameMomentAs(cutoffDate);
      }).toList();

      // Estadísticas generales
      double totalVentas = 0;
      double totalPasajes = 0;
      double totalCorrespondencias = 0;
      double totalAnulaciones = 0;
      int totalTransacciones = 0;

      // Ventas por día (para gráfico)
      Map<String, double> ventasPorDia = {};

      // Ventas por tipo de pasaje
      Map<String, int> ventasPorTipo = {};
      Map<String, double> ingresosPorTipo = {};

      for (var closing in recentClosings) {
        totalVentas += closing.grandTotal;
        totalPasajes += closing.totalPasajes;
        totalCorrespondencias += closing.totalCorrespondencias;
        totalAnulaciones += closing.totalAnulaciones.abs();
        totalTransacciones += closing.transactionCount;

        // Agrupar ventas por día
        final dateKey =
            '${closing.day.toString().padLeft(2, '0')}/${closing.month.toString().padLeft(2, '0')}';
        ventasPorDia[dateKey] =
            (ventasPorDia[dateKey] ?? 0) + closing.grandTotal;

        // Obtener transacciones para estadísticas detalladas
        if (closing.id != null) {
          final transactions =
              await _dbService.getTransactionsByClosingId(closing.id!);
          for (var tx in transactions) {
            if (tx.category == TransactionCategory.pasaje) {
              final tipo = tx.nombre;
              ventasPorTipo[tipo] = (ventasPorTipo[tipo] ?? 0) + 1;
              ingresosPorTipo[tipo] = (ingresosPorTipo[tipo] ?? 0) + tx.valor;
            }
          }
        }
      }

      // Calcular promedios
      final diasConVentas = recentClosings.length;
      final promedioDiario =
          diasConVentas > 0 ? totalVentas / diasConVentas : 0.0;
      final promedioTransacciones =
          diasConVentas > 0 ? totalTransacciones / diasConVentas : 0.0;

      // Día con más ventas
      String mejorDia = '';
      double maxVentas = 0;
      ventasPorDia.forEach((dia, ventas) {
        if (ventas > maxVentas) {
          maxVentas = ventas;
          mejorDia = dia;
        }
      });

      // Tipo de pasaje más vendido
      String pasajeMasVendido = '';
      int maxCantidad = 0;
      ventasPorTipo.forEach((tipo, cantidad) {
        if (cantidad > maxCantidad) {
          maxCantidad = cantidad;
          pasajeMasVendido = tipo;
        }
      });

      return {
        'totalVentas': totalVentas,
        'totalPasajes': totalPasajes,
        'totalCorrespondencias': totalCorrespondencias,
        'totalAnulaciones': totalAnulaciones,
        'totalTransacciones': totalTransacciones,
        'diasConVentas': diasConVentas,
        'promedioDiario': promedioDiario,
        'promedioTransacciones': promedioTransacciones,
        'mejorDia': mejorDia,
        'maxVentas': maxVentas,
        'pasajeMasVendido': pasajeMasVendido,
        'cantidadPasajeMasVendido': maxCantidad,
        'ventasPorDia': ventasPorDia,
        'ventasPorTipo': ventasPorTipo,
        'ingresosPorTipo': ingresosPorTipo,
      };
    } catch (e) {
      print('Error al obtener estadísticas: $e');
      return _emptyStats();
    }
  }

  /// Obtiene las ventas de los últimos 7 días para el gráfico
  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    try {
      final now = DateTime.now();
      final List<Map<String, dynamic>> weeklySales = [];

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final closing = await _dbService.getDailyClosingByDate(dateStr);

        weeklySales.add({
          'dia': _getDayName(date.weekday),
          'fecha': '${date.day}/${date.month}',
          'ventas': closing?.grandTotal ?? 0.0,
          'transacciones': closing?.transactionCount ?? 0,
        });
      }

      return weeklySales;
    } catch (e) {
      print('Error al obtener ventas semanales: $e');
      return [];
    }
  }

  /// Elimina todos los cierres de caja (y sus transacciones por CASCADE)
  Future<bool> deleteAllClosings() async {
    try {
      final closings = await _dbService.getAllDailyClosings();

      for (var closing in closings) {
        if (closing.id != null) {
          await _dbService.deleteDailyClosing(closing.id!);
        }
      }

      // También limpiar cierres semanales y mensuales
      final weeklyClosings = await _dbService.getAllWeeklyClosings();
      for (var closing in weeklyClosings) {
        if (closing.id != null) {
          await _dbService.deleteWeeklyClosing(closing.id!);
        }
      }

      final monthlyClosings = await _dbService.getAllMonthlyClosings();
      for (var closing in monthlyClosings) {
        if (closing.id != null) {
          await _dbService.deleteMonthlyClosing(closing.id!);
        }
      }

      return true;
    } catch (e) {
      print('Error al eliminar cierres: $e');
      return false;
    }
  }

  String _getDayName(int weekday) {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days[weekday - 1];
  }

  Map<String, dynamic> _emptyStats() {
    return {
      'totalVentas': 0.0,
      'totalPasajes': 0.0,
      'totalCorrespondencias': 0.0,
      'totalAnulaciones': 0.0,
      'totalTransacciones': 0,
      'diasConVentas': 0,
      'promedioDiario': 0.0,
      'promedioTransacciones': 0.0,
      'mejorDia': '-',
      'maxVentas': 0.0,
      'pasajeMasVendido': '-',
      'cantidadPasajeMasVendido': 0,
      'ventasPorDia': <String, double>{},
      'ventasPorTipo': <String, int>{},
      'ingresosPorTipo': <String, double>{},
    };
  }
}
