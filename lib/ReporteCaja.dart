import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class ReporteCaja extends ChangeNotifier {
  List<Map<String, dynamic>> _transactions = [];
  int _nextId = 1;

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
  void receiveData(String nombre, double valor, String comprobante) {
    _transactions.add(_createTransaction(nombre, valor, comprobante));
    notifyListeners();
  }

  // Recibir datos de cargo (para tickets de cargo)
  void receiveCargoData(String destinatario, double precio, String comprobante) {
    _transactions.add(_createTransaction('Cargo: $destinatario', precio, comprobante));
    notifyListeners();
  }

  // Añadir entradas de oferta (para tickets de oferta múltiple)
  void addOfferEntries(List<double> subtotals, double total, String comprobante) {
    _transactions.add(_createTransaction('Oferta Ruta', total, comprobante));
    notifyListeners();
  }

  // Cancelar última transacción
  void cancelTransaction() {
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
  void removeTransaction(int id) {
    _transactions.removeWhere((t) => t['id'] == id);
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
  void clearTransactions() {
    _transactions.clear();
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