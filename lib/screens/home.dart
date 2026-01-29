import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'cargo_screen.dart';
import '../services/pdf/generateCargo_Ticket.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'reporte_caja_screen.dart';
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

  // Configuración del AppBar
  List<Map<String, dynamic>> _appBarSlots =
      List.generate(8, (index) => {'isEmpty': true, 'element': null});

  // Variables para la configuración de botones
  bool _showIcons = true;
  double _textSizeMultiplier = 0.8;
  double _iconSpacing = 1.0;
  Map<String, IconData> _buttonIcons = {};

  // Variables para la función de reimpresión
  Map<String, dynamic>? _lastTransaction;
  bool _isReprinting = false;

  @override
  void initState() {
    super.initState();

    // Inicializar servicios
    _pendingTransactionService = PendingTransactionService();
    _resourcePreloader = ResourcePreloader(
      pdfOptimizer: pdfOptimizer,
      generateTicket: generateTicket,
    );

    _initializeLocalization();
    _updateDay();
    _timer = Timer.periodic(Duration(milliseconds: 250), (timer) {
      _updateDay();
    });
    _isPhoneMode = true;

    // Iniciar precarga de recursos inmediatamente y en segundo plano
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

    _loadLastTransaction();
    _loadDisplayPreferences();
    _loadIconSettings();
    _loadAppBarConfig();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDisplayPreferences();
    _loadIconSettings();
    _loadAppBarConfig();
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
    super.dispose();
  }

  // ==================== MÉTODOS DE CARGA DE CONFIGURACIÓN ====================

  Future<void> _loadAppBarConfig() async {
    final loadedConfig = await HomeHelpers.loadAppBarConfig();
    setState(() {
      _appBarSlots = loadedConfig;
    });
  }

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

    // Verificar transacciones pendientes del día anterior
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
      extendBodyBehindAppBar: true,
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
                    .withValues(alpha: 0.4),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Badge de alerta si hay días pendientes
                if (hasPendingDays)
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
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
                // Slots del AppBar usando el widget modular
                ...List.generate(_appBarSlots.length, (index) {
                  return HomeAppBarWidgets.buildAppBarSlotWidget(
                    context: context,
                    slot: _appBarSlots[index],
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
                  );
                }),
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
              SizedBox(height: 56),
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
                                      activeThumbColor: Colors.red,
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
                                _generateTicket(pasajes[0]['nombre'],
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
                                _generateTicket(pasajes[4]['nombre'],
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
                                _generateTicket(pasajes[1]['nombre'],
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
                                _generateTicket(pasajes[3]['nombre'],
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
                                _generateTicket(pasajes[2]['nombre'],
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
                                  _generateTicket(pasajes[5]['nombre'],
                                      pasajes[5]['precio'], false);
                                } else {
                                  double defaultPrice =
                                      _switchValue ? 1300.0 : 1000.0;
                                  _generateTicket('Escolar Intermedio',
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
        ],
      ),
    );
  }
}
