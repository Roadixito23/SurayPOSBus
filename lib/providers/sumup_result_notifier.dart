import 'package:flutter/foundation.dart';

/// Notifica a la UI el resultado de un pago SumUp recibido
/// a través del deep link callback `posbus://sumup-result`.
class SumUpResultNotifier extends ChangeNotifier {
  bool? _exitoso;
  String _txCode = '';
  String _monto = '';

  bool? get exitoso => _exitoso;
  String get txCode => _txCode;
  String get monto => _monto;

  /// Establece el resultado devuelto por la app de SumUp.
  void setResultado(bool exitoso, String txCode, String monto) {
    _exitoso = exitoso;
    _txCode = txCode;
    _monto = monto;
    notifyListeners();
  }

  /// Limpia el estado tras procesar el resultado.
  void limpiar() {
    _exitoso = null;
    _txCode = '';
    _monto = '';
    notifyListeners();
  }
}
