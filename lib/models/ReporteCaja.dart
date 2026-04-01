import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReporteCaja extends ChangeNotifier {
  final List<Map<String, dynamic>> _transactions = [];
  int _nextId = 1;

  static const String _prefsKey = 'reporte_caja_transactions';
  static const String _prefsNextIdKey = 'reporte_caja_next_id';

  ReporteCaja() {
    _loadFromPrefs();
  }

  // ── Persistencia ──────────────────────────────────────────────────────────

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_prefsKey);
      final int? savedNextId = prefs.getInt(_prefsNextIdKey);

      if (data != null) {
        final List<dynamic> decoded = json.decode(data);
        _transactions.clear();
        _transactions.addAll(decoded.cast<Map<String, dynamic>>());
      }
      if (savedNextId != null) {
        _nextId = savedNextId;
      } else if (_transactions.isNotEmpty) {
        // Recalcular nextId desde los datos cargados
        _nextId = _transactions
                .map((t) => (t['id'] as int?) ?? 0)
                .reduce((a, b) => a > b ? a : b) +
            1;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando transacciones: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, json.encode(_transactions));
      await prefs.setInt(_prefsNextIdKey, _nextId);
    } catch (e) {
      debugPrint('Error guardando transacciones: $e');
      rethrow;
    }
  }

  // Nueva clase de transacción para guardar correctamente los datos por día
  Map<String, dynamic> _createTransaction(String nombre, double valor, String comprobante) {
    // Obtener día, mes, año y hora actual
    DateTime now = DateTime.now();
    String dia = DateFormat('dd').format(now);
    String mes = DateFormat('MM').format(now);
    String ano = DateFormat('yyyy').format(now);
    String hora = DateFormat('HH:mm').format(now); // Cambiado de HH:mm:ss a HH:mm para eliminar los segundos

    return {
      'id': _nextId++,
      'nombre': nombre,
      'valor': valor,
      'comprobante': comprobante,
      'dia': dia,
      'mes': mes,
      'ano': ano, // Ahora guardamos también el año
      'hora': hora,
      'timestamp': now.millisecondsSinceEpoch
    };
  }

  // Recibir datos de ticket
  Future<void> receiveData(String nombre, double valor, String comprobante) async {
    _transactions.add(_createTransaction(nombre, valor, comprobante));
    await _saveToPrefs();
    notifyListeners();
  }

  // Recibir datos de cargo (para tickets de cargo)
  Future<void> receiveCargoData(String destinatario, double precio, String comprobante) async {
    _transactions.add(_createTransaction('Cargo: $destinatario', precio, comprobante));
    await _saveToPrefs();
    notifyListeners();
  }

  // Añadir entradas de oferta (para tickets de oferta múltiple)
  Future<void> addOfferEntries(List<double> subtotals, double total, String comprobante) async {
    _transactions.add(_createTransaction('Oferta Ruta', total, comprobante));
    await _saveToPrefs();
    notifyListeners();
  }

  // Cancelar última transacción
  Future<void> cancelTransaction() async {
    if (_transactions.isEmpty) return;

    // Buscar la última transacción que no sea una anulación
    Map<String, dynamic>? lastTransaction;
    for (int i = _transactions.length - 1; i >= 0; i--) {
      if (!_transactions[i]['nombre'].toString().startsWith('Anulación:')) {
        lastTransaction = _transactions[i];
        break;
      }
    }

    if (lastTransaction != null) {
      // Crear una nueva transacción de anulación
      String nombre = 'Anulación: ${lastTransaction['nombre']}';
      double valor = -lastTransaction['valor']; // Valor negativo
      String comprobante = lastTransaction['comprobante'];

      _transactions.add(_createTransaction(nombre, valor, comprobante));
      await _saveToPrefs();
      notifyListeners();
    }
  }

  // Obtener transacciones ordenadas
  List<Map<String, dynamic>> getOrderedTransactions() {
    // Ordenar por ID (más antiguos primero)
    List<Map<String, dynamic>> sortedList = List.from(_transactions);
    sortedList.sort((a, b) => a['id'].compareTo(b['id']));
    return sortedList;
  }

  // NUEVO: Eliminar una transacción específica por ID
  Future<void> removeTransaction(int id) async {
    _transactions.removeWhere((t) => t['id'] == id);
    await _saveToPrefs();
    notifyListeners();
  }

  // Calcular el total considerando anulaciones
  double getTotal() {
    return _transactions.fold(0, (total, transaction) {
      return total + (transaction['valor'] ?? 0);
    });
  }

  // Verificar si hay transacciones activas
  bool hasActiveTransactions() {
    return _transactions.isNotEmpty;
  }

  // Vaciar todas las transacciones
  Future<void> clearTransactions() async {
    _transactions.clear();
    _nextId = 1;
    await _saveToPrefs();
    notifyListeners();
  }

  // NUEVO: Obtener transacciones por fecha
  List<Map<String, dynamic>> getTransactionsByDate(String day, String month, String year) {
    return _transactions.where((t) =>
    t['dia'] == day &&
        t['mes'] == month &&
        (t['ano'] == year || t['ano'] == null)
    ).toList();
  }

  // NUEVO: Verificar si hay transacciones de días anteriores
  bool hasPendingOldTransactions() {
    final today = DateTime.now();
    final todayDay = int.parse(DateFormat('dd').format(today));
    final todayMonth = int.parse(DateFormat('MM').format(today));
    final todayYear = today.year; // Aquí aseguramos que es int desde el principio

    return _transactions.any((t) {
      // Ignorar anulaciones
      if (t['nombre'].toString().startsWith('Anulación:')) {
        return false;
      }

      // Obtener fecha de la transacción y convertir a int
      final transDay = int.tryParse(t['dia']) ?? todayDay;
      final transMonth = int.tryParse(t['mes']) ?? todayMonth;
      final transYear = int.tryParse(t['ano'] ?? todayYear.toString()) ?? todayYear;

      // Determinar si la transacción es de un día anterior
      if (transYear < todayYear) {
        return true; // Año anterior
      } else if (transYear == todayYear) {
        if (transMonth < todayMonth) {
          return true; // Mes anterior en el mismo año
        } else if (transMonth == todayMonth && transDay < todayDay) {
          return true; // Día anterior en el mismo mes
        }
      }

      return false;
    });
  }


  // NUEVO: Obtener días con transacciones pendientes
  int getOldestPendingDays() {
    final today = DateTime.now();
    int maxDays = 0;

    for (var transaction in _transactions) {
      // Ignorar anulaciones
      if (transaction['nombre'].toString().startsWith('Anulación:')) {
        continue;
      }

      try {
        final transDay = int.parse(transaction['dia']);
        final transMonth = int.parse(transaction['mes']);
        final transYear = int.parse(transaction['ano'] ?? today.year.toString());

        final transDate = DateTime(transYear, transMonth, transDay);
        final differenceInDays = today.difference(transDate).inDays;

        if (differenceInDays > maxDays) {
          maxDays = differenceInDays;
        }
      } catch (e) {
        print('Error al procesar fecha: $e');
      }
    }

    return maxDays;
  }
}