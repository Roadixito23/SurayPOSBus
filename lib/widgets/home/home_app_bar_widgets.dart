import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ReporteCaja.dart';
import '../../screens/reporte_caja_screen.dart';

/// Widget para construir slots del AppBar configurables
class HomeAppBarWidgets {
  /// Construye un widget según el tipo de elemento del slot
  static Widget buildAppBarSlotWidget({
    required BuildContext context,
    required Map<String, dynamic> slot,
    required String currentDay,
    required Map<String, dynamic>? lastTransaction,
    required bool hasReprinted,
    required bool hasAnulado,
    required bool isReprinting,
    required String Function() getCurrentDate,
    required VoidCallback onNavigateToSettings,
    required VoidCallback onShowOfferDialog,
    required VoidCallback onShowPasswordDialog,
    required VoidCallback onHandleReprint,
  }) {
    if (slot['isEmpty'] == true) {
      return Container();
    }

    String? elementKey = slot['element'] as String?;
    if (elementKey == null) {
      return Container();
    }

    // Additional margin parameter
    double leftMargin = slot['leftMargin'] ?? 0.0;

    // Report button (usually in slot 0)
    if (elementKey == 'report') {
      return Container(
        width: 25,
        height: 25,
        margin: EdgeInsets.only(left: 20 + leftMargin),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF1900A2),
        ),
        child: IconButton(
          icon: Icon(
            Icons.print,
            color: Colors.white,
            size: 24,
          ),
          padding: EdgeInsets.zero,
          tooltip: 'Reportes',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ReporteCajaScreen()),
            );
          },
        ),
      );
    }

    // Delete button
    else if (elementKey == 'delete') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: Consumer<ReporteCaja>(
          builder: (context, reporteCaja, child) {
            bool canAnular = reporteCaja.hasActiveTransactions() && !hasAnulado;
            return Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canAnular ? Color(0xFFFF0C00) : Colors.white,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(21),
                  onTap: canAnular ? onShowPasswordDialog : null,
                  child: Center(
                    child: Icon(
                      Icons.delete,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // Reprint button
    else if (elementKey == 'reprint') {
      // ¿La última transacción es de cargo?
      bool isCargo = lastTransaction != null &&
          lastTransaction['nombre'].toString().toLowerCase().contains('cargo');

      // ¿Podemos reimprimir? — Siempre para cargo, o solo una vez para otros
      bool canReprint =
          lastTransaction != null && !isReprinting && (isCargo || !hasReprinted);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: canReprint ? Color(0xFFFFD71F) : Colors.white,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: canReprint ? onHandleReprint : null,
              child: Center(
                child: Image.asset(
                  'assets/reprint.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Settings button
    else if (elementKey == 'settings') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF00910B),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: onNavigateToSettings,
              child: Center(
                child: Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Date display
    else if (elementKey == 'date') {
      return Padding(
        padding: const EdgeInsets.only(right: 5.0, left: 3.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                getCurrentDate(),
                style: TextStyle(
                    color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                currentDay,
                style: TextStyle(
                    color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // Mail button (for cargo) with status indicator for pending days
    else if (elementKey == 'mail') {
      return Consumer<ReporteCaja>(
        builder: (context, reporteCaja, child) {
          bool hasPendingDays = reporteCaja.hasPendingOldTransactions();

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purple,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(21),
                      onTap: onShowOfferDialog,
                      child: Center(
                        child: Icon(
                          Icons.mail,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Indicator for pending days
              if (hasPendingDays)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    // Default empty widget for unknown elements
    return Container();
  }

  /// Obtiene un icono desde su nombre string
  static IconData getIconFromString(String iconName) {
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
}
