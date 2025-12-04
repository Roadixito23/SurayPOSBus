import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ComprobanteModel.dart';
import 'pdf_optimizer.dart';

class MoTicketGenerator {
  // Use our optimizer
  final PdfOptimizer _optimizer = PdfOptimizer();
  bool _resourcesLoaded = false;

  // Preload resources method
  Future<void> _ensureResourcesLoaded() async {
    if (!_resourcesLoaded) {
      await _optimizer.preloadResources();
      _resourcesLoaded = true;
    }
  }

  Future<void> preloadResources() async {
    await _ensureResourcesLoaded();
  }

  Future<void> generateMoTicket(
      PdfPageFormat format,
      List<Map<String, dynamic>> offerEntries,
      bool isSwitchOn,
      BuildContext context,
      Function(String, double, List<double>, String) onGenerateComplete) async {

    final comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);

    // Preload PDF resources
    await _ensureResourcesLoaded();

    // Incrementar y obtener el número de comprobante antes de crear el PDF
    await comprobanteModel.incrementComprobante();
    String comprobante = comprobanteModel.formattedComprobante;

    // Calcular subtotales y total
    double total = 0.0;
    List<double> subtotals = [];

    // Simplified calculation
    for (var entry in offerEntries) {
      int quantity = int.tryParse(entry['number'] ?? '0') ?? 0;
      double price = double.tryParse(entry['value'] ?? '0.0') ?? 0.0;
      double subtotal = quantity * price;

      total += subtotal;
      subtotals.add(subtotal);
    }

    try {
      // Crear y guardar el PDF
      final Uint8List pdfData = await _generateTicketPdf(
          offerEntries,
          comprobante,
          isSwitchOn,
          false, // No es reimpresión
          subtotals,
          total
      );

      // Imprimir el PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        format: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity), // Usar formato de 58mm
      );

      // Guardar el número de comprobante en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('comprobanteNumber', comprobanteModel.comprobanteNumber);

      // Llamar al callback con los datos relevantes
      onGenerateComplete('Oferta Ruta', total, subtotals, comprobante);

    } catch (e) {
      print('Error generating MO ticket: $e');
      // Clear resources on error
      _optimizer.clearCache();
      throw e;
    }
  }

  // Método de reimpresión mejorado
  Future<void> reprintMoTicket(
      PdfPageFormat format,
      List<Map<String, dynamic>> offerEntries,
      bool isSwitchOn,
      BuildContext context,
      String comprobante) async {

    // Preload PDF resources
    await _ensureResourcesLoaded();

    try {
      // Calcular subtotales y total (simplified)
      double total = 0.0;
      List<double> subtotals = [];

      for (var entry in offerEntries) {
        int quantity = int.tryParse(entry['number'] ?? '0') ?? 0;
        double price = double.tryParse(entry['value'] ?? '0.0') ?? 0.0;
        double subtotal = quantity * price;

        total += subtotal;
        subtotals.add(subtotal);
      }

      // Generate PDF for reprint
      final Uint8List pdfData = await _generateTicketPdf(
          offerEntries,
          comprobante,
          isSwitchOn,
          true, // Es reimpresión
          subtotals,
          total
      );

      // Print it
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        format: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity), // Usar formato de 58mm
      );

    } catch (e) {
      print('Error en reprintMoTicket: $e');
      // Clear resources on error
      _optimizer.clearCache();
      throw e;
    }
  }

  // Método común para generar el PDF (usado tanto para impresión original como reimpresión)
  Future<Uint8List> _generateTicketPdf(
      List<Map<String, dynamic>> offerEntries,
      String comprobante,
      bool isSwitchOn,
      bool isReprint,
      List<double> subtotals,
      double total) async {

    // Use our optimized document
    final doc = _optimizer.createDocument();
    final pdfWidth = 58 * PdfPageFormat.mm;

    // Obtener la fecha y hora actual
    String currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String currentTime = DateFormat('HH:mm:ss').format(DateTime.now());

    // Use NumberFormat just once
    final formatter = NumberFormat('#,##0', 'es_CL');
    final formattedTotal = formatter.format(total);

    // Crear la página del PDF
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pdfWidth, double.infinity),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header idéntico a generateTicket
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: pdfWidth * 0.4,
                    child: pw.Image(_optimizer.getLogoImage()),
                  ),
                  pw.Spacer(),
                  pw.Container(
                    width: pdfWidth * 0.5,
                    padding: pw.EdgeInsets.all(2),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text('COMPROBANTE DE',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text('PAGO EN BUS',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text('N° $comprobante',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 5),

              // Reimpresión indicador
              if (isReprint)
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(vertical: 2, horizontal: 5),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                      color: PdfColors.grey200),
                  child: pw.Text('REIMPRESIÓN',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
              // Título de la oferta
              pw.Text('Oferta en Ruta',
                  style: pw.TextStyle(fontSize: 12)),

              pw.SizedBox(height: 5),

              // Tabla simplificada de ofertas con estilo similar - MODIFICADO
              pw.Center(  // Añadir Center aquí
                child: pw.Container(
                  width: pdfWidth * 0.9,  // Opcional: controlar el ancho de la tabla
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Table(
                    border: pw.TableBorder.all(width: 0.5),
                    columnWidths: {
                      0: pw.FlexColumnWidth(1), // Cantidad
                      1: pw.FlexColumnWidth(2), // Precio unitario
                    },
                    children: [
                      // Encabezados
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(
                            padding: pw.EdgeInsets.all(3),
                            child: pw.Text(
                              'Cant. Pax.',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(3),
                            child: pw.Text(
                              'Precio Unitario',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      // Filas de datos
                      ...offerEntries.map((entry) {
                        final qty = int.tryParse(entry['number']?.toString() ?? '') ?? 0;
                        final price = double.tryParse(entry['value']?.toString() ?? '') ?? 0.0;

                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: pw.EdgeInsets.all(3),
                              child: pw.Text(
                                qty.toString(),
                                style: pw.TextStyle(fontSize: 9),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(3),
                              child: pw.Text(
                                '\$${formatter.format(price)}',
                                style: pw.TextStyle(fontSize: 9),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 5),

              // Total en recuadro similar a generateTicket
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Text('Total: \$$formattedTotal',
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              ),

              pw.SizedBox(height: 5),

              // Contenedor para alinear textos igual que generateTicket
              pw.Container(
                width: pdfWidth - 10,
                padding: pw.EdgeInsets.symmetric(horizontal: 5),
                child: pw.Column(
                  children: [
                    // Texto "Válido hora y fecha señalada"
                    pw.Center(
                      child: pw.Text(
                        'Válido hora y fecha señalada',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    // Hora y fecha sin prefijos, alineados a los extremos
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          currentTime,
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          currentDate,
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Reimpresión fecha si aplica
              if (isReprint)
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: 5),
                  child: pw.Text(
                      'Reimpreso: $currentDate $currentTime',
                      style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                ),

              // Imagen final
              pw.Image(_optimizer.getEndImage()),
            ],
          );
        },
      ),
    );

    // Save and return the PDF
    return await doc.save();
  }
}