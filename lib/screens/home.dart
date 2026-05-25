import 'package:intl/date_symbol_data_local.dart';
import 'cargo_screen.dart';
import 'backup_screen.dart';
import 'transferencia_screen.dart';
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
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/pdf/generate_mo_ticket.dart';
import '../models/ComprobanteModel.dart';
import '../services/pdf/pdf_optimizer.dart';
import '../services/closing/auto_closing_service.dart';
import '../services/sumup_service.dart';
import '../services/pago_storage_service.dart';
import '../providers/sumup_result_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importar los nuevos módulos
import '../services/home/pending_transaction_service.dart';
import '../services/home/resource_preloader.dart';
import '../services/home/home_helpers.dart';
import '../widgets/home/password_dialogs.dart';
import '../widgets/home/reprint_dialogs.dart';
import '../widgets/home/home_app_bar_widgets.dart';
import '../services/holiday_service.dart';
import '../widgets/home/home_buttons.dart';
import '../widgets/home/transaction_counter_widget.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

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
  bool _isAutoTarifa =
      false; // true cuando el switch fue fijado automáticamente
  String? _holidayReason; // nombre del feriado o 'Domingo' si aplica
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

  // Variables para colores personalizados de botones
  Map<String, Map<String, Color>> _buttonColors = {};

  // Variables para la función de reimpresión
  Map<String, dynamic>? _lastTransaction;
  bool _isReprinting = false;

  // Variables para pago con tarjeta SumUp
  bool _isWaitingSumUp = false;
  VoidCallback? _sumUpListener;
  bool _sumUpEnabled = true;

  // Variables para NFC
  bool _isNfcAvailable = false;

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

    // Inicializar NFC
    _checkNfcAvailability();

    // Realizar todas las operaciones pesadas en segundo plano después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Cargar preferencias en paralelo
      await Future.wait([
        _loadLastTransaction(),
        _loadDisplayPreferences(),
        _loadIconSettings(),
        _loadSumUpEnabled(),
        _loadButtonColors(),
        _autoDetectTarifa(),
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
        final notifier =
            Provider.of<SumUpResultNotifier>(context, listen: false);
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

  /// Detecta automáticamente si hoy es domingo o feriado y ajusta el switch.
  /// El usuario puede sobrescribir manualmente después de que cargue.
  Future<void> _autoDetectTarifa() async {
    final result = await HolidayService().checkToday();
    if (!mounted) return;
    setState(() {
      _switchValue = result.isSpecial;
      _isAutoTarifa = result.isSpecial;
      _holidayReason = result.reason;
    });
  }

  Future<void> _loadButtonColors() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Map<String, Color>> colors = {};

    // Cargar colores para cada botón (weekday y sunday)
    for (int i = 0; i < 6; i++) {
      // Weekday
      final keyWeekday = 'button_colors_weekday_$i';
      final String? colorsJsonWeekday = prefs.getString(keyWeekday);
      if (colorsJsonWeekday != null) {
        final Map<String, dynamic> colorData = json.decode(colorsJsonWeekday);
        colors['weekday_$i'] = {
          'background': Color.fromRGBO(
            colorData['bgRed'].toInt(),
            colorData['bgGreen'].toInt(),
            colorData['bgBlue'].toInt(),
            (colorData['bgOpacity'] as num?)?.toDouble() ?? 0.70,
          ),
          'border': Color.fromRGBO(
            colorData['borderRed'].toInt(),
            colorData['borderGreen'].toInt(),
            colorData['borderBlue'].toInt(),
            1,
          ),
        };
      }

      // Sunday
      final keySunday = 'button_colors_sunday_$i';
      final String? colorsJsonSunday = prefs.getString(keySunday);
      if (colorsJsonSunday != null) {
        final Map<String, dynamic> colorData = json.decode(colorsJsonSunday);
        colors['sunday_$i'] = {
          'background': Color.fromRGBO(
            colorData['bgRed'].toInt(),
            colorData['bgGreen'].toInt(),
            colorData['bgBlue'].toInt(),
            (colorData['bgOpacity'] as num?)?.toDouble() ?? 0.70,
          ),
          'border': Color.fromRGBO(
            colorData['borderRed'].toInt(),
            colorData['borderGreen'].toInt(),
            colorData['borderBlue'].toInt(),
            1,
          ),
        };
      }
    }

    setState(() {
      _buttonColors = colors;
    });

    // Cargar colores para botones OTROS (oferta=0, cargo=1)
    for (int i = 0; i < 2; i++) {
      final keyOtros = 'button_colors_otros_$i';
      final String? colorsJsonOtros = prefs.getString(keyOtros);
      if (colorsJsonOtros != null) {
        final Map<String, dynamic> colorData = json.decode(colorsJsonOtros);
        colors['otros_$i'] = {
          'background': Color.fromRGBO(
            colorData['bgRed'].toInt(),
            colorData['bgGreen'].toInt(),
            colorData['bgBlue'].toInt(),
            (colorData['bgOpacity'] as num?)?.toDouble() ?? 0.70,
          ),
          'border': Color.fromRGBO(
            colorData['borderRed'].toInt(),
            colorData['borderGreen'].toInt(),
            colorData['borderBlue'].toInt(),
            1,
          ),
        };
      }
    }

    setState(() {
      _buttonColors = colors;
    });
  }

  // Método helper para obtener el color de fondo de un botón
  Color _getButtonBackgroundColor(int index, bool isSunday) {
    final key = isSunday ? 'sunday_$index' : 'weekday_$index';
    if (_buttonColors.containsKey(key) &&
        _buttonColors[key]!.containsKey('background')) {
      return _buttonColors[key]!['background']!;
    }

    // Colores por defecto si no se han configurado
    if (isSunday) {
      switch (index) {
        case 0:
          return Colors.grey.shade400.withOpacity(0.70);
        case 1:
          return Colors.red.shade400.withOpacity(0.70);
        case 2:
          return Colors.green.shade400.withOpacity(0.70);
        case 3:
          return Colors.red.shade400.withOpacity(0.70);
        case 4:
          return Colors.red.shade400.withOpacity(0.70);
        case 5:
          return Colors.white.withOpacity(0.70);
        default:
          return Colors.grey.withOpacity(0.70);
      }
    } else {
      switch (index) {
        case 0:
          return Colors.red.shade400.withOpacity(0.70);
        case 1:
          return Colors.green.shade400.withOpacity(0.70);
        case 2:
          return Colors.blue.shade400.withOpacity(0.70);
        case 3:
          return Colors.blue.shade400.withOpacity(0.70);
        case 4:
          return Colors.green.shade400.withOpacity(0.70);
        case 5:
          return Colors.white.withOpacity(0.70);
        default:
          return Colors.grey.withOpacity(0.70);
      }
    }
  }

  // Método helper para obtener el color de borde de un botón
  Color _getButtonBorderColor(int index, bool isSunday) {
    final key = isSunday ? 'sunday_$index' : 'weekday_$index';
    if (_buttonColors.containsKey(key) &&
        _buttonColors[key]!.containsKey('border')) {
      return _buttonColors[key]!['border']!;
    }

    // Colores por defecto si no se han configurado
    if (isSunday) {
      switch (index) {
        case 0:
          return Colors.blue.shade300;
        case 1:
          return Colors.pink.shade300;
        case 2:
          return Colors.yellow.shade300;
        case 3:
          return Colors.pink.shade300;
        case 4:
          return Colors.pink.shade300;
        case 5:
          return Colors.black;
        default:
          return Colors.black;
      }
    } else {
      return Colors.black;
    }
  }

  Color _getOtrosButtonBackgroundColor(int index) {
    final key = 'otros_$index';
    if (_buttonColors.containsKey(key) &&
        _buttonColors[key]!.containsKey('background')) {
      return _buttonColors[key]!['background']!;
    }
    return Colors.orange.withOpacity(0.70);
  }

  Color _getOtrosButtonBorderColor(int index) {
    final key = 'otros_$index';
    if (_buttonColors.containsKey(key) &&
        _buttonColors[key]!.containsKey('border')) {
      return _buttonColors[key]!['border']!;
    }
    return Colors.black;
  }

  Future<void> _loadSumUpEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sumUpEnabled = prefs.getBool('sumUpEnabled') ?? true;
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

  // ==================== MÉTODOS DE COOLDOWN ====================

  void _activateCooldown() {
    if (mounted) {
      setState(() {
        _isButtonDisabled = true;
      });
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isButtonDisabled = false;
          });
        }
      });
    }
  }

  // ==================== MÉTODOS DE NAVEGACIÓN ====================

  void _navigateToReports() {
    _activateCooldown();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReporteCajaScreen()),
    ).then((_) {
      // Reactivar cooldown al volver de reportes
      _activateCooldown();
    });
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

  Widget _buildSectionHeader(String title) {
    return Container(
      height: 20,
      padding: EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            letterSpacing: 1.4,
          ),
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
                    'V25.05.26',
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
                    _activateCooldown();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => StatisticsScreen()),
                    ).then((_) => _activateCooldown());
                  },
                ),
                ListTile(
                  leading: Icon(Icons.swap_horiz_rounded,
                      color: Colors.purple.shade600),
                  title: Text('Transferencia'),
                  onTap: () {
                    Navigator.pop(context);
                    _activateCooldown();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TransferenciaScreen()),
                    ).then((_) => _activateCooldown());
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
                    _activateCooldown();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RecoveryReport()),
                    ).then((_) => _activateCooldown());
                  },
                ),
                ListTile(
                  leading:
                      Icon(Icons.backup_rounded, color: Colors.teal.shade600),
                  title: Text('Copias de Seguridad'),
                  onTap: () {
                    Navigator.pop(context);
                    _activateCooldown();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BackupScreen()),
                    ).then((_) => _activateCooldown());
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
    _activateCooldown();
    final settingsChanged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => Settings()),
    );

    if (settingsChanged == true) {
      print('Settings changed, reloading preferences');
      await _loadDisplayPreferences();
      await _loadSumUpEnabled();
      await _loadButtonColors();
      setState(() {});
    }
    // Reactivar cooldown al volver de settings
    _activateCooldown();
  }

  // ==================== MÉTODOS DE GENERACIÓN DE TICKETS ====================

  Future<void> _generateTicket(
      String tipo, double valor, bool isCorrespondencia) async {
    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    final autoClosingService = AutoClosingService();

    // Verificar y realizar auto-cierre si hay cambio de día
    final didAutoClose =
        await autoClosingService.checkAndAutoClose(reporteCaja);
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

    final comprobanteModel =
        Provider.of<ComprobanteModel>(context, listen: false);

    // Incrementar comprobante ANTES de cualquier escritura
    await comprobanteModel.incrementComprobante();
    final String currentComprobante = comprobanteModel.formattedComprobante;

    // ── Registro en caja (crítico, independiente de la impresión) ──────────
    try {
      await reporteCaja.receiveData(tipo, valor, currentComprobante);
    } catch (e) {
      print('Error crítico guardando en caja: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar venta. Contacte soporte.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      setState(() {
        _isButtonDisabled = false;
        _isLoading = false;
      });
      return;
    }

    // Actualizar fecha de última transacción y estado local
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

    // ── Impresión (independiente; un fallo no revierte la caja) ────────────
    try {
      await generateTicket.generateTicketPdf(
        context,
        valor,
        _switchValue,
        tipo,
        comprobanteModel,
        false,
        skipIncrement: true,
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket generado correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error de impresión: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Venta guardada. Error al imprimir ticket.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
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
  Future<void> _showPaymentMethodDialog(
      String tipo, double valor, bool isCorrespondencia) async {
    // Si SumUp está deshabilitado, generar ticket directamente con efectivo
    if (!_sumUpEnabled) {
      await _generateTicket(tipo, valor, isCorrespondencia);
      return;
    }

    // Si SumUp está habilitado, mostrar el diálogo de selección de método de pago
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
                        label: Text('Efectivo',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _generateTicket(tipo, valor, isCorrespondencia);
                        },
                      ),
                    ),
                  ),
                  // Botón Tarjeta - solo si está habilitado
                  if (_sumUpEnabled) ...[
                    SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.credit_card, size: 24),
                          label: Text('Tarjeta',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
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
                            _generateTicketConTarjeta(
                                tipo, valor, isCorrespondencia);
                          },
                        ),
                      ),
                    ),
                  ],
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
          // Generar el ticket (Fix 1: registra en caja ANTES de imprimir)
          setState(() {
            _isWaitingSumUp = false;
          });
          await _generateTicket(tipo, valor, isCorrespondencia);

          // Guardar pago con tarjeta DESPUÉS de confirmar registro en caja
          await PagoStorageService.guardarPagoTarjeta(
            monto: valor,
            txCode: txCode,
            fecha: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          );
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
                    Expanded(
                        child: Text('Pago con tarjeta rechazado o cancelado')),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Reintentar',
                  textColor: Colors.white,
                  onPressed: () async {
                    await _generateTicketConTarjeta(
                        tipo, valor, isCorrespondencia);
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

  // ==================== MÉTODOS DE NFC ====================

  Future<void> _checkNfcAvailability() async {
    bool available = await NfcManager.instance.isAvailable();
    if (mounted) {
      setState(() {
        _isNfcAvailable = available;
      });
    }
  }

  // ==================== MÉTODOS DE REIMPRESIÓN ====================

  void _handleReprint() async {
    // Activar cooldown al abrir diálogo
    _activateCooldown();

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

    // Pedir contraseña (ahora con NFC)
    bool ok = await showReprintPasswordDialog(
      context,
      HomeHelpers.loadPassword,
      _isNfcAvailable,
    );

    // Reactivar cooldown al cerrar diálogo
    _activateCooldown();

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
                      String comprobante) async {
                    await reporteCaja.addOfferEntries(
                        subtots, valor, comprobante);
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
    ).then((_) {
      // Reactivar cooldown al volver de cargo
      _activateCooldown();
    });
  }

  // ==================== DIÁLOGO DE ANULAR VENTA ====================

  Future<void> _showPasswordDialog() async {
    _activateCooldown();
    await showPasswordDialog(
      context,
      HomeHelpers.loadPassword,
      _cancelLastTransaction,
      _hasAnulado,
      _isNfcAvailable,
    );
    // Reactivar cooldown al cerrar diálogo
    _activateCooldown();
  }

  Future<void> _cancelLastTransaction() async {
    await HomeHelpers.cancelLastTransaction(context);

    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    await reporteCaja.cancelTransaction();

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
        preferredSize: Size.fromHeight(76),
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
                // ── Izquierda: menú ───────────────────────────────────
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
                  onOpenDrawer: () {
                    _activateCooldown();
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                // ── Logo ──────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Image.asset(
                    'assets/logo.png',
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 10),
                Consumer<ComprobanteModel>(
                  builder: (context, comprobanteModel, child) {
                    // Formatear el número con ceros a la izquierda (6 dígitos)
                    // Mostrar el próximo número a imprimir (+1)
                    final formattedNumber =
                        (comprobanteModel.comprobanteNumber + 1)
                            .toString()
                            .padLeft(6, '0');
                    return Container(
                      height: 40,
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
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
                          SizedBox(width: 6),
                          Text(
                            formattedNumber,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (hasPendingDays) ...[
                  SizedBox(width: 10),
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

                // ── Derecha: anular · reimprimir ───────────────────────
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
                  onOpenDrawer: () {
                    _activateCooldown();
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
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
                  onOpenDrawer: () {
                    _activateCooldown();
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                SizedBox(width: 6),
              ],
            ),
            titleSpacing: 0,
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(20),
              child: Container(
                width: double.infinity,
                height: 20,
                alignment: Alignment.center,
                child: Text(
                  '$_currentDay  ${DateFormat('dd/MM/yy').format(DateTime.now())}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
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
              SizedBox(height: 110),
              // Banner de advertencia si hay días pendientes
              if (hasPendingDays)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade100,
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hay un dia con ventas sin cerrar',
                          style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _navigateToReports,
                        style: TextButton.styleFrom(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Cerrar',
                            style: TextStyle(
                                fontSize: 11, color: Colors.red.shade900)),
                      ),
                    ],
                  ),
                ),

              // ── Banda de estado ──────────────────────────────────────
              Container(
                height: 56,
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TransactionCounterWidget(),
                    // Switch compacto modo tarifa
                    Tooltip(
                      message: _isAutoTarifa && _holidayReason != null
                          ? 'Auto detectado: $_holidayReason'
                          : _switchValue
                              ? 'Tarifa Domingo / Feriado'
                              : 'Tarifa Lunes a Sábado',
                      preferBelow: false,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: _isAutoTarifa
                              ? Border.all(
                                  color: Colors.amber.withOpacity(0.8),
                                  width: 1.2,
                                )
                              : null,
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Ícono auto (rayo) visible solo cuando fue detectado automáticamente
                            if (_isAutoTarifa)
                              Padding(
                                padding: const EdgeInsets.only(right: 3),
                                child: Icon(
                                  Icons.bolt,
                                  size: 12,
                                  color: Colors.amber,
                                ),
                              ),
                            Stack(
                              children: [
                                Text(
                                  _switchValue ? 'D/F' : 'L-S',
                                  style: TextStyle(
                                    fontFamily: 'Hemiheads',
                                    fontSize: textSize * 0.85,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 2
                                      ..color = Colors.black,
                                  ),
                                ),
                                Text(
                                  _switchValue ? 'D/F' : 'L-S',
                                  style: TextStyle(
                                    fontFamily: 'Hemiheads',
                                    fontSize: textSize * 0.85,
                                    color: _switchValue
                                        ? Colors.red
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _switchValue,
                              onChanged: (value) {
                                setState(() {
                                  _switchValue = value;
                                  // Al cambiar manualmente, desactivar modo auto
                                  _isAutoTarifa = false;
                                  _holidayReason = null;
                                });
                              },
                              activeColor: Colors.red,
                              activeTrackColor: Colors.red.withOpacity(0.5),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Botones de venta ─────────────────────────────────────
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      buttonHeight / 4,
                      0,
                      buttonHeight / 4,
                      buttonHeight / 2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ─── PASAJEROS (izq) | INTERMEDIO (der) ──────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Columna PASAJEROS ──────────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSectionHeader('PASAJEROS'),
                                  SizedBox(height: 3),
                                  SizedBox(
                                    height: buttonHeight,
                                    child: HomeButtons.buildConfigurableButton(
                                      context: context,
                                      text: pasajes[0]['nombre'],
                                      icon: Icons.people,
                                      backgroundColor:
                                          _getButtonBackgroundColor(
                                              0, _switchValue),
                                      borderColor: _getButtonBorderColor(
                                          0, _switchValue),
                                      onPressed: () async {
                                        await _showPaymentMethodDialog(
                                            pasajes[0]['nombre'],
                                            pasajes[0]['precio'],
                                            false);
                                      },
                                      showIcons: _showIcons,
                                      textSizeMultiplier: _textSizeMultiplier,
                                      buttonIcons: _buttonIcons,
                                      isDisabled:
                                          _isButtonDisabled || hasPendingDays,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  SizedBox(
                                    height: buttonHeight,
                                    child: HomeButtons.buildConfigurableButton(
                                      context: context,
                                      text: pasajes[1]['nombre'],
                                      icon: Icons.school,
                                      backgroundColor:
                                          _getButtonBackgroundColor(
                                              1, _switchValue),
                                      borderColor: _getButtonBorderColor(
                                          1, _switchValue),
                                      onPressed: () async {
                                        await _showPaymentMethodDialog(
                                            pasajes[1]['nombre'],
                                            pasajes[1]['precio'],
                                            false);
                                      },
                                      showIcons: _showIcons,
                                      textSizeMultiplier: _textSizeMultiplier,
                                      buttonIcons: _buttonIcons,
                                      isDisabled:
                                          _isButtonDisabled || hasPendingDays,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  SizedBox(
                                    height: buttonHeight,
                                    child: HomeButtons.buildConfigurableButton(
                                      context: context,
                                      text: pasajes[2]['nombre'],
                                      icon: Icons.elderly,
                                      backgroundColor:
                                          _getButtonBackgroundColor(
                                              2, _switchValue),
                                      borderColor: _getButtonBorderColor(
                                          2, _switchValue),
                                      onPressed: () async {
                                        await _showPaymentMethodDialog(
                                            pasajes[2]['nombre'],
                                            pasajes[2]['precio'],
                                            false);
                                      },
                                      showIcons: _showIcons,
                                      textSizeMultiplier: _textSizeMultiplier,
                                      buttonIcons: _buttonIcons,
                                      isDisabled:
                                          _isButtonDisabled || hasPendingDays,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            // ── Columna INTERMEDIO ─────────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSectionHeader('INTERMEDIO'),
                                  SizedBox(height: 3),
                                  SizedBox(
                                    height: buttonHeight,
                                    child: HomeButtons.buildConfigurableButton(
                                      context: context,
                                      text: pasajes[4]['nombre'],
                                      icon: Icons.map,
                                      backgroundColor:
                                          _getButtonBackgroundColor(
                                              4, _switchValue),
                                      borderColor: _getButtonBorderColor(
                                          4, _switchValue),
                                      onPressed: () async {
                                        await _showPaymentMethodDialog(
                                            pasajes[4]['nombre'],
                                            pasajes[4]['precio'],
                                            false);
                                      },
                                      showIcons: _showIcons,
                                      textSizeMultiplier: _textSizeMultiplier,
                                      buttonIcons: _buttonIcons,
                                      isDisabled:
                                          _isButtonDisabled || hasPendingDays,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  SizedBox(
                                    height: buttonHeight,
                                    child: HomeButtons.buildConfigurableButton(
                                      context: context,
                                      text: pasajes[3]['nombre'],
                                      icon: Icons.directions_bus,
                                      backgroundColor:
                                          _getButtonBackgroundColor(
                                              3, _switchValue),
                                      borderColor: _getButtonBorderColor(
                                          3, _switchValue),
                                      onPressed: () async {
                                        await _showPaymentMethodDialog(
                                            pasajes[3]['nombre'],
                                            pasajes[3]['precio'],
                                            false);
                                      },
                                      showIcons: _showIcons,
                                      textSizeMultiplier: _textSizeMultiplier,
                                      buttonIcons: _buttonIcons,
                                      isDisabled:
                                          _isButtonDisabled || hasPendingDays,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  SizedBox(
                                    height: buttonHeight,
                                    child: HomeButtons.buildConfigurableButton(
                                      context: context,
                                      text: pasajes.length > 5
                                          ? pasajes[5]['nombre']
                                          : 'Escolar Intermedio',
                                      icon: Icons.school_outlined,
                                      backgroundColor:
                                          _getButtonBackgroundColor(
                                              5, _switchValue),
                                      borderColor: _getButtonBorderColor(
                                          5, _switchValue),
                                      textColor: Colors.black,
                                      onPressed: () async {
                                        if (pasajes.length > 5) {
                                          await _showPaymentMethodDialog(
                                              pasajes[5]['nombre'],
                                              pasajes[5]['precio'],
                                              false);
                                        } else {
                                          double defaultPrice =
                                              _switchValue ? 1300.0 : 1000.0;
                                          await _showPaymentMethodDialog(
                                              'Escolar Intermedio',
                                              defaultPrice,
                                              false);
                                          print(
                                              'ADVERTENCIA: No se encontró Escolar Intermedio en la posición 5. Usando precio por defecto: $defaultPrice');
                                        }
                                      },
                                      showIcons: _showIcons,
                                      textSizeMultiplier: _textSizeMultiplier,
                                      buttonIcons: _buttonIcons,
                                      isDisabled:
                                          _isButtonDisabled || hasPendingDays,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),

                        // ─── Sección OTROS ───────────────────────────────
                        _buildSectionHeader('OTROS'),
                        SizedBox(height: 3),
                        SizedBox(
                          height: buttonHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: HomeButtons.buildConfigurableButton(
                                  context: context,
                                  text: 'O F E R T A',
                                  icon: Icons.local_offer,
                                  backgroundColor: hasPendingDays
                                      ? Colors.grey.shade300
                                      : _getOtrosButtonBackgroundColor(0),
                                  borderColor: hasPendingDays
                                      ? Colors.grey
                                      : _getOtrosButtonBorderColor(0),
                                  textColor: Colors.black,
                                  onPressed: _showMultiOfferDialog,
                                  showIcons: _showIcons,
                                  textSizeMultiplier: _textSizeMultiplier,
                                  buttonIcons: _buttonIcons,
                                  isDisabled:
                                      _isButtonDisabled || hasPendingDays,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: HomeButtons.buildConfigurableButton(
                                  context: context,
                                  text: 'C A R G O',
                                  icon: Icons.inventory,
                                  textColor: Colors.black,
                                  backgroundColor:
                                      _isButtonDisabled || hasPendingDays
                                          ? Colors.grey
                                          : _getOtrosButtonBackgroundColor(1),
                                  borderColor:
                                      _isButtonDisabled || hasPendingDays
                                          ? Colors.grey.shade600
                                          : _getOtrosButtonBorderColor(1),
                                  onPressed: _showOfferDialog,
                                  showIcons: _showIcons,
                                  textSizeMultiplier: _textSizeMultiplier,
                                  buttonIcons: _buttonIcons,
                                  isDisabled:
                                      _isButtonDisabled || hasPendingDays,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
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
