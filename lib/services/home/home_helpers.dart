import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Helpers y utilidades para la pantalla Home
class HomeHelpers {
  /// Formatea información de contacto (teléfono o email)
  static String formatContactInfo(String value, bool isPhone) {
    if (isPhone) {
      if (value.length < 8) return value;
      return '${value.substring(0, 1)} ${value.substring(1, 5)} ${value.substring(5)}';
    } else {
      return value;
    }
  }

  /// Carga la contraseña almacenada
  static Future<String> loadPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('password') ?? '232323';
  }

  /// Guarda la última transacción
  static Future<void> saveLastTransaction(Map<String, dynamic> transaction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastTransaction', jsonEncode(transaction));
    } catch (e) {
      print('Error al guardar la última transacción: $e');
    }
  }

  /// Carga la última transacción
  static Future<Map<String, dynamic>?> loadLastTransaction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? lastTransactionJson = prefs.getString('lastTransaction');

      if (lastTransactionJson != null && lastTransactionJson.isNotEmpty) {
        return jsonDecode(lastTransactionJson);
      }
    } catch (e) {
      print('Error al cargar la última transacción: $e');
    }
    return null;
  }

  /// Obtiene la fecha actual formateada
  static String getCurrentDate() {
    return DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  /// Obtiene el día de la semana actual en español
  static String getCurrentDay() {
    try {
      return DateFormat('EEEE', 'es_ES').format(DateTime.now()).toUpperCase();
    } catch (e) {
      // Fallback si la localización no está inicializada
      const days = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO'];
      return days[DateTime.now().weekday - 1];
    }
  }

  /// Verifica si el total de oferta es cero
  static bool isTotalZero(List<Map<String, dynamic>> offerEntries) {
    double total = offerEntries.fold(0.0, (sum, entry) {
      double number = double.tryParse(entry['number'] ?? '0') ?? 0.0;
      double value = double.tryParse(entry['value'] ?? '0') ?? 0.0;
      return sum + (number * value);
    });
    return total == 0;
  }

  /// Cancela la última transacción
  static Future<void> cancelLastTransaction(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    int comprobanteNumber = prefs.getInt('comprobanteNumber') ?? 1;

    if (comprobanteNumber > 1) {
      comprobanteNumber--;
      await prefs.setInt('comprobanteNumber', comprobanteNumber);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Última venta anulada.')),
    );
  }

  /// Carga la configuración de íconos
  static Future<Map<String, IconData>> loadIconSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic>? savedIcons =
          prefs.getString('buttonIcons') != null
              ? json.decode(prefs.getString('buttonIcons')!)
              : null;

      Map<String, IconData> buttonIcons = {};

      if (savedIcons != null) {
        savedIcons.forEach((key, value) {
          buttonIcons[key] = _getIconFromString(value.toString());
        });
      }

      print('Icon settings loaded: icons=${buttonIcons.length}');
      return buttonIcons;
    } catch (e) {
      print('Error loading icon settings: $e');
      return {};
    }
  }

  /// Convierte un string a IconData
  static IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'people':
        return Icons.people;
      case 'school':
        return Icons.school;
      case 'school_outlined':
        return Icons.school_outlined;
      case 'elderly':
        return Icons.elderly;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'map':
        return Icons.map;
      case 'local_offer':
        return Icons.local_offer;
      case 'inventory':
        return Icons.inventory;
      case 'confirmation_number':
        return Icons.confirmation_number;
      case 'receipt':
        return Icons.receipt;
      case 'attach_money':
        return Icons.attach_money;
      case 'mail':
        return Icons.mail;
      default:
        return Icons.error;
    }
  }

  /// Carga preferencias de visualización
  static Future<Map<String, dynamic>> loadDisplayPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final showIcons = prefs.getBool('showIcons');
      final textSizeMultiplier = prefs.getDouble('textSizeMultiplier');
      final iconSpacing = prefs.getDouble('iconSpacing');

      print(
          'Loading display preferences: showIcons=$showIcons, textSizeMultiplier=$textSizeMultiplier');

      return {
        'showIcons': showIcons ?? true,
        'textSizeMultiplier': textSizeMultiplier ?? 0.8,
        'iconSpacing': iconSpacing ?? 1.0,
      };
    } catch (e) {
      print('Error loading display preferences: $e');
      return {
        'showIcons': true,
        'textSizeMultiplier': 0.8,
        'iconSpacing': 1.0,
      };
    }
  }
}
