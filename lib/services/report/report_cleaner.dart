import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

/// Clase utilitaria para gestionar estadísticas de reportes
class ReportCleaner {
  /// Obtiene estadísticas sobre los reportes almacenados
  static Future<Map<String, dynamic>> getReportStatistics() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> files = directory.listSync();

      int totalReports = 0;
      int reportsLastWeek = 0;
      int oldestReportDays = 0;
      double totalSizeMB = 0;

      final now = DateTime.now();
      final lastWeekDate = now.subtract(Duration(days: 7));

      for (var entity in files) {
        if (entity is File) {
          final String fileName = entity.path.split('/').last;

          if (fileName.startsWith('reporte_') && fileName.endsWith('.pdf')) {
            totalReports++;

            // Calcular el tamaño
            final fileSize = await entity.length();
            totalSizeMB += fileSize / (1024 * 1024);

            // Verificar si es de la última semana
            final FileStat stats = await entity.stat();
            final fileDate = stats.modified;
            final differenceInDays = now.difference(fileDate).inDays;

            if (fileDate.isAfter(lastWeekDate)) {
              reportsLastWeek++;
            }

            // Actualizar el reporte más antiguo
            if (differenceInDays > oldestReportDays) {
              oldestReportDays = differenceInDays;
            }
          }
        }
      }

      return {
        'totalReports': totalReports,
        'reportsLastWeek': reportsLastWeek,
        'oldestReportDays': oldestReportDays,
        'totalSizeMB': totalSizeMB.toStringAsFixed(2),
        'timestamp': DateFormat('dd/MM/yyyy HH:mm').format(now),
      };
    } catch (e) {
      debugPrint('Error al obtener estadísticas de reportes: $e');
      return {
        'error': e.toString(),
        'timestamp': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      };
    }
  }
}