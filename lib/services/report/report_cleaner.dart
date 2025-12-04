import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

/// Clase utilitaria para gestionar la limpieza automática de reportes y estadísticas
class ReportCleaner {
  // Constante para definir el período de retención de reportes (30 días por defecto)
  static const int DEFAULT_RETENTION_DAYS = 30;

  /// Limpia los reportes vencidos cuando se inicia la aplicación
  /// Retorna la cantidad de reportes eliminados
  static Future<int> cleanExpiredReportsOnStartup([int retentionDays = DEFAULT_RETENTION_DAYS]) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final DateTime cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      int cleanedCount = 0;

      // Obtener la lista de archivos en el directorio
      final List<FileSystemEntity> files = directory.listSync();

      for (var entity in files) {
        if (entity is File) {
          final String fileName = entity.path.split('/').last;

          // Verificar si es un archivo de reporte PDF o un informe de día
          if ((fileName.startsWith('reporte_') && fileName.endsWith('.pdf')) ||
              (fileName.startsWith('informe_dia_') && fileName.endsWith('.txt'))) {
            try {
              final FileStat stats = await entity.stat();
              final fileDate = stats.modified;
              final difference = DateTime.now().difference(fileDate).inDays;

              // Si el archivo es más antiguo que el límite, lo eliminamos
              if (difference > retentionDays) {
                await entity.delete();
                cleanedCount++;
                debugPrint('Eliminado reporte antiguo: $fileName (${difference} días)');
              }
            } catch (e) {
              debugPrint('Error al procesar archivo para limpieza: $fileName - $e');
            }
          }
        }
      }

      if (cleanedCount > 0) {
        debugPrint('Limpieza automática completada: $cleanedCount archivos eliminados.');
      }

      return cleanedCount;
    } catch (e) {
      debugPrint('Error durante la limpieza automática de reportes: $e');
      return 0;
    }
  }

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