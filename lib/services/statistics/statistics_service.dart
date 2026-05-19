import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database_service.dart';

/// Servicio para obtener estadísticas de ventas desde SQLite + SharedPreferences
class StatisticsService {
  static const String _transactionsKey = 'reporte_caja_transactions';

  /// Carga todas las transacciones: históricas (SQLite) + día actual (SharedPreferences)
  Future<List<Map<String, dynamic>>> _loadAllTransactions() async {
    // 1. Transacciones históricas desde SQLite (días ya cerrados)
    // Try-catch propio: un fallo en BD no debe cancelar la lectura de SharedPreferences
    List<Map<String, dynamic>> dbTransactions = [];
    try {
      final dbService = DatabaseService();
      dbTransactions = await dbService.getAllTransactionsAsMap();
    } catch (e) {
      debugPrint('StatisticsService: no se pudo leer SQLite: $e');
    }

    // 2. Transacciones del día actual desde SharedPreferences (aún no cerradas)
    List<Map<String, dynamic>> prefsTransactions = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_transactionsKey);
      if (data != null && data.isNotEmpty) {
        final decoded = json.decode(data) as List<dynamic>;
        prefsTransactions = decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('StatisticsService: no se pudo leer SharedPreferences: $e');
    }

    return [...dbTransactions, ...prefsTransactions];
  }

  /// Obtiene estadísticas de ventas de los últimos [days] días
  Future<Map<String, dynamic>> getSalesStatistics({int days = 30}) async {
    try {
      final all = await _loadAllTransactions();
      if (all.isEmpty) return _emptyStats();

      final now = DateTime.now();
      final cutoff = now.subtract(Duration(days: days));

      // Filtrar al rango de días solicitado
      final transactions = all.where((t) {
        try {
          final d = int.parse(t['dia']);
          final m = int.parse(t['mes']);
          final y = int.parse(t['ano'] ?? now.year.toString());
          final date = DateTime(y, m, d);
          return !date.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day));
        } catch (_) {
          return true;
        }
      }).toList();

      if (transactions.isEmpty) return _emptyStats();

      double totalVentas = 0;
      double totalCorrespondencias = 0;
      double totalAnulaciones = 0;
      int totalTransacciones = 0;

      // Ventas reales por día (solo positivas, sin anulaciones)
      Map<String, double> ventasPorDia = {};
      Map<String, int> ventasPorTipo = {};
      Map<String, double> ingresosPorTipo = {};

      // Ventas por día de la semana (weekday 1=Lun … 7=Dom)
      Map<String, int> weekdayByDate = {}; // key: 'dd/mm/yyyy' → weekday

      for (var t in transactions) {
        final nombre = t['nombre']?.toString() ?? '';
        final double valor = (t['valor'] as num?)?.toDouble() ?? 0.0;
        final String dia = t['dia'] ?? '01';
        final String mes = t['mes'] ?? '01';
        final String ano = t['ano'] ?? now.year.toString();
        final String dateKey = '$dia/$mes/$ano';

        final bool isAnulacion = nombre.startsWith('Anulación:');
        final bool isCargo = nombre.toLowerCase().startsWith('cargo');

        if (isAnulacion) {
          totalAnulaciones += valor.abs();
        } else {
          totalVentas += valor;
          totalTransacciones++;

          ventasPorDia[dateKey] = (ventasPorDia[dateKey] ?? 0) + valor;

          // Guardar weekday para cada fecha
          if (!weekdayByDate.containsKey(dateKey)) {
            try {
              final d = int.parse(dia);
              final m = int.parse(mes);
              final y = int.parse(ano);
              weekdayByDate[dateKey] = DateTime(y, m, d).weekday; // 1=Lun, 7=Dom
            } catch (_) {}
          }

          if (isCargo) {
            totalCorrespondencias += valor;
          } else {
            ventasPorTipo[nombre] = (ventasPorTipo[nombre] ?? 0) + 1;
            ingresosPorTipo[nombre] = (ingresosPorTipo[nombre] ?? 0) + valor;
          }
        }
      }

      final diasConVentas = ventasPorDia.keys.length;
      final promedioDiario = diasConVentas > 0 ? totalVentas / diasConVentas : 0.0;

      // Día con más ventas
      String mejorDia = '-';
      double maxVentas = 0;
      ventasPorDia.forEach((dia, ventas) {
        if (ventas > maxVentas) {
          maxVentas = ventas;
          mejorDia = dia;
        }
      });

      // Tipo de pasaje más vendido
      String pasajeMasVendido = '-';
      int maxCantidad = 0;
      ventasPorTipo.forEach((tipo, cantidad) {
        if (cantidad > maxCantidad) {
          maxCantidad = cantidad;
          pasajeMasVendido = tipo;
        }
      });

      // ── Promedios por tipo de día ─────────────────────────────────────────
      // Semana completa: promedio de TODOS los días con ventas
      final promedioSemanal = diasConVentas > 0 ? totalVentas / diasConVentas : 0.0;

      // Lun–Sáb (weekday 1..6)
      final diasLunSab = ventasPorDia.entries
          .where((e) => (weekdayByDate[e.key] ?? 0) >= 1 &&
              (weekdayByDate[e.key] ?? 0) <= 6)
          .toList();
      final totalLunSab =
          diasLunSab.fold(0.0, (sum, e) => sum + e.value);
      final promedioLunSab =
          diasLunSab.isNotEmpty ? totalLunSab / diasLunSab.length : 0.0;

      // Domingos (weekday 7)
      final diasDomingo = ventasPorDia.entries
          .where((e) => (weekdayByDate[e.key] ?? 0) == 7)
          .toList();
      final totalDomingos =
          diasDomingo.fold(0.0, (sum, e) => sum + e.value);
      final promedioDomingos =
          diasDomingo.isNotEmpty ? totalDomingos / diasDomingo.length : 0.0;

      return {
        'totalVentas': totalVentas,
        'totalPasajes': totalVentas - totalCorrespondencias,
        'totalCorrespondencias': totalCorrespondencias,
        'totalAnulaciones': totalAnulaciones,
        'totalTransacciones': totalTransacciones,
        'diasConVentas': diasConVentas,
        'promedioDiario': promedioDiario,
        'promedioTransacciones':
            diasConVentas > 0 ? totalTransacciones / diasConVentas : 0.0,
        'mejorDia': mejorDia,
        'maxVentas': maxVentas,
        'pasajeMasVendido': pasajeMasVendido,
        'cantidadPasajeMasVendido': maxCantidad,
        'ventasPorDia': ventasPorDia,
        'ventasPorTipo': ventasPorTipo,
        'ingresosPorTipo': ingresosPorTipo,
        'promedioSemanal': promedioSemanal,
        'promedioLunSab': promedioLunSab,
        'promedioDomingos': promedioDomingos,
      };
    } catch (e) {
      print('StatisticsService: error en getSalesStatistics: $e');
      return _emptyStats();
    }
  }

  /// Obtiene las ventas de los últimos 7 días para el gráfico
  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    try {
      final all = await _loadAllTransactions();
      final now = DateTime.now();

      // Construir mapa dia → total vendido
      Map<String, double> ventasPorFecha = {};
      for (var t in all) {
        final nombre = t['nombre']?.toString() ?? '';
        if (nombre.startsWith('Anulación:')) continue;
        final double valor = (t['valor'] as num?)?.toDouble() ?? 0.0;
        if (valor <= 0) continue;
        final String dia = t['dia'] ?? '';
        final String mes = t['mes'] ?? '';
        final String ano = t['ano'] ?? now.year.toString();
        final key = '$ano-${mes.padLeft(2, '0')}-${dia.padLeft(2, '0')}';
        ventasPorFecha[key] = (ventasPorFecha[key] ?? 0) + valor;
      }

      return List.generate(7, (i) {
        final date = now.subtract(Duration(days: 6 - i));
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        return {
          'dia': _getDayName(date.weekday),
          'fecha': '${date.day}/${date.month}',
          'ventas': ventasPorFecha[key] ?? 0.0,
          'transacciones': 0,
        };
      });
    } catch (e) {
      print('StatisticsService: error en getWeeklySales: $e');
      return [];
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
      'promedioSemanal': 0.0,
      'promedioLunSab': 0.0,
      'promedioDomingos': 0.0,
    };
  }
}
