import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/ReporteCaja.dart';

/// Servicio para gestionar la verificación y alertas de transacciones pendientes
class PendingTransactionService {
  Timer? _pendingDaysCheckTimer;
  bool _hasShownPendingAlert = false;

  /// Verifica si hay transacciones de días anteriores sin cerrar
  bool hasPreviousDayTransactions(ReporteCaja reporteCaja) {
    return reporteCaja.hasPendingOldTransactions();
  }

  /// Obtiene el número de días pendientes
  int getPendingDays(ReporteCaja reporteCaja) {
    return reporteCaja.getOldestPendingDays();
  }

  /// Muestra diálogo de alerta para días pendientes
  Future<void> showPreviousDayAlert(
    BuildContext context,
    ReporteCaja reporteCaja,
    VoidCallback onNavigateToReports,
  ) async {
    // Si ya mostramos la alerta, no la mostramos de nuevo
    if (_hasShownPendingAlert) return;

    _hasShownPendingAlert = true;

    int pendingDays = getPendingDays(reporteCaja);
    String dayText = pendingDays == 1 ? 'día' : 'días';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Cierre de Caja Pendiente'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No es posible generar ventas porque existen transacciones de hace $pendingDays $dayText sin cerrar.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 15),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Debe cerrar la caja para continuar usando el sistema.',
                        style: TextStyle(color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.print),
              label: Text('Ir a Reportes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[800],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                onNavigateToReports();
              },
            ),
          ],
        );
      },
    ).then((_) {
      // Después de cerrar el diálogo, reseteamos la bandera después de un tiempo
      Future.delayed(Duration(minutes: 5), () {
        _hasShownPendingAlert = false;
      });
    });
  }

  /// Inicia verificación periódica de transacciones pendientes
  void startPendingTransactionsCheck(
    ReporteCaja reporteCaja,
    Function() onShowAlert,
  ) {
    // Cancelar timer existente si hay uno
    _pendingDaysCheckTimer?.cancel();

    // Crear un nuevo timer que verifica cada 5 minutos
    _pendingDaysCheckTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (hasPreviousDayTransactions(reporteCaja) && !_hasShownPendingAlert) {
        onShowAlert();
      }
    });
  }

  /// Cancela el timer de verificación
  void dispose() {
    _pendingDaysCheckTimer?.cancel();
  }
}
