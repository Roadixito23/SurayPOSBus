import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'database/database_helper.dart';
import 'services/pdf/pdf_resource_manager.dart';
import 'services/pdf/pdf_optimizer.dart';
import 'models/ComprobanteModel.dart';
import 'models/ReporteCaja.dart';
import 'models/ticket_model.dart';
import 'models/sunday_ticket_model.dart';
import 'providers/sumup_result_notifier.dart';
import 'services/pago_storage_service.dart';
import 'screens/login_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Precalentar la BD para que esté lista antes de que cualquier pantalla la necesite
  unawaited(DatabaseHelper.instance.database);

  // Start resource preloading in background
  unawaited(_preloadPdfResources());

  // Limpiar pagos con tarjeta de días anteriores
  unawaited(PagoStorageService.limpiarPagosAnteriores());

  // Crear el notifier de resultado SumUp
  final sumUpResultNotifier = SumUpResultNotifier();

  // Inicializar AppLinks para recibir el callback de SumUp
  final appLinks = AppLinks();

  // Manejar deep link que abrió/resumió la app (initial/cold start)
  try {
    final initialUri = await appLinks.getInitialAppLink();
    if (initialUri != null &&
        initialUri.scheme == 'posbus' &&
        initialUri.host == 'sumup-result') {
      final status = initialUri.queryParameters['smp-status'];
      final txCode = initialUri.queryParameters['smp-tx-code'] ?? '';
      final monto = initialUri.queryParameters['smp-amount'] ?? '';
      final exitoso = status == 'success';
      // Pequeño delay para que el listener en Home se registre primero
      Future.delayed(Duration(milliseconds: 500), () {
        sumUpResultNotifier.setResultado(exitoso, txCode, monto);
      });
    }
  } catch (e) {
    print('Error obteniendo initial link: $e');
  }

  // Manejar deep links mientras la app está viva en background (warm resume)
  appLinks.uriLinkStream.listen((Uri uri) {
    if (uri.scheme == 'posbus' && uri.host == 'sumup-result') {
      final status = uri.queryParameters['smp-status'];
      final txCode = uri.queryParameters['smp-tx-code'] ?? '';
      final monto = uri.queryParameters['smp-amount'] ?? '';
      final exitoso = status == 'success';
      sumUpResultNotifier.setResultado(exitoso, txCode, monto);
    }
  });

  // Run the app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ComprobanteModel()),
        ChangeNotifierProvider(create: (context) => ReporteCaja()),
        ChangeNotifierProvider(create: (context) => TicketModel()),
        ChangeNotifierProvider(create: (context) => SundayTicketModel()),
        ChangeNotifierProvider.value(value: sumUpResultNotifier),
      ],
      child: MyApp(),
    ),
  );
}

// Preload PDF resources in background
Future<void> _preloadPdfResources() async {
  try {
    print('Main: Starting background PDF resource initialization');

    // Initialize the resource manager
    final resourceManager = PdfResourceManager();
    await resourceManager.initialize();

    // Initialize the PDF optimizer
    final pdfOptimizer = PdfOptimizer();
    await pdfOptimizer.preloadResources();

    print('Main: Background PDF resource initialization complete');
  } catch (e) {
    print('Main: Error preloading PDF resources: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V25.05.26',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Helper for fire-and-forget Futures
void unawaited(Future<void> future) {
  // Explicitly ignore the result of the future
  future.then((_) {
    // Do nothing on completion
  }).catchError((error) {
    // Log errors, don't crash
    print('Unawaited Future error: $error');
  });
}
