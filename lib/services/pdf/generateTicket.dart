import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../models/ComprobanteModel.dart';
import 'pdf_optimizer.dart';

class GenerateTicket {
  final PdfOptimizer optimizer = PdfOptimizer();
  bool resourcesPreloaded = false;

  Future<void> preloadResources() async {
    if (resourcesPreloaded) return;
    await optimizer.preloadResources();
    resourcesPreloaded = true;
  }

  Future<void> generateTicketPdf(BuildContext context,
      double valor,
      bool isSunday,
      String tipo,
      ComprobanteModel comprobanteModel,
      bool isReprint,) async {
    await preloadResources();

    if (!isReprint) {
      await comprobanteModel.incrementComprobante();
    }

    final ticketId = comprobanteModel.formattedComprobante;
    final priceFmt = NumberFormat('#,###', 'es_CL');
    final formattedValor = priceFmt.format(valor);
    final now = DateTime.now();

    final pdfWidth = 58 * PdfPageFormat.mm;

    final doc = optimizer.createDocument();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(pdfWidth, double.infinity),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: pdfWidth * 0.4,
                  child: pw.Image(optimizer.getLogoImage()),
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
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw
                              .FontWeight.bold)),
                      pw.Text('PAGO EN BUS',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw
                              .FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('N° $ticketId',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw
                              .FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            if (isReprint)
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 2, horizontal: 5),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(), color: PdfColors.grey200),
                child: pw.Text('REIMPRESIÓN', style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
            pw.Text(
                isSunday ? 'TARIFA DOMINGO/FERIADO' : 'TARIFA LUNES A SÁBADO',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)
            ),
            pw.Text(tipo, style: pw.TextStyle(fontSize: 12,)),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Text('Valor: \$$formattedValor', style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 5),
            // Contenedor para alinear ambos textos
            pw.Container(
              width: pdfWidth - 10, // Ancho fijo con margen simétrico
              padding: pw.EdgeInsets.symmetric(horizontal: 5),
              child: pw.Column(
                children: [
                  // Texto "Válido hora y fecha señalada"
                  pw.Center(
                    child: pw.Text(
                      'Válido hora y fecha señaladas',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  // Hora y fecha
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        DateFormat('HH:mm:ss').format(now),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw
                            .FontWeight.bold),
                      ),
                      pw.Text(
                        DateFormat('dd/MM/yyyy').format(now),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw
                            .FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isReprint)
              pw.Padding(
                padding: pw.EdgeInsets.only(top: 5),
                child: pw.Text(
                    'Reimpreso: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(
                        now)}',
                    style: pw.TextStyle(
                        fontSize: 8, fontStyle: pw.FontStyle.italic)),
              ),
            pw.Image(optimizer.getEndImage()),
          ],
        );
      },
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      format: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
    );
  }
}
