import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/ComprobanteModel.dart';
import '../../models/ReporteCaja.dart';
import '../pdf/pdf_optimizer.dart';
import '../pdf/generateTicket.dart';
import '../pdf/generateCargo_Ticket.dart';

/// Servicio para precargar recursos PDF en segundo plano
class ResourcePreloader {
  bool _resourcesPreloaded = false;

  final PdfOptimizer pdfOptimizer;
  final GenerateTicket generateTicket;

  ResourcePreloader({
    required this.pdfOptimizer,
    required this.generateTicket,
  });

  /// Verifica si los recursos ya están precargados
  bool get resourcesPreloaded => _resourcesPreloaded;

  /// Precarga recursos de manera asíncrona sin bloquear la UI
  Future<void> preloadPdfResourcesAsync(
    BuildContext context,
    ComprobanteModel comprobanteModel,
    ReporteCaja reporteCaja,
  ) async {
    if (_resourcesPreloaded) return; // Evitar cargar múltiples veces

    print('Iniciando precarga de recursos en segundo plano...');

    // Crear completer para rastrear el progreso
    final completer = Completer<void>();

    // Ejecutar en un microtask para evitar bloquear la UI
    Future.microtask(() async {
      try {
        // Precargar los recursos del PDF
        await pdfOptimizer.preloadResources();
        await generateTicket.preloadResources();

        // Precargar recursos para tickets de cargo si están disponibles
        try {
          final cargoGen = CargoTicketGenerator(comprobanteModel, reporteCaja);
          await cargoGen.preloadResources();
        } catch (e) {
          // Si hay un error al precargar recursos de cargo, no afecta la funcionalidad principal
          print('Advertencia: No se pudieron precargar recursos de cargo: $e');
        }

        // Marcar como completado
        _resourcesPreloaded = true;

        completer.complete();
        print('Precarga de recursos completada con éxito');
      } catch (e) {
        completer.completeError(e);
        print('Error durante la precarga de recursos: $e');
      }
    });

    return completer.future;
  }

  /// Verifica primero si ya está cargado y carga si es necesario
  Future<void> preloadPdfResources(
    BuildContext context,
    ComprobanteModel comprobanteModel,
    ReporteCaja reporteCaja,
  ) async {
    if (_resourcesPreloaded) {
      print('Recursos ya precargados, no es necesario cargar nuevamente');
      return;
    }

    // Si no está precargado, intentar cargar normalmente
    try {
      await preloadPdfResourcesAsync(context, comprobanteModel, reporteCaja);
    } catch (e) {
      print('Error al cargar recursos: $e');
      // Intentaremos nuevamente cuando sea necesario
      _resourcesPreloaded = false;
    }
  }

  /// Limpia la caché de recursos cuando sea necesario
  void clearCacheIfNeeded() {
    print('Liberando memoria para PDF...');
    pdfOptimizer.clearCache();
    _resourcesPreloaded = false;

    // También podemos liberar otras cachés si es necesario
    if (generateTicket.resourcesPreloaded) {
      generateTicket.optimizer.clearCache();
      generateTicket.resourcesPreloaded = false;
    }
  }
}
