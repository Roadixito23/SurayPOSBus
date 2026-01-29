import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/ReporteCaja.dart';

class TransactionCounterWidget extends StatelessWidget {
  const TransactionCounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF1900A2),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(13),
                      bottomLeft: Radius.circular(13),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFFF0C00),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(13),
                      bottomRight: Radius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Contador de transacciones (lado izquierdo - azul)
          Positioned(
            left: 13,
            child: Consumer<ReporteCaja>(
              builder: (context, reporteCaja, child) {
                DateTime today = DateTime.now();
                String todayDay = DateFormat('dd').format(today);
                String todayMonth = DateFormat('MM').format(today);

                var allTransactions = reporteCaja.getOrderedTransactions();
                var todayTransactions = allTransactions.where((t) =>
                    t['dia'] == todayDay && t['mes'] == todayMonth &&
                        !t['nombre'].toString().startsWith('Anulación:')
                ).toList();

                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    '${todayTransactions.length}',
                    key: ValueKey<int>(todayTransactions.length),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 23,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          // Contador de anulaciones (lado derecho - rojo)
          Positioned(
            right: 13,
            child: Consumer<ReporteCaja>(
              builder: (context, reporteCaja, child) {
                DateTime today = DateTime.now();
                String todayDay = DateFormat('dd').format(today);
                String todayMonth = DateFormat('MM').format(today);

                var allTransactions = reporteCaja.getOrderedTransactions();
                var todayAnulaciones = allTransactions.where((t) =>
                    t['dia'] == todayDay && t['mes'] == todayMonth &&
                        t['nombre'].toString().startsWith('Anulación:')
                ).toList();

                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    '${todayAnulaciones.length}',
                    key: ValueKey<int>(todayAnulaciones.length),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 23,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          // Contador neto central (círculo verde)
          Consumer<ReporteCaja>(
            builder: (context, reporteCaja, child) {
              DateTime today = DateTime.now();
              String todayDay = DateFormat('dd').format(today);
              String todayMonth = DateFormat('MM').format(today);

              var allTransactions = reporteCaja.getOrderedTransactions();
              var todayTransactions = allTransactions.where((t) =>
                  t['dia'] == todayDay && t['mes'] == todayMonth &&
                      !t['nombre'].toString().startsWith('Anulación:')
              ).toList();

              var todayAnulaciones = allTransactions.where((t) =>
                  t['dia'] == todayDay && t['mes'] == todayMonth &&
                      t['nombre'].toString().startsWith('Anulación:')
              ).toList();

              int netCount = todayTransactions.length - todayAnulaciones.length;

              return AnimatedContainer(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 3,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      '$netCount',
                      key: ValueKey<int>(netCount),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
