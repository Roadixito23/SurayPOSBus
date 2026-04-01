import 'package:flutter/material.dart';
import 'package:printing/printing.dart' as printing;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/ReporteCaja.dart';
import '../services/pdf/pdfReport_generator.dart';
import '../services/pdf/pdf_optimizer.dart';
import '../services/pago_storage_service.dart';
import '../theme/app_theme.dart';
import 'reporte_recovery.dart'; // Import for navigation

class ReporteCajaScreen extends StatefulWidget {
  const ReporteCajaScreen({super.key});

  @override
  _ReporteCajaScreenState createState() => _ReporteCajaScreenState();
}

class _ReporteCajaScreenState extends State<ReporteCajaScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  String _statusMessage = '';
  bool _sortNewestFirst = true;
  int _sortVersion = 0; // incrementar para forzar AnimatedSwitcher
  final PdfOptimizer pdfOptimizer = PdfOptimizer();

  // Controladores para animaciones
  late AnimationController _fadeController;
  late AnimationController _staggeredController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _sortIconController;
  late Animation<double> _sortIconTurns;

  // Colores personalizados de botones
  Map<String, Color> _buttonColors = {};

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

    _sortIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _sortIconTurns = Tween<double>(begin: 0.0, end: 0.5)
        .animate(CurvedAnimation(
          parent: _sortIconController,
          curve: Curves.easeInOut,
        ));

    // Iniciar las animaciones
    _fadeController.forward();
    _staggeredController.forward();

    // Iniciar la precarga de recursos del PDF
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadPdfResources();
      _loadButtonColors();
    });
  }

  // Método para cargar colores personalizados de botones
  Future<void> _loadButtonColors() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Color> colors = {};
    
    // Mapeo de índices a nombres de tarifas (igual que en home.dart)
    final Map<int, String> indexToName = {
      0: 'Público General',
      1: 'Escolar General',
      2: 'Adulto Mayor',
      3: 'Int. hasta 15 Km',
      4: 'Int. hasta 50 Km',
      5: 'Escolar Intermedio',
    };
    
    // Determinar si es domingo o día de semana
    final today = DateTime.now();
    final isSunday = today.weekday == DateTime.sunday;
    final prefix = isSunday ? 'sunday' : 'weekday';
    
    // Cargar colores desde SharedPreferences
    for (int i = 0; i < indexToName.length; i++) {
      final key = 'button_colors_${prefix}_$i';
      final colorJson = prefs.getString(key);
      if (colorJson != null) {
        try {
          final Map<String, dynamic> colorData = json.decode(colorJson);
          if (colorData.containsKey('bgRed') && 
              colorData.containsKey('bgGreen') && 
              colorData.containsKey('bgBlue')) {
            final r = colorData['bgRed'] as int;
            final g = colorData['bgGreen'] as int;
            final b = colorData['bgBlue'] as int;
            colors[indexToName[i]!] = Color.fromRGBO(r, g, b, 1.0);
          }
        } catch (e) {
          print('Error cargando color para ${indexToName[i]}: $e');
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _buttonColors = colors;
      });
    }
  }

  // Método para obtener el color según el tipo de transacción
  Color _getColorForTransaction(String nombre) {
    // Si hay un color personalizado cargado, usarlo
    if (_buttonColors.containsKey(nombre)) {
      return _buttonColors[nombre]!;
    }
    
    // Determinar si es domingo o día de semana para colores por defecto
    final today = DateTime.now();
    final isSunday = today.weekday == DateTime.sunday;
    
    // Colores por defecto (mismos que en home.dart)
    if (isSunday) {
      // Colores domingo (generalmente más grises/rojos)
      if (nombre.contains('Público General')) {
        return Colors.grey.shade400;
      } else if (nombre.contains('Escolar General')) {
        return Colors.red.shade400;
      } else if (nombre.contains('Adulto Mayor')) {
        return Colors.green.shade400;
      } else if (nombre.contains('Int. hasta 15')) {
        return Colors.red.shade400;
      } else if (nombre.contains('Int. hasta 50')) {
        return Colors.red.shade400;
      } else if (nombre.contains('Escolar Intermedio')) {
        return Colors.white;
      }
    } else {
      // Colores de semana
      if (nombre.contains('Público General')) {
        return Colors.red.shade400;
      } else if (nombre.contains('Escolar General')) {
        return Colors.green.shade400;
      } else if (nombre.contains('Adulto Mayor')) {
        return Colors.blue.shade400;
      } else if (nombre.contains('Int. hasta 15')) {
        return Colors.blue.shade400;
      } else if (nombre.contains('Int. hasta 50')) {
        return Colors.green.shade400;
      } else if (nombre.contains('Escolar Intermedio')) {
        return Colors.white;
      }
    }
    
    // Para tipos adicionales que no están en los 6 principales
    if (nombre.contains('Oferta')) {
      return Colors.pink.shade400;
    } else if (nombre.contains('Cargo')) {
      return Colors.brown.shade400;
    }
    
    // Color por defecto si no coincide con ningún tipo conocido
    return AppTheme.turquoise;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggeredController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _sortIconController.dispose();
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
      
      // Determinar la fecha del reporte basándose en las transacciones
      // Si todas las transacciones son del mismo día, usar esa fecha
      // De lo contrario, usar la fecha actual
      DateTime reportDate = _determineReportDate(transactions);

      // Generate the PDF and get the document (assuming it returns Uint8List now)
      final pdfBytes = await generator.generatePdf(transactions, total, reportDate);

      // Use the printing library with the bytes directly
      await printing.Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Reporte_Caja_${DateFormat('dd-MM-yyyy_HHmm').format(reportDate)}',
      );

      // Clear transactions after successful printing
      await reporteCaja.clearTransactions();

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



  // NUEVO MÉTODO: Determinar la fecha del reporte basándose en las transacciones
  // Este método garantiza que el cierre de caja se genere con la fecha correcta
  // correspondiente a las transacciones, no a la fecha actual del sistema.
  // Esto evita que un cierre de caja del miércoles se guarde como jueves.
  DateTime _determineReportDate(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) {
      return DateTime.now();
    }

    // Obtener el día, mes y año de la primera transacción (no anulación)
    Map<String, dynamic>? firstValidTransaction = transactions.firstWhere(
      (t) => !t['nombre'].toString().startsWith('Anulación:'),
      orElse: () => transactions.first,
    );

    String dia = firstValidTransaction['dia'] ?? DateFormat('dd').format(DateTime.now());
    String mes = firstValidTransaction['mes'] ?? DateFormat('MM').format(DateTime.now());
    String ano = firstValidTransaction['ano'] ?? DateTime.now().year.toString();

    // Verificar si todas las transacciones son del mismo día
    bool allSameDay = transactions.every((t) {
      return t['dia'] == dia && 
             t['mes'] == mes && 
             (t['ano'] ?? ano) == ano;
    });

    if (allSameDay) {
      // Todas las transacciones son del mismo día, usar esa fecha
      try {
        int year = int.parse(ano);
        int month = int.parse(mes);
        int day = int.parse(dia);
        
        // Usar la hora de la última transacción si está disponible
        String? lastHora = transactions.last['hora'];
        int hour = 23;
        int minute = 59;
        
        if (lastHora != null && lastHora.contains(':')) {
          List<String> timeParts = lastHora.split(':');
          hour = int.tryParse(timeParts[0]) ?? hour;
          minute = int.tryParse(timeParts[1]) ?? minute;
        }
        
        return DateTime(year, month, day, hour, minute);
      } catch (e) {
        print('Error al parsear fecha de transacción: $e');
        return DateTime.now();
      }
    } else {
      // Transacciones de diferentes días, usar fecha actual
      return DateTime.now();
    }
  }

  // Método para navegar a la pantalla de reportes antiguos
  void _navigateToOldReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecoveryReport()),
    );
  }

  // ─── Widgets auxiliares ───────────────────────────────────────────────────

  Widget _buildSummaryCard(
      List<Map<String, dynamic>> transactions, double total) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                // Contador de transacciones
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${transactions.length}',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontHemiheads,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.turquoiseDark,
                        ),
                      ),
                      Text(
                        'Transacciones',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 44, color: Colors.grey.shade200),
                // Total
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '\$${NumberFormat('#,##0', 'es_ES').format(total)}',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontHemiheads,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.coral,
                          ),
                        ),
                      ),
                      Text(
                        'Total',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Resumen de pagos con tarjeta
            FutureBuilder<double>(
              future: PagoStorageService.obtenerTotalTarjetaHoy(),
              builder: (context, snapshot) {
                final totalTarjeta = snapshot.data ?? 0.0;
                if (totalTarjeta <= 0) return SizedBox.shrink();
                final totalEfectivo = total - totalTarjeta;
                return Column(
                  children: [
                    SizedBox(height: 10),
                    Divider(height: 1, color: Colors.grey.shade200),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.attach_money,
                                  size: 16, color: Colors.green.shade700),
                              SizedBox(width: 4),
                              Text(
                                '\$${NumberFormat('#,##0', 'es_ES').format(totalEfectivo)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                            width: 1, height: 20, color: Colors.grey.shade200),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.credit_card,
                                  size: 16, color: Colors.blue.shade700),
                              SizedBox(width: 4),
                              Text(
                                '\$${NumberFormat('#,##0', 'es_ES').format(totalTarjeta)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Efectivo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Tarjeta',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(List<Map<String, dynamic>> transactions) {
    // Aplicar el orden seleccionado
    final sorted = List<Map<String, dynamic>>.from(transactions);
    if (_sortNewestFirst) {
      sorted.sort((a, b) {
        final aId = (a['id'] ?? 0) as int;
        final bId = (b['id'] ?? 0) as int;
        return bId.compareTo(aId);
      });
    } else {
      sorted.sort((a, b) {
        final aId = (a['id'] ?? 0) as int;
        final bId = (b['id'] ?? 0) as int;
        return aId.compareTo(bId);
      });
    }

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: AppTheme.turquoiseDark, size: 17),
                const SizedBox(width: 6),
                const Text(
                  'Transacciones',
                  style: TextStyle(
                    fontFamily: AppTheme.fontHemiheads,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.turquoiseDark,
                  ),
                ),
                const Spacer(),
                if (transactions.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      // Animar el ícono
                      if (_sortIconController.status == AnimationStatus.dismissed ||
                          _sortIconController.status == AnimationStatus.reverse) {
                        _sortIconController.forward();
                      } else {
                        _sortIconController.reverse();
                      }
                      setState(() {
                        _sortNewestFirst = !_sortNewestFirst;
                        _sortVersion++;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.turquoiseLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RotationTransition(
                            turns: _sortIconTurns,
                            child: Icon(
                              _sortNewestFirst
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 14,
                              color: AppTheme.turquoiseDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _sortNewestFirst ? 'Más nuevo' : 'Más antiguo',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.turquoiseDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 14),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long,
                          size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'No hay transacciones registradas',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final offset = _sortNewestFirst
                      ? const Offset(0, -0.06)
                      : const Offset(0, 0.06);
                  return SlideTransition(
                    position: Tween<Offset>(
                            begin: offset, end: Offset.zero)
                        .animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_sortVersion),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final transaction = sorted[index];
                  final bool isAnulacion = transaction['nombre']
                      .toString()
                      .startsWith('Anulación:');
                  final today = DateTime.now();
                  final todayDay = DateFormat('dd').format(today);
                  final todayMonth = DateFormat('MM').format(today);
                  final transDay = transaction['dia'];
                  final transMonth = transaction['mes'];
                  final isPastDay =
                      transDay != todayDay || transMonth != todayMonth;

                  Color leftBarColor = AppTheme.turquoise;
                  Color iconColor = AppTheme.turquoise;
                  IconData iconData = Icons.receipt_rounded;
                  Color bgColor = Colors.white;

                  if (isPastDay) {
                    leftBarColor = AppTheme.coral;
                    iconColor = AppTheme.coral;
                    iconData = Icons.warning_amber_rounded;
                    bgColor = AppTheme.coralLight.withOpacity(0.15);
                  } else if (isAnulacion) {
                    leftBarColor = Colors.red.shade400;
                    iconColor = Colors.red.shade400;
                    iconData = Icons.do_disturb_rounded;
                    bgColor = Colors.red.shade50;
                  } else {
                    // Obtener color según el tipo de transacción
                    final nombre = transaction['nombre'] as String;
                    final customColor = _getColorForTransaction(nombre);
                    leftBarColor = customColor;
                    iconColor = customColor;
                    bgColor = customColor.withOpacity(0.08);
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(9),
                      border: Border(
                        left: BorderSide(color: leftBarColor, width: 3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.14),
                              shape: BoxShape.circle,
                            ),
                            child:
                                Icon(iconData, color: iconColor, size: 15),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transaction['nombre'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isPastDay
                                        ? AppTheme.coral
                                        : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${transaction['dia']}/${transaction['mes']} ${transaction['hora']}  ·  ${transaction['comprobante'] ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '\$${NumberFormat('#,##0', 'es_ES').format(transaction['valor'])}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isAnulacion
                                  ? Colors.red.shade600
                                  : AppTheme.turquoiseDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(List<Map<String, dynamic>> transactions) {
    final bool isEmpty = transactions.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.print_rounded, size: 19),
            label: const Text(
              'Cerrar Caja e Imprimir',
              style: TextStyle(
                fontFamily: AppTheme.fontHemiheads,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isEmpty ? Colors.grey.shade400 : AppTheme.turquoise,
              foregroundColor: Colors.white,
              elevation: isEmpty ? 0 : 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: isEmpty ? null : () => _generateReport(context),
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reporteCaja = Provider.of<ReporteCaja>(context);
    final transactions = reporteCaja.getOrderedTransactions();
    final total = reporteCaja.getTotal();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Reporte de Caja',
          style: TextStyle(
            fontFamily: AppTheme.fontHemiheads,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.turquoise,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            onPressed: _navigateToOldReports,
            tooltip: 'Reportes Anteriores',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Contenido desplazable
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  color: AppTheme.turquoise,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSummaryCard(transactions, total),
                        const SizedBox(height: 10),
                        _buildTransactionsList(transactions),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),

              // Barra de acción fija inferior
              _buildBottomActionBar(transactions),
            ],
          ),

          // Overlay de carga
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.turquoise),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontHemiheads,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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