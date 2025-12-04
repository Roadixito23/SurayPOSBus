import 'package:shared_preferences/shared_preferences.dart';
import '../pdf/pdfReport_generator.dart';

/// Servicio para realizar tareas de mantenimiento programadas
class MaintenanceService {
  /// Ejecuta tareas de mantenimiento (limpieza de reportes antiguos)
  static Future<void> performMaintenanceTasks() async {
    try {
      // Verificar cuándo fue la última limpieza
      final prefs = await SharedPreferences.getInstance();
      final lastCleanup = prefs.getInt('lastReportCleanup') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Si han pasado más de 7 días desde la última limpieza
      if (now - lastCleanup > Duration(days: 7).inMilliseconds) {
        print('Ejecutando limpieza programada de reportes antiguos...');

        // Crear instancia correctamente
        final generator = PdfReportGenerator();
        await generator.cleanOldReports(30); // Mantener reportes hasta 30 días

        // Guardar timestamp de la última limpieza
        await prefs.setInt('lastReportCleanup', now);
        print('Limpieza completada. Próxima limpieza en 7 días.');
      }
    } catch (e) {
      print('Error al realizar tareas de mantenimiento: $e');
    }
  }
}
