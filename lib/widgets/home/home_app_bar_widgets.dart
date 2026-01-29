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
      return Padding(
        padding: EdgeInsets.only(left: 8 + leftMargin, right: 3),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4F8FC0), // primary
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ReporteCajaScreen()),
                );
              },
              child: Center(
                child: Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canAnular ? Color(0xFFE57373) : Colors.grey.shade300,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: canAnular ? onShowPasswordDialog : null,
                  child: Center(
                    child: Icon(
                      Icons.delete,
                      color: canAnular ? Colors.white : Colors.grey.shade600,
                      size: 22,
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
      bool isCargo = lastTransaction != null &&
          lastTransaction['nombre'].toString().toLowerCase().contains('cargo');
      bool canReprint =
          lastTransaction != null && !isReprinting && (isCargo || !hasReprinted);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: canReprint ? Color(0xFFF2C94C) : Colors.grey.shade300,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: canReprint ? onHandleReprint : null,
              child: Center(
                child: Icon(
                  Icons.print,
                  color: canReprint ? Colors.white : Colors.grey.shade600,
                  size: 22,
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF6FCF97), // secondary
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onNavigateToSettings,
              child: Center(
                child: Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 22,
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purple,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onShowOfferDialog,
                      child: Center(
                        child: Icon(
                          Icons.mail,
                          color: Colors.white,
                          size: 22,
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
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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
