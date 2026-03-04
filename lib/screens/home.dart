import 'package:intl/date_symbol_data_local.dart';
import 'cargo_screen.dart';
import 'backup_screen.dart';
import 'reporte_recovery.dart';
import '../services/pdf/generateCargo_Ticket.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'reporte_caja_screen.dart';
import 'statistics_screen.dart';
import '../services/pdf/generateTicket.dart';
import 'settings.dart';
import '../models/ReporteCaja.dart';
import '../models/ticket_model.dart';
import '../models/sunday_ticket_model.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/pdf/generate_mo_ticket.dart';
import '../models/ComprobanteModel.dart';
import '../services/pdf/pdf_optimizer.dart';
import '../services/closing/auto_closing_service.dart';
import '../services/sumup_service.dart';
import '../services/pago_storage_service.dart';
import '../providers/sumup_result_notifier.dart';

// Importar los nuevos módulos
import '../services/home/pending_transaction_service.dart';
import '../services/home/resource_preloader.dart';
import '../services/home/maintenance_service.dart';
import '../services/home/home_helpers.dart';
import '../widgets/home/password_dialogs.dart';
import '../widgets/home/reprint_dialogs.dart';
import '../widgets/home/home_app_bar_widgets.dart';
import '../widgets/home/home_buttons.dart';
import '../widgets/home/transaction_counter_widget.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Key para el Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Servicios
  final PdfOptimizer pdfOptimizer = PdfOptimizer();
  final GenerateTicket generateTicket = GenerateTicket();
  final MoTicketGenerator moTicketGenerator = MoTicketGenerator();
  late final PendingTransactionService _pendingTransactionService;
  late final ResourcePreloader _resourcePreloader;

  // Variables de estado
  bool _isButtonDisabled = false;
  bool _isLoading = false;
  late Timer _timer;
  String _currentDay = '';
  bool _switchValue = false;
  bool _hasReprinted = false;
  bool _hasAnulado = false;
  bool _isPhoneMode = true;

  // Controladores
  final TextEditingController _offerController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final FocusNode _contactFocusNode = FocusNode();

  // Variables para la configuración de botones
  bool _showIcons = true;
  double _textSizeMultiplier = 0.8;
  double _iconSpacing = 1.0;
  Map<String, IconData> _buttonIcons = {};

  // Variables para la función de reimpresión
  Map<String, dynamic>? _lastTransaction;
  bool _isReprinting = false;

  // Variables para pago con tarjeta SumUp
  bool _isWaitingSumUp = false;
  VoidCallback? _sumUpListener;

  @override
  void initState() {
    super.initState();

    // Inicializar servicios
    _pendingTransactionService = PendingTransactionService();
    _resourcePreloader = ResourcePreloader(
      pdfOptimizer: pdfOptimizer,
      generateTicket: generateTicket,
    );

    // Inicializar localización de forma asíncrona sin esperar
    _initializeLocalization();
    
    _updateDay();
    _timer = Timer.periodic(Duration(milliseconds: 250), (timer) {
      _updateDay();
    });
    _isPhoneMode = true;

    // Realizar todas las operaciones pesadas en segundo plano después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Cargar preferencias en paralelo
      await Future.wait([
        _loadLastTransaction(),
        _loadDisplayPreferences(),
        _loadIconSettings(),
      ]);

      // Luego cargar recursos PDF y verificar transacciones
      try {
        final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
        final comprobanteModel =
            Provider.of<ComprobanteModel>(context, listen: false);

        await _resourcePreloader.preloadPdfResourcesAsync(
            context, comprobanteModel, reporteCaja);

        // Verificar transacciones pendientes después de cargar recursos
        if (_pendingTransactionService
            .hasPreviousDayTransactions(reporteCaja)) {
          await _pendingTransactionService.showPreviousDayAlert(
            context,
            reporteCaja,
            _navigateToReports,
          );
        }

        // Iniciar verificación periódica de transacciones pendientes
        _pendingTransactionService.startPendingTransactionsCheck(
          reporteCaja,
          () async {
            if (mounted) {
              await _pendingTransactionService.showPreviousDayAlert(
                context,
                reporteCaja,
                _navigateToReports,
              );
            }
          },
        );

        // Ejecutar limpieza de reportes antiguos al iniciar
        await MaintenanceService.performMaintenanceTasks();
      } catch (e) {
        print('Error en precarga de recursos: $e');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDisplayPreferences();
    _loadIconSettings();
  }

  @override
  void dispose() {
    _timer.cancel();
    _pendingTransactionService.dispose();
    _offerController.dispose();
    _ownerController.dispose();
    _phoneController.dispose();
    _itemController.dispose();
    _contactFocusNode.dispose();
    // Remover listener de SumUp si existe
    if (_sumUpListener != null) {
      try {
        final notifier = Provider.of<SumUpResultNotifier>(context, listen: false);
        notifier.removeListener(_sumUpListener!);
      } catch (_) {}
      _sumUpListener = null;
    }
    super.dispose();
  }

  // ==================== MÉTODOS DE CARGA DE CONFIGURACIÓN ====================

  Future<void> _loadIconSettings() async {
    final loadedIcons = await HomeHelpers.loadIconSettings();
    setState(() {
      _iconSpacing = 1.0; // Default value
      _buttonIcons = loadedIcons;
    });
  }

  Future<void> _loadDisplayPreferences() async {
    final prefs = await HomeHelpers.loadDisplayPreferences();
    setState(() {
      _showIcons = prefs['showIcons'];
      _textSizeMultiplier = prefs['textSizeMultiplier'];
      _iconSpacing = prefs['iconSpacing'];
    });
  }

  Future<void> _initializeLocalization() async {
    await initializeDateFormatting('es_ES', null);
  }

  Future<void> _loadLastTransaction() async {
    final transaction = await HomeHelpers.loadLastTransaction();
    if (transaction != null) {
      setState(() {
        _lastTransaction = transaction;
        _hasReprinted = false;
      });
    }
  }

  Future<void> _saveLastTransaction(Map<String, dynamic> transaction) async {
    await HomeHelpers.saveLastTransaction(transaction);
    setState(() {
      _lastTransaction = transaction;
      _hasReprinted = false;
      _hasAnulado = false;
    });
  }

  void _updateDay() {
    setState(() {
      _currentDay = HomeHelpers.getCurrentDay();
    });
  }

  // ==================== MÉTODOS DE NAVEGACIÓN ====================

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReporteCajaScreen()),
    );
  }

  void _logout() {
    Navigator.pushReplacementNamed(context, '/');
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade700, Colors.amber.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12),
                  Icon(Icons.directions_bus_rounded,
                      color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text(
                    'Suray POS Bus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'V.02.03.26',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Items ───────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 8),
              children: [
                // — Operaciones —
                _buildDrawerSectionTitle('Operaciones'),
                ListTile(
                  leading:
                      Icon(Icons.assessment_rounded, color: Color(0xFF4F8FC0)),
                  title: Text('Cierres de Caja'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToReports();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.bar_chart_rounded,
                      color: Colors.green.shade700),
                  title: Text('Estadísticas'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => StatisticsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.inventory_2_rounded,
                      color: Colors.orange.shade700),
                  title: Text('Cargo'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CargoScreen(
                          onTransactionComplete: _saveLastTransaction,
                        ),
                      ),
                    );
                  },
                ),
                Divider(indent: 16, endIndent: 16),
                // — Respaldo —
                _buildDrawerSectionTitle('Respaldo'),
                ListTile(
                  leading: Icon(Icons.history_edu_rounded,
                      color: Colors.indigo.shade400),
                  title: Text('Recuperación de Reportes'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RecoveryReport()),
                    );
                  },
                ),
                ListTile(
                  leading:
                      Icon(Icons.backup_rounded, color: Colors.teal.shade600),
                  title: Text('Copias de Seguridad'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BackupScreen()),
                    );
                  },
                ),
                Divider(indent: 16, endIndent: 16),
                // — Sistema —
                _buildDrawerSectionTitle('Sistema'),
                ListTile(
                  leading: Icon(Icons.settings_rounded,
                      color: Colors.green.shade700),
                  title: Text('Configuración'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToSettings();
                  },
                ),
                ListTile(
                  leading:
                      Icon(Icons.logout_rounded, color: Colors.red.shade600),
                  title: Text('Cerrar Sesión'),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSettings() async {
    final settingsChanged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => Settings()),
    );

    if (settingsChanged == true) {
      print('Settings changed, reloading preferences');
      await _loadDisplayPreferences();
      setState(() {});
    }
  }

  // ==================== MÉTODOS DE GENERACIÓN DE TICKETS ====================

  Future<void> _generateTicket(
      String tipo, double valor, bool isCorrespondencia) async {
    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    final autoClosingService = AutoClosingService();

    // Verificar y realizar auto-cierre si hay cambio de día
    final didAutoClose = await autoClosingService.checkAndAutoClose(reporteCaja);
    if (didAutoClose && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se cerró la caja del día anterior automáticamente'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Verificar transacciones pendientes del día anterior (por si no se pudo auto-cerrar)
    if (_pendingTransactionService.hasPreviousDayTransactions(reporteCaja)) {
      await _pendingTransactionService.showPreviousDayAlert(
        context,
        reporteCaja,
        _navigateToReports,
      );
      return;
    }

    if (_isButtonDisabled) return;

    setState(() {
      _hasReprinted = false;
      _hasAnulado = false;
      _isButtonDisabled = true;
      _isLoading = true;
    });

    final snackBar = SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 10),
          Text('Generando ticket de $tipo...'),
        ],
      ),
      duration: Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    try {
      final comprobanteModel =
          Provider.of<ComprobanteModel>(context, listen: false);

      await generateTicket.generateTicketPdf(
        context,
        valor,
        _switchValue,
        tipo,
        comprobanteModel,
        false,
      );

      String currentComprobante = comprobanteModel.formattedComprobante;
      reporteCaja.receiveData(tipo, valor, currentComprobante);

      // Actualizar fecha de última transacción
      await autoClosingService.updateLastTransactionDate();

      setState(() {
        _lastTransaction = {
          'nombre': tipo,
          'valor': valor,
          'switchValue': _switchValue,
          'comprobante': currentComprobante,
        };
      });

      await _saveLastTransaction(_lastTransaction!);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket generado correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error generando ticket: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar ticket'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isButtonDisabled = false;
        _isLoading = false;
      });
    }
  }

  // ==================== DIÁLOGO DE MÉTODO DE PAGO ====================

  /// Muestra un diálogo para elegir entre Efectivo y Tarjeta.
  /// Si se elige Efectivo, genera el ticket normalmente.
  /// Si se elige Tarjeta, inicia el flujo SumUp Deep Link.
  void _showPaymentMethodDialog(String tipo, double valor, bool isCorrespondencia) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Método de Pago',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '$tipo — \$${NumberFormat('#,##0', 'es_CL').format(valor)}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  // Botón Efectivo
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.attach_money, size: 24),
                        label: Text('Efectivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _generateTicket(tipo, valor, isCorrespondencia);
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // Botón Tarjeta
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.credit_card, size: 24),
                        label: Text('Tarjeta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _generateTicketConTarjeta(tipo, valor, isCorrespondencia);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Inicia cobro con tarjeta vía SumUp y, al recibir resultado exitoso,
  /// genera el ticket y guarda el pago en PagoStorageService.
  Future<void> _generateTicketConTarjeta(
      String tipo, double valor, bool isCorrespondencia) async {
    if (_isButtonDisabled) return;

    setState(() {
      _isWaitingSumUp = true;
      _isButtonDisabled = true;
    });

    try {
      // Abrir la app de SumUp para cobrar
      await SumUpService.cobrar(monto: valor, titulo: 'Pasaje Suray - $tipo');

      // Escuchar resultado desde el notifier
      final notifier = Provider.of<SumUpResultNotifier>(context, listen: false);

      // Remover listener anterior si existe
      if (_sumUpListener != null) {
        notifier.removeListener(_sumUpListener!);
      }

      _sumUpListener = () async {
        final exitoso = notifier.exitoso;
        if (exitoso == null) return; // Aún no hay resultado

        final txCode = notifier.txCode;
        notifier.limpiar();

        // Remover el listener
        if (_sumUpListener != null) {
          notifier.removeListener(_sumUpListener!);
          _sumUpListener = null;
        }

        if (!mounted) return;

        if (exitoso) {
          // Guardar pago con tarjeta
          await PagoStorageService.guardarPagoTarjeta(
            monto: valor,
            txCode: txCode,
            fecha: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          );

          // Generar el ticket normalmente (igual que efectivo)
          setState(() {
            _isWaitingSumUp = false;
          });
          await _generateTicket(tipo, valor, isCorrespondencia);
        } else {
          setState(() {
            _isWaitingSumUp = false;
            _isButtonDisabled = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text('Pago con tarjeta rechazado o cancelado')),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Reintentar',
                  textColor: Colors.white,
                  onPressed: () {
                    _generateTicketConTarjeta(tipo, valor, isCorrespondencia);
                  },
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      };

      notifier.addListener(_sumUpListener!);
    } catch (e) {
      setState(() {
        _isWaitingSumUp = false;
        _isButtonDisabled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('$e')),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ==================== MÉTODOS DE REIMPRESIÓN ====================

  void _handleReprint() async {
    // Si no es cargo y ya reimpreso, bloqueo
    if (_hasReprinted &&
        _lastTransaction != null &&
        !_lastTransaction!['nombre']
            .toString()
            .toLowerCase()
            .contains('cargo')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Ya se ha reimpreso este boleto. Genere uno nuevo para reimprimir.')),
      );
      return;
    }

    // Sin última transacción
    if (_lastTransaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay transacción para reimprimir')),
      );
      return;
    }

    // Pedir contraseña
    bool ok =
        await showReprintPasswordDialog(context, HomeHelpers.loadPassword);
    if (!ok) return;

    // Cargo → muestro siempre opciones Cliente/Carga/Ambas
    final nombre = _lastTransaction!['nombre'].toString().toLowerCase();
    if (nombre.contains('cargo')) {
      await showLastCargoReprintOptions(
        context,
        _lastTransaction,
        _reprintCargoTicket,
      );
    } else {
      // Resto → flujo actual (una única reimpresión)
      await showReprintOptionsDialog(
        context,
        _lastTransaction,
        _hasReprinted,
        _handleLastTransactionReprint,
      );
      setState(() {
        _hasReprinted = true;
      });
    }
  }

  void _handleLastTransactionReprint() async {
    if (_lastTransaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay transacción para reimprimir')),
      );
      return;
    }

    setState(() {
      _isReprinting = true;
    });

    try {
      String nombre = _lastTransaction!['nombre'] ?? '';

      if (nombre.toLowerCase().contains('cargo')) {
        await showLastCargoReprintOptions(
          context,
          _lastTransaction,
          _reprintCargoTicket,
        );
      } else if (nombre == 'Oferta Ruta' ||
          _lastTransaction!['tipo'] == 'ofertaMultiple') {
        await _reprintOfferTicket();
      } else {
        await _reprintRegularTicket();
      }

      if (!nombre.toLowerCase().contains('cargo')) {
        setState(() {
          _hasReprinted = true;
        });
      }
    } catch (e) {
      print('Error al reimprimir: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reimprimir: $e')),
      );
    } finally {
      setState(() {
        _isReprinting = false;
      });
    }
  }

  Future<void> _reprintOfferTicket() async {
    try {
      if (_lastTransaction == null ||
          _lastTransaction!['offerEntries'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('No hay suficientes detalles para reimprimir')),
        );
        return;
      }

      Provider.of<ComprobanteModel>(context, listen: false);
      String comprobante = _lastTransaction!['comprobante'] ?? '';
      bool switchValue = _lastTransaction!['switchValue'] ?? false;

      List savedEntries = _lastTransaction!['offerEntries'] as List;
      List<Map<String, dynamic>> offerEntries = [];
      for (var entry in savedEntries) {
        offerEntries.add({
          'number': entry['number'],
          'value': entry['value'],
          'numberController': TextEditingController(text: entry['number']),
          'valueController': TextEditingController(text: entry['value']),
        });
      }

      setState(() {
        _isReprinting = true;
      });

      await moTicketGenerator.reprintMoTicket(
        PdfPageFormat.standard,
        offerEntries,
        switchValue,
        context,
        comprobante,
      );

      setState(() {
        _hasReprinted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reimpresión completada correctamente')),
      );
    } catch (e) {
      print('Error en _reprintOfferTicket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reimprimir: $e')),
      );
    } finally {
      setState(() {
        _isReprinting = false;
      });
    }
  }

  Future<void> _reprintRegularTicket() async {
    final comprobanteModel =
        Provider.of<ComprobanteModel>(context, listen: false);

    String tipo = _lastTransaction!['nombre'] ?? '';
    double valor = _lastTransaction!['valor'] ?? 0.0;
    bool switchValue = _lastTransaction!['switchValue'] ?? false;

    await generateTicket.generateTicketPdf(
      context,
      valor,
      switchValue,
      tipo,
      comprobanteModel,
      true,
    );

    setState(() {
      _hasReprinted = true;
    });
  }

  Future<void> _reprintCargoTicket(bool printClient, bool printCargo) async {
    final comprobanteModel =
        Provider.of<ComprobanteModel>(context, listen: false);
    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    final cargoGen = CargoTicketGenerator(comprobanteModel, reporteCaja);

    try {
      final String destinatario =
          _lastTransaction!['destinatario'] as String? ?? '';
      final String articulo = _lastTransaction!['articulo'] as String? ?? '';
      final double valor = _lastTransaction!['precio'] as double? ?? 0.0;
      final String destino = _lastTransaction!['destino'] as String? ?? '';
      final String telefono = _lastTransaction!['telefono'] as String? ?? '';
      final String ticketNum = comprobanteModel.formattedComprobante;

      await cargoGen.reprintNewCargoPdf(
        destinatario,
        articulo,
        valor,
        destino,
        telefono,
        printClient,
        printCargo,
        ticketNum,
      );

      setState(() {
        _hasReprinted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reimpresión completada correctamente')),
      );
    } catch (e) {
      print('Error en _reprintCargoTicket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reimprimir: $e')),
      );
      setState(() {
        _hasReprinted = false;
      });
    }
  }

  // ==================== DIÁLOGO DE OFERTA MÚLTIPLE ====================

  Future<void> _showMultiOfferDialog() async {
    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);

    // Verificar si hay transacciones del día anterior
    if (_pendingTransactionService.hasPreviousDayTransactions(reporteCaja)) {
      await _pendingTransactionService.showPreviousDayAlert(
        context,
        reporteCaja,
        _navigateToReports,
      );
      return;
    }

    // Asegurar que los recursos estén precargados
    if (!_resourcePreloader.resourcesPreloaded) {
      final comprobanteModel =
          Provider.of<ComprobanteModel>(context, listen: false);
      await _resourcePreloader.preloadPdfResources(
          context, comprobanteModel, reporteCaja);
    }

    final decimalFormatter = NumberFormat.decimalPattern('es_CL');

    List<Map<String, dynamic>> offerEntries = [
      {
        'numberController': TextEditingController(),
        'valueController': TextEditingController(),
        'numberFocus': FocusNode(),
        'valueFocus': FocusNode(),
      }
    ];

    double currentTotal = 0.0;

    double calculateTotal(List<Map<String, dynamic>> entries) {
      return entries.fold(0.0, (sum, e) {
        final qty = double.tryParse(e['numberController'].text) ?? 0;
        final val = double.tryParse(e['valueController'].text) ?? 0;
        return sum + qty * val;
      });
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Oferta Ruta',
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter dialogSetState) {
            bool isLoading = false;

            void setupControllerListeners() {
              for (var entry in offerEntries) {
                final numberController =
                    entry['numberController'] as TextEditingController?;
                final valueController =
                    entry['valueController'] as TextEditingController?;

                if (numberController != null) {
                  numberController.removeListener(() {});
                  numberController.addListener(() {
                    dialogSetState(() {
                      currentTotal = calculateTotal(offerEntries);
                    });
                  });
                }

                if (valueController != null) {
                  valueController.removeListener(() {});
                  valueController.addListener(() {
                    dialogSetState(() {
                      currentTotal = calculateTotal(offerEntries);
                    });
                  });
                }
              }
            }

            if (currentTotal == 0.0) {
              setupControllerListeners();
            }

            Future<void> submitAndPrint() async {
              dialogSetState(() => isLoading = true);
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              setState(() {
                _isButtonDisabled = true;
                _isLoading = true;
              });

              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Generando oferta...'),
                    duration: Duration(milliseconds: 800),
                  ),
                );

                final entriesForTicket = offerEntries
                    .map((e) => {
                          'number': e['numberController'].text,
                          'value': e['valueController'].text,
                        })
                    .toList();

                await moTicketGenerator.generateMoTicket(
                  PdfPageFormat.standard,
                  entriesForTicket,
                  _switchValue,
                  context,
                  (String nombre, double valor, List<double> subtots,
                      String comprobante) {
                    reporteCaja.addOfferEntries(subtots, valor, comprobante);
                    if (!mounted) return;
                    setState(() {
                      _lastTransaction = {
                        'nombre': 'Oferta Ruta',
                        'valor': currentTotal,
                        'switchValue': _switchValue,
                        'comprobante': comprobante,
                        'offerEntries': entriesForTicket,
                        'tipo': 'ofertaMultiple',
                      };
                      _hasReprinted = false;
                      _hasAnulado = false;
                    });

                    _saveLastTransaction(_lastTransaction!);
                  },
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Oferta generada correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al imprimir: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  _resourcePreloader.clearCacheIfNeeded();
                }
              } finally {
                if (!mounted) return;
                setState(() {
                  _isButtonDisabled = false;
                  _isLoading = false;
                });
              }
            }

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.amber.shade800,
                title: Text('Oferta en Ruta'),
                actions: [
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  )
                ],
              ),
              body: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (reporteCaja.hasPendingOldTransactions())
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hay cajas pendientes de cierre',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                  Text(
                                    'Se recomienda cerrar las cajas pendientes',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                _navigateToReports();
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.orange.shade100,
                                foregroundColor: Colors.orange.shade900,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              child: Text('Ir a Reportes'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: offerEntries.length,
                        itemBuilder: (_, i) {
                          final e = offerEntries[i];
                          return Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: e['numberController'],
                                  focusNode: e['numberFocus'],
                                  decoration: InputDecoration(
                                    labelText: 'Cantidad',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    dialogSetState(() {
                                      currentTotal =
                                          calculateTotal(offerEntries);
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: e['valueController'],
                                  focusNode: e['valueFocus'],
                                  decoration: InputDecoration(
                                    labelText: 'Valor',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    dialogSetState(() {
                                      currentTotal =
                                          calculateTotal(offerEntries);
                                    });
                                  },
                                ),
                              ),
                              if (offerEntries.length > 1) ...[
                                IconButton(
                                  icon: Icon(Icons.remove_circle,
                                      color: Colors.red),
                                  onPressed: () {
                                    dialogSetState(() {
                                      offerEntries.removeAt(i);
                                      currentTotal =
                                          calculateTotal(offerEntries);
                                    });
                                  },
                                )
                              ]
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          Spacer(),
                          Text(
                            '\$${decimalFormatter.format(currentTotal)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    if (!isLoading)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              dialogSetState(() {
                                final newEntry = {
                                  'numberController': TextEditingController(),
                                  'valueController': TextEditingController(),
                                  'numberFocus': FocusNode(),
                                  'valueFocus': FocusNode(),
                                };
                                offerEntries.add(newEntry);

                                final newNumberController =
                                    newEntry['numberController']
                                        as TextEditingController?;
                                final newValueController =
                                    newEntry['valueController']
                                        as TextEditingController?;

                                if (newNumberController != null) {
                                  newNumberController.addListener(() {
                                    dialogSetState(() {
                                      currentTotal =
                                          calculateTotal(offerEntries);
                                    });
                                  });
                                }

                                if (newValueController != null) {
                                  newValueController.addListener(() {
                                    dialogSetState(() {
                                      currentTotal =
                                          calculateTotal(offerEntries);
                                    });
                                  });
                                }
                              });
                            },
                            icon: Icon(Icons.add),
                            label: Text('Agregar línea'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: submitAndPrint,
                            icon: Icon(Icons.print),
                            label: Text('Imprimir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      )
                    else
                      Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.amber.shade800),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== DIÁLOGO DE CARGO ====================

  void _showOfferDialog() {
    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);

    if (_pendingTransactionService.hasPreviousDayTransactions(reporteCaja)) {
      _pendingTransactionService.showPreviousDayAlert(
        context,
        reporteCaja,
        _navigateToReports,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CargoScreen(
          onTransactionComplete: (transactionData) {
            _saveLastTransaction(transactionData);
          },
        ),
      ),
    );
  }

  // ==================== DIÁLOGO DE ANULAR VENTA ====================

  Future<void> _showPasswordDialog() async {
    await showPasswordDialog(
      context,
      HomeHelpers.loadPassword,
      _cancelLastTransaction,
      _hasAnulado,
    );
  }

  Future<void> _cancelLastTransaction() async {
    await HomeHelpers.cancelLastTransaction(context);

    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    reporteCaja.cancelTransaction();

    setState(() {
      _hasAnulado = true;
    });
  }

  // ==================== BUILD METHOD ====================

  @override
  Widget build(BuildContext context) {
    double marginSize = MediaQuery.of(context).size.width * 0.05;
    double screenWidth = MediaQuery.of(context).size.width;
    double buttonWidth = screenWidth - (marginSize * 2);
    double buttonHeight = 60;
    double textSize = buttonWidth * 0.06;

    final ticketModel = Provider.of<TicketModel>(context);
    final sundayTicketModel = Provider.of<SundayTicketModel>(context);
    final reporteCaja = Provider.of<ReporteCaja>(context);

    List<Map<String, dynamic>> pasajes =
        _switchValue ? sundayTicketModel.pasajes : ticketModel.pasajes;

    bool hasPendingDays = reporteCaja.hasPendingOldTransactions();

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(context),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hasPendingDays
                  ? [Colors.orange.shade800, Colors.red.shade700]
                  : [Colors.amber.shade700, Colors.amber.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: (hasPendingDays ? Colors.orange : Colors.amber)
                    .withOpacity(0.4),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                // ── Izquierda: menú + badge ────────────────────────────
                HomeAppBarWidgets.buildAppBarSlotWidget(
                  context: context,
                  slot: {'isEmpty': false, 'element': 'report'},
                  currentDay: _currentDay,
                  lastTransaction: _lastTransaction,
                  hasReprinted: _hasReprinted,
                  hasAnulado: _hasAnulado,
                  isReprinting: _isReprinting,
                  getCurrentDate: HomeHelpers.getCurrentDate,
                  onNavigateToSettings: _navigateToSettings,
                  onShowOfferDialog: _showOfferDialog,
                  onShowPasswordDialog: _showPasswordDialog,
                  onHandleReprint: _handleReprint,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                if (hasPendingDays) ...[
                  SizedBox(width: 6),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '${reporteCaja.getOldestPendingDays()}d',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Espaciador ─────────────────────────────────────────
                Spacer(),

                // ── Derecha: anular · reimprimir · fecha ───────────────
                HomeAppBarWidgets.buildAppBarSlotWidget(
                  context: context,
                  slot: {'isEmpty': false, 'element': 'delete'},
                  currentDay: _currentDay,
                  lastTransaction: _lastTransaction,
                  hasReprinted: _hasReprinted,
                  hasAnulado: _hasAnulado,
                  isReprinting: _isReprinting,
                  getCurrentDate: HomeHelpers.getCurrentDate,
                  onNavigateToSettings: _navigateToSettings,
                  onShowOfferDialog: _showOfferDialog,
                  onShowPasswordDialog: _showPasswordDialog,
                  onHandleReprint: _handleReprint,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                SizedBox(width: 10),
                HomeAppBarWidgets.buildAppBarSlotWidget(
                  context: context,
                  slot: {'isEmpty': false, 'element': 'reprint'},
                  currentDay: _currentDay,
                  lastTransaction: _lastTransaction,
                  hasReprinted: _hasReprinted,
                  hasAnulado: _hasAnulado,
                  isReprinting: _isReprinting,
                  getCurrentDate: HomeHelpers.getCurrentDate,
                  onNavigateToSettings: _navigateToSettings,
                  onShowOfferDialog: _showOfferDialog,
                  onShowPasswordDialog: _showPasswordDialog,
                  onHandleReprint: _handleReprint,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                SizedBox(width: 10),
                HomeAppBarWidgets.buildAppBarSlotWidget(
                  context: context,
                  slot: {'isEmpty': false, 'element': 'date'},
                  currentDay: _currentDay,
                  lastTransaction: _lastTransaction,
                  hasReprinted: _hasReprinted,
                  hasAnulado: _hasAnulado,
                  isReprinting: _isReprinting,
                  getCurrentDate: HomeHelpers.getCurrentDate,
                  onNavigateToSettings: _navigateToSettings,
                  onShowOfferDialog: _showOfferDialog,
                  onShowPasswordDialog: _showPasswordDialog,
                  onHandleReprint: _handleReprint,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ],
            ),
            titleSpacing: 0,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Fondo de imagen que cubre toda la pantalla
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                    _switchValue ? 'assets/bgRojo.png' : 'assets/bgBlanco.png',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Contenido encima del fondo
          Column(
            children: [
              // Espaciador para la AppBar
              SizedBox(height:90),
              // Banner de advertencia si hay días pendientes
              if (hasPendingDays)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade100,
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hay ${reporteCaja.getOldestPendingDays()} días con ventas sin cerrar',
                          style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: _navigateToReports,
                        child: Text('Cerrar Caja'),
                      ),
                    ],
                  ),
                ),

              // Contenido principal
              Expanded(
                child: Container(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 10.0, left: 10.0, right: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TransactionCounterWidget(),
                            Consumer<ComprobanteModel>(
                              builder: (context, comprobanteModel, child) {
                                return Container(
                                  height: 36,
                                  width: 100,
                                  padding: EdgeInsets.symmetric(horizontal: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(13),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.receipt_long,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        '${comprobanteModel.comprobanteNumber}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: EdgeInsets.all(8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: Duration(milliseconds: 600),
                                      transitionBuilder: (Widget child,
                                          Animation<double> animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Stack(
                                        key: ValueKey<bool>(_switchValue),
                                        children: [
                                          Text(
                                            _switchValue
                                                ? 'Domingo/Feriado'
                                                : 'Lunes a Sábado',
                                            style: TextStyle(
                                              fontFamily: 'Hemiheads',
                                              fontSize: textSize * 1,
                                              foreground: Paint()
                                                ..style = PaintingStyle.stroke
                                                ..strokeWidth = 2
                                                ..color = Colors.black,
                                            ),
                                          ),
                                          Text(
                                            _switchValue
                                                ? 'Domingo/Feriado'
                                                : 'Lunes a Sábado',
                                            style: TextStyle(
                                              fontFamily: 'Hemiheads',
                                              fontSize: textSize * 1,
                                              color: _switchValue
                                                  ? Colors.red
                                                  : Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Switch(
                                      value: _switchValue,
                                      onChanged: (value) {
                                        setState(() {
                                          _switchValue = value;
                                        });
                                      },
                                      activeColor: Colors.red,
                                      activeTrackColor:
                                          Colors.red.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(right: 16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (hasPendingDays)
                                      Container(
                                        margin: EdgeInsets.only(bottom: 10),
                                        width: 70,
                                        height: 30,
                                        child: ElevatedButton.icon(
                                          icon: Icon(Icons.warning_amber,
                                              size: 16),
                                          label: Text('Cerrar',
                                              style: TextStyle(fontSize: 10)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 5),
                                          ),
                                          onPressed: _navigateToReports,
                                        ),
                                      ),
                                    Image.asset(
                                      'assets/logo.png',
                                      width: 130,
                                      height: 100,
                                      fit: BoxFit.contain,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Primera fila: Público General | Intermedio hasta 50kms
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(
                            width: (buttonWidth / 2) - 10,
                            height: buttonHeight,
                            child: HomeButtons.buildConfigurableButton(
                              context: context,
                              text: pasajes[0]['nombre'],
                              icon: Icons.people,
                              backgroundColor:
                                  _switchValue ? Colors.grey : Colors.red,
                              borderColor: _switchValue
                                  ? Colors.blueAccent
                                  : Colors.black,
                              onPressed: () {
                                _showPaymentMethodDialog(pasajes[0]['nombre'],
                                    pasajes[0]['precio'], false);
                              },
                              showIcons: _showIcons,
                              textSizeMultiplier: _textSizeMultiplier,
                              buttonIcons: _buttonIcons,
                              isDisabled: _isButtonDisabled || hasPendingDays,
                            ),
                          ),
                          SizedBox(
                            width: (buttonWidth / 2) - 10,
                            height: buttonHeight,
                            child: HomeButtons.buildConfigurableButton(
                              context: context,
                              text: pasajes[4]['nombre'],
                              icon: Icons.map,
                              backgroundColor:
                                  _switchValue ? Colors.red : Colors.green,
                              borderColor: _switchValue
                                  ? Colors.pinkAccent
                                  : Colors.black,
                              onPressed: () {
                                _showPaymentMethodDialog(pasajes[4]['nombre'],
                                    pasajes[4]['precio'], false);
                              },
                              showIcons: _showIcons,
                              textSizeMultiplier: _textSizeMultiplier,
                              buttonIcons: _buttonIcons,
                              isDisabled: _isButtonDisabled || hasPendingDays,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),

                      // Segunda fila: Escolar | Intermedio hasta 15 km
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(
                            width: (buttonWidth / 2) - 10,
                            height: buttonHeight,
                            child: HomeButtons.buildConfigurableButton(
                              context: context,
                              text: pasajes[1]['nombre'],
                              icon: Icons.school,
                              backgroundColor:
                                  _switchValue ? Colors.red : Colors.green,
                              borderColor: _switchValue
                                  ? Colors.pinkAccent
                                  : Colors.black,
                              onPressed: () {
                                _showPaymentMethodDialog(pasajes[1]['nombre'],
                                    pasajes[1]['precio'], false);
                              },
                              showIcons: _showIcons,
                              textSizeMultiplier: _textSizeMultiplier,
                              buttonIcons: _buttonIcons,
                              isDisabled: _isButtonDisabled || hasPendingDays,
                            ),
                          ),
                          SizedBox(
                            width: (buttonWidth / 2) - 10,
                            height: buttonHeight,
                            child: HomeButtons.buildConfigurableButton(
                              context: context,
                              text: pasajes[3]['nombre'],
                              icon: Icons.directions_bus,
                              backgroundColor:
                                  _switchValue ? Colors.red : Colors.blue,
                              borderColor: _switchValue
                                  ? Colors.pinkAccent
                                  : Colors.black,
                              onPressed: () {
                                _showPaymentMethodDialog(pasajes[3]['nombre'],
                                    pasajes[3]['precio'], false);
                              },
                              showIcons: _showIcons,
                              textSizeMultiplier: _textSizeMultiplier,
                              buttonIcons: _buttonIcons,
                              isDisabled: _isButtonDisabled || hasPendingDays,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),

                      // Tercera fila: Adulto Mayor | Escolar Intermedio
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(
                            width: (buttonWidth / 2) - 10,
                            height: buttonHeight,
                            child: HomeButtons.buildConfigurableButton(
                              context: context,
                              text: pasajes[2]['nombre'],
                              icon: Icons.elderly,
                              backgroundColor:
                                  _switchValue ? Colors.green : Colors.blue,
                              borderColor: _switchValue
                                  ? Colors.yellowAccent
                                  : Colors.black,
                              onPressed: () {
                                _showPaymentMethodDialog(pasajes[2]['nombre'],
                                    pasajes[2]['precio'], false);
                              },
                              showIcons: _showIcons,
                              textSizeMultiplier: _textSizeMultiplier,
                              buttonIcons: _buttonIcons,
                              isDisabled: _isButtonDisabled || hasPendingDays,
                            ),
                          ),
                          SizedBox(
                            width: (buttonWidth / 2) - 10,
                            height: buttonHeight,
                            child: HomeButtons.buildConfigurableButton(
                              context: context,
                              text: pasajes.length > 5
                                  ? pasajes[5]['nombre']
                                  : 'Escolar Intermedio',
                              icon: Icons.school_outlined,
                              backgroundColor:
                                  _switchValue ? Colors.white : Colors.white,
                              borderColor:
                                  _switchValue ? Colors.black : Colors.black,
                              textColor: Colors.black,
                              onPressed: () {
                                if (pasajes.length > 5) {
                                  _showPaymentMethodDialog(pasajes[5]['nombre'],
                                      pasajes[5]['precio'], false);
                                } else {
                                  double defaultPrice =
                                      _switchValue ? 1300.0 : 1000.0;
                                  _showPaymentMethodDialog('Escolar Intermedio',
                                      defaultPrice, false);
                                  print(
                                      'ADVERTENCIA: No se encontró Escolar Intermedio en la posición 5. Usando precio por defecto: $defaultPrice');
                                }
                              },
                              showIcons: _showIcons,
                              textSizeMultiplier: _textSizeMultiplier,
                              buttonIcons: _buttonIcons,
                              isDisabled: _isButtonDisabled || hasPendingDays,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),

                      // Cuarta fila: Multi Oferta y Cargo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(
                            width: (buttonWidth / 2) - 10,
                            height: buttonHeight,
                            child: HomeButtons.buildConfigurableButton(
                              context: context,
                              text: 'O F E R T A',
                              icon: Icons.local_offer,
                              backgroundColor: hasPendingDays
                                  ? Colors.grey.shade300
                                  : Colors.orange,
                              borderColor: Colors.black,
                              textColor: Colors.black,
                              onPressed: _showMultiOfferDialog,
                              showIcons: _showIcons,
                              textSizeMultiplier: _textSizeMultiplier,
                              buttonIcons: _buttonIcons,
                              isDisabled: _isButtonDisabled || hasPendingDays,
                            ),
                          ),
                          SizedBox(
                            width: (buttonWidth / 2) - 10,
                            height: buttonHeight,
                            child: HomeButtons.buildConfigurableButton(
                              context: context,
                              text: 'C A R G O',
                              icon: Icons.inventory,
                              textColor: Colors.black,
                              backgroundColor:
                                  _isButtonDisabled || hasPendingDays
                                      ? Colors.grey
                                      : Colors.orange,
                              borderColor: Colors.black,
                              onPressed: _showOfferDialog,
                              showIcons: _showIcons,
                              textSizeMultiplier: _textSizeMultiplier,
                              buttonIcons: _buttonIcons,
                              isDisabled: _isButtonDisabled || hasPendingDays,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Overlay de espera SumUp
          if (_isWaitingSumUp)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade700),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Esperando pago con tarjeta...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Complete el pago en la app de SumUp',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            final notifier = Provider.of<SumUpResultNotifier>(
                                context,
                                listen: false);
                            if (_sumUpListener != null) {
                              notifier.removeListener(_sumUpListener!);
                              _sumUpListener = null;
                            }
                            setState(() {
                              _isWaitingSumUp = false;
                              _isButtonDisabled = false;
                            });
                          },
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
