import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de almacenamiento local (SharedPreferences) para pagos
/// realizados con tarjeta vía SumUp.
///
/// Los pagos se guardan bajo la clave `pagos_tarjeta_YYYY-MM-DD` como
/// lista JSON. Cada entrada tiene la forma:
/// ```json
/// { "monto": 1500.0, "txCode": "ABC123", "fecha": "...", "tipo": "tarjeta" }
/// ```
class PagoStorageService {
  static String _claveHoy() {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return 'pagos_tarjeta_$hoy';
  }

  /// Guarda un pago con tarjeta del día actual.
  static Future<void> guardarPagoTarjeta({
    required double monto,
    required String txCode,
    required String fecha,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final clave = _claveHoy();
    final datosExistentes = prefs.getString(clave);

    List<Map<String, dynamic>> lista = [];
    if (datosExistentes != null) {
      final decoded = json.decode(datosExistentes) as List<dynamic>;
      lista = decoded.cast<Map<String, dynamic>>();
    }

    lista.add({
      'monto': monto,
      'txCode': txCode,
      'fecha': fecha,
      'tipo': 'tarjeta',
    });

    await prefs.setString(clave, json.encode(lista));
  }

  /// Devuelve la lista de pagos con tarjeta registrados hoy.
  static Future<List<Map<String, dynamic>>> obtenerPagosTarjetaHoy() async {
    final prefs = await SharedPreferences.getInstance();
    final clave = _claveHoy();
    final datos = prefs.getString(clave);

    if (datos == null) return [];

    final decoded = json.decode(datos) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Obtiene el total cobrado con tarjeta hoy.
  static Future<double> obtenerTotalTarjetaHoy() async {
    final pagos = await obtenerPagosTarjetaHoy();
    return pagos.fold<double>(
      0.0,
      (sum, pago) => sum + ((pago['monto'] as num?)?.toDouble() ?? 0.0),
    );
  }

  /// Elimina los pagos de tarjeta de días anteriores al actual.
  ///
  /// Recorre todas las claves de SharedPreferences buscando las que
  /// coincidan con el patrón `pagos_tarjeta_YYYY-MM-DD` y elimina las
  /// que NO correspondan al día de hoy.
  static Future<void> limpiarPagosAnteriores() async {
    final prefs = await SharedPreferences.getInstance();
    final claveHoy = _claveHoy();
    final todasLasClaves = prefs.getKeys();

    for (final clave in todasLasClaves) {
      if (clave.startsWith('pagos_tarjeta_') && clave != claveHoy) {
        await prefs.remove(clave);
      }
    }
  }
}
