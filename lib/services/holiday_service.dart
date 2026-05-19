import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resultado de verificar si hoy es día especial (domingo o feriado)
class HolidayCheckResult {
  final bool isSpecial;
  final String? reason; // nombre del feriado o 'Domingo'

  const HolidayCheckResult({required this.isSpecial, this.reason});
}

/// Estrategia de caché anual:
///
///  • El caché es **definitivo** si se obtuvo el 5 de enero o después.
///    Es válido para todo el año sin volver a consultar la API.
///
///  • El caché es **fungible** si se obtuvo antes del 5 de enero
///    (ej. primera apertura en enero 1–4 o fin del año anterior).
///    Se reemplaza automáticamente cuando el dispositivo llega al 5 de enero.
///
///  • Si no hay caché en absoluto se consulta la API de inmediato y se
///    almacena como definitivo o fungible según la fecha de hoy.
///
/// API utilizada: https://apis.digital.gob.cl/fl/feriados/{año}
class HolidayService {
  static const String _apiBase = 'https://apis.digital.gob.cl/fl/feriados';

  // Claves SharedPreferences (sufijo = año, ej. holidays_cache_2025)
  static const String _cachePrefix = 'holidays_cache_';
  static const String _fungiblePrefix = 'holidays_fungible_';

  // Fecha de renovación anual: 5 de enero
  static const int _refreshMonth = 1;
  static const int _refreshDay = 5;

  // ─── API pública ──────────────────────────────────────────────────────────

  /// Verifica si hoy es domingo o feriado.
  /// Devuelve [HolidayCheckResult] con [isSpecial] y el motivo si aplica.
  Future<HolidayCheckResult> checkToday() async {
    final today = DateTime.now();

    // Domingo: no necesita API
    if (today.weekday == DateTime.sunday) {
      return const HolidayCheckResult(isSpecial: true, reason: 'Domingo');
    }

    final holidays = await _getHolidaysForYear(today.year);
    final todayStr = _dateStr(today);

    final match = holidays.firstWhere(
      (h) => h['fecha'] == todayStr,
      orElse: () => {},
    );

    if (match.isNotEmpty) {
      return HolidayCheckResult(
        isSpecial: true,
        reason: match['nombre']?.toString() ?? 'Feriado',
      );
    }

    return const HolidayCheckResult(isSpecial: false, reason: null);
  }

  /// Fuerza una nueva consulta a la API descartando el caché del año actual.
  Future<HolidayCheckResult> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final year = DateTime.now().year;
    await prefs.remove('$_cachePrefix$year');
    await prefs.remove('$_fungiblePrefix$year');
    return checkToday();
  }

  // ─── Lógica interna ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _getHolidaysForYear(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('$_cachePrefix$year');
    final isFungible = prefs.getBool('$_fungiblePrefix$year') ?? true;

    if (cachedJson != null) {
      // Caché definitivo → válido todo el año, sin nueva consulta
      // Caché fungible  → vence cuando se llega al 5 de enero
      if (!_fungibleExpired(year, isFungible)) {
        return _decode(cachedJson);
      }
      debugPrint('HolidayService: caché fungible vencido, renovando para $year…');
    }

    // Sin caché válido: consultar API
    return _fetchAndCache(year, prefs);
  }

  /// Indica si un caché fungible necesita renovarse.
  /// Un caché definitivo (fungible = false) nunca expira dentro del año.
  bool _fungibleExpired(int year, bool isFungible) {
    if (!isFungible) return false;
    // Fungible vence cuando hoy >= 5 de enero del mismo año
    final jan5 = DateTime(year, _refreshMonth, _refreshDay);
    return !DateTime.now().isBefore(jan5);
  }

  /// Un caché generado antes del 5 de enero se considera fungible.
  bool _isCurrentFetchFungible(int year) {
    final jan5 = DateTime(year, _refreshMonth, _refreshDay);
    return DateTime.now().isBefore(jan5);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(
    int year,
    SharedPreferences prefs,
  ) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);

      final request = await client.getUrl(Uri.parse('$_apiBase/$year'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final holidays = _decode(body);
        final fungible = _isCurrentFetchFungible(year);

        await prefs.setString('$_cachePrefix$year', body);
        await prefs.setBool('$_fungiblePrefix$year', fungible);

        debugPrint(
          'HolidayService: ${holidays.length} feriados para $year '
          '(${fungible ? "fungible — se renovará el 5 de enero" : "definitivo"})',
        );
        return holidays;
      }

      debugPrint('HolidayService: HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('HolidayService: error al consultar API: $e');
    }

    // Fallback: usar caché existente aunque esté vencido antes de desistir
    final stale = prefs.getString('$_cachePrefix$year');
    if (stale != null) {
      debugPrint('HolidayService: usando caché vencido como fallback');
      return _decode(stale);
    }

    return [];
  }

  // ─── Utilidades ───────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _decode(String json_) {
    try {
      return (jsonDecode(json_) as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
