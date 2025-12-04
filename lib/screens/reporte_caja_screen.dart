import 'package:flutter/material.dart';
import 'package:printing/printing.dart' as printing;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ReporteCaja.dart';
import '../services/pdf/pdfReport_generator.dart';
import '../services/pdf/pdf_optimizer.dart';
import '../theme/app_theme.dart';
import '../theme/app_animations.dart';
import '../services/report/report_cleaner.dart';
import 'reporte_recovery.dart'; // Import for navigation

class ReporteCajaScreen extends StatefulWidget {
  @override
  _ReporteCajaScreenState createState() => _ReporteCajaScreenState();
}

class _ReporteCajaScreenState extends State<ReporteCajaScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  String _statusMessage = '';
  bool _showAdminOptions = false;
  final TextEditingController _adminPasswordController = TextEditingController();
  final PdfOptimizer pdfOptimizer = PdfOptimizer();

  // Controladores para animaciones
  late AnimationController _fadeController;
  late AnimationController _staggeredController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    // Inicializar controladores de animación
    _fadeController = AnimationController(
      vsync: this,
      duration: AppTheme.animationDuration,
    );

    _staggeredController = AnimationController(
      vsync: this,
      duration: AppTheme.longAnimationDuration,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    // Iniciar las animaciones
    _fadeController.forward();
    _staggeredController.forward();

    // Iniciar la precarga de recursos del PDF
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadPdfResources();
    });
  }

  @override
  void dispose() {
    _adminPasswordController.dispose();
    _fadeController.dispose();
    _staggeredController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // Método para precargar recursos de PDF
  Future<void> _preloadPdfResources() async {
    try {
      await pdfOptimizer.preloadResources();
    } catch (e) {
      print('Error en precarga de recursos: $e');
    }
  }

  // Method to generate the report
  Future<void> _generateReport(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generando reporte...';
    });

    try {
      final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);

      // Validate if there are transactions
      if (!reporteCaja.hasActiveTransactions()) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'No hay transacciones para generar reporte';
        });
        _showSnackBar('No hay transacciones para generar reporte', Colors.orange);
        return;
      }

      // Generate the report using PdfReportGenerator
      final generator = PdfReportGenerator();
      final transactions = reporteCaja.getOrderedTransactions();
      final total = reporteCaja.getTotal();
      final reportDate = DateTime.now();

      // Generate the PDF and get the document (assuming it returns Uint8List now)
      final pdfBytes = await generator.generatePdf(transactions, total, reportDate);

      // Use the printing library with the bytes directly
      await printing.Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Reporte_Caja_${DateFormat('dd-MM-yyyy_HHmm').format(reportDate)}',
      );

      // Clear transactions after successful printing
      reporteCaja.clearTransactions();

      setState(() {
        _isLoading = false;
        _statusMessage = 'Reporte generado e impreso correctamente';
      });

      _showSnackBar('Reporte generado e impreso correctamente', AppTheme.turquoise);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al generar reporte: $e';
      });

      _showSnackBar('Error al generar reporte: $e', AppTheme.coral);
    }
  }

  // Método para mostrar SnackBar con estilo personalizado
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontFamily: AppTheme.fontDefault,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(8),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // NUEVO MÉTODO: Para cerrar forzadamente las cajas pendientes
  Future<void> _forceCloseOldTransactions() async {
    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);

    // Verificar si hay transacciones para cerrar
    final today = DateTime.now();
    final todayDay = DateFormat('dd').format(today);
    final todayMonth = DateFormat('MM').format(today);
    final todayYear = today.year.toString();

    // Filtrar transacciones de días anteriores
    final oldTransactions = reporteCaja.getOrderedTransactions().where((t) {
      // Verificar si la transacción no es una anulación
      if (t['nombre'].toString().startsWith('Anulación:')) {
        return false;
      }

      // Obtener fecha de la transacción
      final transDay = t['dia'];
      final transMonth = t['mes'];
      final transYear = t['ano'] ?? todayYear; // Usar año actual si no está definido

      // Determinar si la transacción es de un día anterior
      if (transYear < todayYear) {
        return true; // Año anterior
      } else if (transYear == todayYear) {
        if (transMonth < todayMonth) {
          return true; // Mes anterior en el mismo año
        } else if (transMonth == todayMonth && transDay < todayDay) {
          return true; // Día anterior en el mismo mes
        }
      }

      return false;
    }).toList();

    if (oldTransactions.isEmpty) {
      _showSnackBar('No hay transacciones antiguas pendientes', Colors.blue);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Cerrando transacciones antiguas...';
    });

    try {
      // Agrupar transacciones por día para generar reportes separados
      Map<String, List<Map<String, dynamic>>> transactionsByDate = {};

      for (var transaction in oldTransactions) {
        final day = transaction['dia'];
        final month = transaction['mes'];
        final year = transaction['ano'] ?? todayYear;
        final dateKey = '$year-$month-$day';

        if (!transactionsByDate.containsKey(dateKey)) {
          transactionsByDate[dateKey] = [];
        }

        transactionsByDate[dateKey]!.add(transaction);
      }

      // Generar un reporte para cada día
      final generator = PdfReportGenerator();

      for (var entry in transactionsByDate.entries) {
        final transactions = entry.value;
        final dateKey = entry.key.split('-');

        // Crear fecha para el reporte
        final reportDate = DateTime(
          int.parse(dateKey[0]),
          int.parse(dateKey[1]),
          int.parse(dateKey[2]),
        );

        // Calcular total para estas transacciones
        final total = transactions.fold(0.0, (sum, t) => sum + (t['valor'] ?? 0.0));

        // Generar PDF para este día
        await generator.generatePdf(transactions, total, reportDate);

        // Eliminar estas transacciones de la lista del ReporteCaja
        for (var transaction in transactions) {
          reporteCaja.removeTransaction(transaction['id']);
        }
      }

      setState(() {
        _isLoading = false;
        _statusMessage = 'Cajas antiguas cerradas correctamente';
      });

      _showSnackBar(
          'Se han cerrado ${transactionsByDate.length} cajas pendientes',
          AppTheme.turquoise
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al cerrar cajas antiguas: $e';
      });

      _showSnackBar('Error al cerrar cajas antiguas: $e', AppTheme.coral);
    }
  }

  // NUEVO MÉTODO: Para limpiar reportes antiguos manualmente
  Future<void> _cleanOldReportsManually() async {
    // Mostrar diálogo de confirmación
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Limpieza', style: AppTheme.subtitleLarge),
        content: Text(
          '¿Está seguro de que desea eliminar los reportes con más de 30 días? Esta acción no se puede deshacer.',
          style: AppTheme.bodyMedium,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: Text('Confirmar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coral,
            ),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Limpiando reportes antiguos...';
    });

    try {
      int cleanedCount = await ReportCleaner.cleanExpiredReportsOnStartup(30); // Mantener reportes hasta 30 días

      setState(() {
        _isLoading = false;
        _statusMessage = 'Reportes antiguos limpiados correctamente';
      });

      if (cleanedCount > 0) {
        _showSnackBar('Se eliminaron $cleanedCount reportes antiguos', AppTheme.turquoise);
      } else {
        _showSnackBar('No se encontraron reportes antiguos para eliminar', Colors.blue);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al limpiar reportes antiguos: $e';
      });

      _showSnackBar('Error al limpiar reportes antiguos: $e', AppTheme.coral);
    }
  }

  // Método para mostrar diálogo de autenticación de administrador
  Future<void> _showAdminAuthDialog() async {
    // Reiniciar el controlador de texto
    _adminPasswordController.clear();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Acceso Administrador',
            style: TextStyle(
              fontFamily: AppTheme.fontHemiheads,
              color: AppTheme.turquoiseDark,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingrese la contraseña de administrador para acceder a funciones avanzadas',
                style: AppTheme.bodyMedium,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _adminPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.turquoise),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.turquoiseDark, width: 2),
                  ),
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.turquoise),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Verificar contraseña
                final prefs = await SharedPreferences.getInstance();
                final adminPass = prefs.getString('password') ?? '232323';

                if (_adminPasswordController.text == adminPass) {
                  Navigator.of(context).pop();
                  setState(() {
                    _showAdminOptions = true;
                  });
                } else {
                  Navigator.of(context).pop();
                  _showSnackBar('Contraseña incorrecta', AppTheme.coral);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.turquoise,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Acceder'),
            ),
          ],
        );
      },
    );
  }

  // Método para navegar a la pantalla de reportes antiguos
  void _navigateToOldReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecoveryReport()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reporteCaja = Provider.of<ReporteCaja>(context);
    final transactions = reporteCaja.getOrderedTransactions();
    final total = reporteCaja.getTotal();

    // Alerta si hay transacciones antiguas pendientes
    final hasOldTransactions = reporteCaja.hasPendingOldTransactions();
    final oldestPendingDays = reporteCaja.getOldestPendingDays();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Reporte de Caja',
              style: TextStyle(
                fontFamily: AppTheme.fontHemiheads,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.turquoise,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
          // Nuevo botón para navegar a reportes antiguos
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _navigateToOldReports,
            tooltip: 'Reportes Antiguos',
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: AppTheme.gradientBackground,
            child: RefreshIndicator(
              onRefresh: () async {
                // Simplemente actualiza la vista
                setState(() {});
              },
              color: AppTheme.turquoise,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Alerta de transacciones antiguas pendientes
                    if (hasOldTransactions)
                      FadeTransition(
                        opacity: _fadeController,
                        child: AppAnimations.pulse(
                          controller: _pulseController,
                          child: Card(
                            color: AppTheme.coralLight.withOpacity(0.8),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cajas pendientes de cierre',
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontHemiheads,
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Hay transacciones con $oldestPendingDays días de antigüedad que requieren cierre.',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.arrow_forward, color: Colors.white),
                                    onPressed: _showAdminOptions ? _forceCloseOldTransactions : _showAdminAuthDialog,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (hasOldTransactions)
                      SizedBox(height: 16),

                    // Sección de Admin (visible solo con autenticación)
                    if (_showAdminOptions)
                      AnimatedBuilder(
                        animation: _staggeredController,
                        builder: (context, child) {
                          return AppAnimations.fadeInUp(
                            animation: _staggeredController,
                            child: child!,
                          );
                        },
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings, color: AppTheme.turquoiseDark),
                                    SizedBox(width: 8),
                                    Text(
                                      'Opciones de Administrador',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontHemiheads,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.turquoiseDark,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Utilice estas funciones con precaución:',
                                  style: TextStyle(
                                    color: AppTheme.turquoiseDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: Icon(Icons.warning_amber_rounded),
                                  label: Text('Cerrar Cajas Pendientes'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.coral,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _forceCloseOldTransactions,
                                ),
                                SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: Icon(Icons.cleaning_services),
                                  label: Text('Limpiar Reportes Antiguos'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.turquoise,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _cleanOldReportsManually,
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: Icon(Icons.logout),
                                      label: Text('Salir de Administrador'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey[700],
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showAdminOptions = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    if (_showAdminOptions)
                      SizedBox(height: 16),

                    SizedBox(height: 16),

                    // Información del Reporte
                    AnimatedBuilder(
                      animation: _staggeredController,
                      builder: (context, child) {
                        return AppAnimations.fadeInUp(
                          animation: _staggeredController,
                          yOffset: 40.0,
                          child: child!,
                        );
                      },
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Información del Reporte',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontHemiheads,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.turquoiseDark,
                                ),
                              ),
                              SizedBox(height: 8),
                              Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total de Transacciones:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.turquoiseLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${transactions.length}',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontHemiheads,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.turquoiseDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontHemiheads,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppTheme.turquoiseDark,
                                    ),
                                  ),
                                  Text(
                                    '\$${NumberFormat('#,##0', 'es_ES').format(total)}',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontHemiheads,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: AppTheme.coral,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: Icon(Icons.print),
                                label: Text(
                                  'Cerrar Caja e Imprimir',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontHemiheads,
                                    fontSize: 18,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: transactions.isEmpty ? Colors.grey : AppTheme.turquoise,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: transactions.isEmpty
                                    ? null
                                    : () => _generateReport(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Lista de Transacciones
                    AnimatedBuilder(
                      animation: _staggeredController,
                      builder: (context, child) {
                        return AppAnimations.fadeInUp(
                          animation: _staggeredController,
                          yOffset: 50.0,
                          child: child!,
                        );
                      },
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.receipt, color: AppTheme.turquoiseDark),
                                  SizedBox(width: 8),
                                  Text(
                                    'Transacciones',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontHemiheads,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.turquoiseDark,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Divider(),
                              if (transactions.isEmpty)
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 30),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.receipt_long,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No hay transacciones registradas',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: transactions.length,
                                  itemBuilder: (context, index) {
                                    final transaction = transactions[index];
                                    final bool isAnulacion = transaction['nombre'].toString().startsWith('Anulación:');

                                    // Verificar si es una transacción de día anterior
                                    final today = DateTime.now();
                                    final todayDay = DateFormat('dd').format(today);
                                    final todayMonth = DateFormat('MM').format(today);

                                    final transDay = transaction['dia'];
                                    final transMonth = transaction['mes'];
                                    final isPastDay = transDay != todayDay || transMonth != todayMonth;

                                    Color cardColor = Colors.white;
                                    Color borderColor = Colors.grey.shade300;
                                    Color iconColor = AppTheme.turquoise;
                                    IconData iconData = Icons.receipt;

                                    if (isPastDay) {
                                      cardColor = AppTheme.coralLight.withOpacity(0.2);
                                      borderColor = AppTheme.coral;
                                      iconColor = AppTheme.coral;
                                      iconData = Icons.warning_amber_rounded;
                                    } else if (isAnulacion) {
                                      cardColor = Colors.red.shade50;
                                      borderColor = Colors.red.shade300;
                                      iconColor = Colors.red;
                                      iconData = Icons.do_disturb;
                                    }

                                    return AnimatedBuilder(
                                      animation: _staggeredController,
                                      builder: (context, child) {
                                        final int staggeredIndex = index % 10; // Repetir animación cada 10 elementos
                                        final double interval = 0.05 * staggeredIndex;

                                        final Animation<double> animation = CurvedAnimation(
                                          parent: _staggeredController,
                                          curve: Interval(
                                            0.5 + interval, // Empezar después de que las tarjetas principales aparezcan
                                            1.0,
                                            curve: Curves.easeOutQuart,
                                          ),
                                        );

                                        return AppAnimations.fadeInRight(
                                          animation: animation,
                                          child: child!,
                                        );
                                      },
                                      child: Card(
                                        elevation: 2,
                                        margin: EdgeInsets.symmetric(vertical: 6),
                                        color: cardColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: borderColor,
                                            width: 1,
                                          ),
                                        ),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          leading: CircleAvatar(
                                            backgroundColor: iconColor,
                                            child: Icon(
                                              iconData,
                                              color: Colors.white,
                                            ),
                                          ),
                                          title: Text(
                                            transaction['nombre'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isPastDay ? AppTheme.coral : null,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.receipt_long,
                                                    size: 14,
                                                    color: Colors.grey,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    '${transaction['comprobante'] ?? 'N/A'}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 14,
                                                    color: isPastDay ? AppTheme.coral : Colors.grey,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    '${transaction['dia']}/${transaction['mes']} - ${transaction['hora']}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontStyle: isPastDay ? FontStyle.italic : null,
                                                      color: isPastDay ? AppTheme.coral : null,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          trailing: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isAnulacion
                                                  ? Colors.red.shade100
                                                  : AppTheme.turquoiseLight,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '\$${NumberFormat('#,##0', 'es_ES').format(transaction['valor'])}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isAnulacion ? Colors.red : AppTheme.turquoiseDark,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // Indicador de carga
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.turquoise),
                        ),
                        SizedBox(height: 20),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontFamily: AppTheme.fontHemiheads,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}