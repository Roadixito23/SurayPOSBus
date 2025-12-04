import 'package:flutter/material.dart';

/// Diálogo para mostrar opciones de reimpresión
Future<void> showReprintOptionsDialog(
  BuildContext context,
  Map<String, dynamic>? lastTransaction,
  bool hasReprinted,
  VoidCallback onReprintLastTransaction,
) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.print, color: Colors.yellow.shade600, size: 32),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Opciones de Reimpresión',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lastTransaction != null && !hasReprinted)
                ListTile(
                  leading: Icon(Icons.receipt_long, color: Colors.blue, size: 28),
                  title: Text(
                    'Reimprimir última transacción',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(lastTransaction['nombre'] ?? 'Transacción'),
                  trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
                  onTap: () {
                    Navigator.of(context).pop();
                    onReprintLastTransaction();
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      );
    },
  );
}

/// Diálogo para mostrar opciones de cargo para reimprimir
Future<void> showLastCargoReprintOptions(
  BuildContext context,
  Map<String, dynamic>? lastTransaction,
  Function(bool printClient, bool printCargo) onReprintCargo,
) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.inventory,
              color: Colors.orange,
              size: 28,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text('Reimprimir Último Cargo', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Información del cargo
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalles del Cargo:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Destinatario: ${lastTransaction?['destinatario'] ?? 'No disponible'}'),
                    Text('Comprobante: ${lastTransaction?['comprobante'] ?? 'No disponible'}'),
                  ],
                ),
              ),
              SizedBox(height: 15),
              Text(
                '¿Qué boleta desea reimprimir?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
        actions: [
          // Fila de botones en dos columnas
          Container(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primera fila: Cliente y Carga
                Row(
                  children: [
                    // Botón Cliente (Azul)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.person, color: Colors.white),
                          label: Text(
                            'Cliente',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            onReprintCargo(true, false);
                          },
                        ),
                      ),
                    ),

                    // Botón Carga (Verde)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.local_shipping, color: Colors.white),
                          label: Text(
                            'Carga',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            onReprintCargo(false, true);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Segunda fila: Ambas y Cancelar
                Row(
                  children: [
                    // Botón Ambas (Naranja)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4.0, top: 4.0),
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.print, color: Colors.white),
                          label: Text(
                            'Ambas',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            onReprintCargo(true, true);
                          },
                        ),
                      ),
                    ),

                    // Botón Cancelar (Gris)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4.0, top: 4.0),
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.cancel, color: Colors.white),
                          label: Text(
                            'Cancelar',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// Widget auxiliar para construir filas de detalles de cargo
Widget buildCargoDetailRow(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 35,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ),
      Expanded(
        flex: 65,
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}
