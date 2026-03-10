import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/ticket_model.dart';
import '../models/sunday_ticket_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_screen.dart';
import '../models/ComprobanteModelSettings.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'button_color_settings_screen.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings>
    with SingleTickerProviderStateMixin {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController idController = TextEditingController();
  bool isAuthenticated = false;
  double _textSizeMultiplier = 0.8;
  bool _showIcons = true;
  double _buttonOpacity = 1.0; // Transparencia de los botones (0.0 - 1.0)
  double _pdfEndMargin = 69.0; // Valor por defecto
  bool _isNfcAvailable = false;
  bool _isReadingNfc = false;
  String _nfcStatus = '';
  // NFC para autenticación de acceso a configuración
  bool _isNfcAuthReading = false;
  String _nfcAuthStatus = '';
  List<String> _linkedNfcCards = [];
  // Control para habilitar/deshabilitar pagos con tarjeta SumUp
  bool _sumUpEnabled = true;
  // Controller para el affiliate key de SumUp
  final TextEditingController _sumUpAffiliateKeyController = TextEditingController();

  Future<bool> _showComprobanteAuthDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final basePwd = passwordController.text; // tu contraseña actual de Settings
    final reversed = basePwd.split('').reversed.join();
    final allowed = prefs.getString('comprobanteSettingsPassword') ?? reversed;
    String entry = '';

    return (await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text('Autenticación - N° Comprobante'),
              content: TextField(
                onChanged: (v) => entry = v,
                decoration: InputDecoration(
                  labelText: 'Contraseña (6 dígitos)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (entry == allowed) {
                      Navigator.pop(ctx, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Contraseña incorrecta')));
                    }
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  // State variable for icon spacing
  double _iconSpacing = 1.0;

  // Map to store icon selections for each button type
  final Map<String, String> _buttonIcons = {
    'Público General': 'people',
    'Escolar General': 'school',
    'Adulto Mayor': 'elderly',
    'Int. hasta 15 Km': 'directions_bus',
    'Int. hasta 50 Km': 'map',
    'Escolar Intermedio': 'school_outlined',
    'Oferta Ruta': 'local_offer',
    'Cargo': 'inventory',
  };

  // Available icons for selection
  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'Personas', 'icon': Icons.people},
    {'name': 'Escuela', 'icon': Icons.school},
    {'name': 'Escuela (Alt)', 'icon': Icons.school_outlined},
    {'name': 'Adulto Mayor', 'icon': Icons.elderly},
    {'name': 'Bus', 'icon': Icons.directions_bus},
    {'name': 'Mapa', 'icon': Icons.map},
    {'name': 'Oferta', 'icon': Icons.local_offer},
    {'name': 'Inventario', 'icon': Icons.inventory},
    {'name': 'Ticket', 'icon': Icons.confirmation_number},
    {'name': 'Recibo', 'icon': Icons.receipt},
    {'name': 'Dinero', 'icon': Icons.attach_money},
    {'name': 'Correo', 'icon': Icons.mail},
  ];

  // Flag to track if settings have changed
  bool _settingsChanged = false;

  final String appVersion = 'V.05.03.26';

  // Variables para TabController
  late TabController _tabController;

  // Colores de la aplicación - Paleta naranja empresarial moderna
  final Color primaryColor = Color(0xFFFF6B35); // Naranja vibrante
  final Color primaryLight = Color(0xFFFF8C61); // Naranja claro
  final Color primaryDark = Color(0xFFE55428); // Naranja oscuro
  final Color accentColor = Color(0xFFF7931E); // Naranja dorado
  final Color backgroundColor = Color(0xFFFAFAFA);
  final Color cardColor = Colors.white;
  final Color textColor = Colors.black87;
  final Color buttonColor = Color(0xFFFF6B35);

  // Variables para las abreviaturas
  final Map<String, String> _abbreviations = {
    'Público General': 'PG',
    'Escolar General': 'Esc.',
    'Adulto Mayor': 'AM',
    'Escolar Intermedio': 'Int.E',
    'Intermedio hasta 15 Km': 'Int.15',
    'Intermedio hasta 50 Km': 'Int.50',
    'Oferta Ruta': 'OR',
    'Cargo': 'Cargo',
  };

  final Map<String, TextEditingController> _abbreviationControllers = {};

  @override
  void initState() {
    super.initState();
    _loadId();
    _loadDisplayPreferences();
    _loadAbbreviations();
    _loadButtonIconPreferences();
    _loadPdfEndMargin(); // Agregar esta línea
    _checkNfcAvailability();
    _loadLinkedNfcCards();
    _loadSumUpEnabled();
    _loadSumUpAffiliateKey();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    if (_isNfcAuthReading) {
      NfcManager.instance.stopSession();
    }
    _tabController.dispose();
    passwordController.dispose();
    idController.dispose();
    _sumUpAffiliateKeyController.dispose();
    for (var controller in _abbreviationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'people':
        return Icons.people;
      case 'school':
        return Icons.school;
      case 'school_outlined':
        return Icons.school_outlined;
      case 'elderly':
        return Icons.elderly;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'map':
        return Icons.map;
      case 'local_offer':
        return Icons.local_offer;
      case 'inventory':
        return Icons.inventory;
      case 'confirmation_number':
        return Icons.confirmation_number;
      case 'receipt':
        return Icons.receipt;
      case 'attach_money':
        return Icons.attach_money;
      case 'mail':
        return Icons.mail;
      default:
        return Icons.error;
    }
  }

  // Function to get string name from IconData
  String _getStringFromIcon(IconData icon) {
    if (icon == Icons.people) return 'people';
    if (icon == Icons.school) return 'school';
    if (icon == Icons.school_outlined) return 'school_outlined';
    if (icon == Icons.elderly) return 'elderly';
    if (icon == Icons.directions_bus) return 'directions_bus';
    if (icon == Icons.map) return 'map';
    if (icon == Icons.local_offer) return 'local_offer';
    if (icon == Icons.inventory) return 'inventory';
    if (icon == Icons.confirmation_number) return 'confirmation_number';
    if (icon == Icons.receipt) return 'receipt';
    if (icon == Icons.attach_money) return 'attach_money';
    if (icon == Icons.mail) return 'mail';
    return 'error';
  }

  // Method to load button icons and spacing preferences
  Future<void> _loadButtonIconPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _iconSpacing = prefs.getDouble('iconSpacing') ?? 2.0;

        // Load button icons
        final Map<String, dynamic>? savedIcons =
            prefs.getString('buttonIcons') != null
                ? json.decode(prefs.getString('buttonIcons')!)
                : null;

        if (savedIcons != null) {
          savedIcons.forEach((key, value) {
            _buttonIcons[key] = value.toString();
          });
        }
      });
      print('Button icon preferences loaded: spacing=$_iconSpacing');
    } catch (e) {
      print('Error loading button icon preferences: $e');
    }
  }

  // Method to save button icons and spacing preferences
  Future<void> _saveButtonIconPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('iconSpacing', _iconSpacing);
      await prefs.setString('buttonIcons', json.encode(_buttonIcons));

      // Set flag that settings have changed
      _settingsChanged = true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Preferencias de iconos guardadas'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
      print('Button icon preferences saved: spacing=$_iconSpacing');
    } catch (e) {
      print('Error saving button icon preferences: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar preferencias de iconos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to show icon selection dialog
  void _showIconSelectionDialog(String buttonName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleccionar Ícono para "$buttonName"'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: _availableIcons.length,
              itemBuilder: (context, index) {
                final iconInfo = _availableIcons[index];
                final bool isSelected = _buttonIcons[buttonName] ==
                    _getStringFromIcon(iconInfo['icon']);

                return InkWell(
                  onTap: () {
                    setState(() {
                      _buttonIcons[buttonName] =
                          _getStringFromIcon(iconInfo['icon']);
                    });
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor.withOpacity(0.2)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: primaryColor, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          iconInfo['icon'],
                          size: 30,
                          color: isSelected ? primaryColor : Colors.grey[700],
                        ),
                        SizedBox(height: 5),
                        Text(
                          iconInfo['name'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? primaryColor : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  // Método para cargar las abreviaturas
  Future<void> _loadAbbreviations() async {
    final prefs = await SharedPreferences.getInstance();

    // Inicializar controladores para cada abreviatura
    for (var key in _abbreviations.keys) {
      String value = prefs.getString(key) ?? _abbreviations[key]!;
      _abbreviations[key] = value; // Actualizar el mapa con el valor guardado
      _abbreviationControllers[key] = TextEditingController(text: value);
    }

    setState(() {});
  }

  // Método para guardar las abreviaturas
  Future<void> _saveAbbreviations() async {
    final prefs = await SharedPreferences.getInstance();

    // Guardar cada abreviatura
    for (var key in _abbreviations.keys) {
      String abbreviation =
          _abbreviationControllers[key]?.text ?? _abbreviations[key]!;
      _abbreviations[key] = abbreviation; // Actualizar el mapa
      await prefs.setString(key, abbreviation);
    }

    // Indicar que se han cambiado las configuraciones
    _settingsChanged = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Abreviaturas guardadas correctamente'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _loadDisplayPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _showIcons = prefs.getBool('showIcons') ?? true;
        _textSizeMultiplier = prefs.getDouble('textSizeMultiplier') ?? 0.8;
        _buttonOpacity = prefs.getDouble('buttonOpacity') ?? 1.0;
      });
      print(
          'Settings loaded: showIcons=$_showIcons, textSizeMultiplier=$_textSizeMultiplier, buttonOpacity=$_buttonOpacity');
    } catch (e) {
      print('Error al cargar preferencias de visualización: $e');
    }
  }

  Future<void> _saveDisplayPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Debug print to see what we're saving
      print(
          'Saving settings: showIcons=$_showIcons, textSizeMultiplier=$_textSizeMultiplier, buttonOpacity=$_buttonOpacity');

      // Use await to ensure the values are actually saved
      await prefs.setBool('showIcons', _showIcons);
      await prefs.setDouble('textSizeMultiplier', _textSizeMultiplier);
      await prefs.setDouble('buttonOpacity', _buttonOpacity);

      // Debug print to confirm values are saved
      print('Settings saved. Verifying...');
      bool? savedIcons = prefs.getBool('showIcons');
      double? savedSize = prefs.getDouble('textSizeMultiplier');
      double? savedOpacity = prefs.getDouble('buttonOpacity');
      print('Verified: showIcons=$savedIcons, textSizeMultiplier=$savedSize, buttonOpacity=$savedOpacity');

      // Set flag that settings have changed
      _settingsChanged = true;

      // Notificar a los usuarios inmediatamente
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Preferencias de visualización guardadas'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      print('Error al guardar preferencias de visualización: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar preferencias: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadId() async {
    final prefs = await SharedPreferences.getInstance();
    int ticketId = prefs.getInt('ticketId') ?? 1;
    idController.text = ticketId.toString();
  }

  Future<void> _saveId() async {
    final prefs = await SharedPreferences.getInstance();
    int newId = int.tryParse(idController.text) ?? 1;

    if (newId >= 1 && newId <= 99) {
      await prefs.setInt('ticketId', newId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('ID guardado: $newId'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('Por favor, ingrese un ID válido (1-99)'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetComprobanteCounter() async {
    // Mostrar diálogo de confirmación
    bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 10),
                  Text('Confirmar reinicio'),
                ],
              ),
              content: Text(
                  '¿Está seguro que desea reiniciar el contador de comprobantes?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: Text('Reiniciar'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('comprobanteNumber', 1);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.refresh, color: Colors.white),
              SizedBox(width: 10),
              Text('Contador de comprobantes reiniciado'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<String> _loadPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('password') ?? '123456';
  }

  Future<void> _savePassword(String newPassword) async {
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('La contraseña debe tener 6 dígitos'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('password', newPassword);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Contraseña actualizada correctamente'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  void _authenticate() async {
    String storedPassword = await _loadPassword();
    if (passwordController.text == storedPassword) {
      setState(() {
        isAuthenticated = true;
      });
      _loadId();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('Contraseña incorrecta'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkNfcAvailability() async {
    bool available = await NfcManager.instance.isAvailable();
    setState(() {
      _isNfcAvailable = available;
    });
    // Auto-iniciar lectura NFC para autenticación si aún no está autenticado
    if (available && !isAuthenticated) {
      _startNfcAuthReading();
    }
  }

  Future<void> _loadLinkedNfcCards() async {
    final prefs = await SharedPreferences.getInstance();
    final cardsJson = prefs.getString('linked_nfc_cards') ?? '[]';
    setState(() {
      _linkedNfcCards = List<String>.from(json.decode(cardsJson));
    });
  }

  Future<void> _saveLinkedNfcCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('linked_nfc_cards', json.encode(_linkedNfcCards));
  }

  Future<void> _startNfcLinking() async {
    if (!_isNfcAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('NFC no está disponible en este dispositivo'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isReadingNfc = true;
      _nfcStatus = 'Acerca la tarjeta NFC para vincularla...';
    });

    try {
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          final nfcTag = NfcTagAndroid.from(tag);
          if (nfcTag != null) {
            final tagId = nfcTag.id;
            final tagIdHex = tagId
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(':')
                .toUpperCase();

            await NfcManager.instance.stopSession();

            setState(() {
              _isReadingNfc = false;
              if (!_linkedNfcCards.contains(tagIdHex)) {
                _linkedNfcCards.add(tagIdHex);
                _nfcStatus = 'Tarjeta vinculada: $tagIdHex';
              } else {
                _nfcStatus = 'Esta tarjeta ya está vinculada: $tagIdHex';
              }
            });

            await _saveLinkedNfcCards();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text('Tarjeta NFC vinculada: $tagIdHex')),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );

            await Future.delayed(const Duration(seconds: 2));
            setState(() {
              _nfcStatus = '';
            });
          } else {
            await NfcManager.instance.stopSession();
            setState(() {
              _isReadingNfc = false;
              _nfcStatus = 'No se pudo leer la tarjeta';
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _isReadingNfc = false;
        _nfcStatus = 'Error: $e';
      });
    }
  }

  Future<void> _stopNfcLinking() async {
    await NfcManager.instance.stopSession();
    setState(() {
      _isReadingNfc = false;
      _nfcStatus = '';
    });
  }

  // ── NFC Autenticación de acceso ────────────────────────────────────────────

  Future<void> _startNfcAuthReading() async {
    if (!_isNfcAvailable || _isNfcAuthReading) return;
    if (mounted) {
      setState(() {
        _isNfcAuthReading = true;
        _nfcAuthStatus = 'Acerca la tarjeta NFC...';
      });
    }
    try {
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          final nfcTag = NfcTagAndroid.from(tag);
          if (nfcTag != null) {
            final tagId = nfcTag.id;
            final tagIdHex = tagId
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(':')
                .toUpperCase();
            // Cargar tarjetas autorizadas desde SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            final cardsJson = prefs.getString('linked_nfc_cards') ?? '[]';
            final List<String> authorizedIds =
                List<String>.from(json.decode(cardsJson));
            final bool isAuthorized =
                authorizedIds.isEmpty || authorizedIds.contains(tagIdHex);
            if (isAuthorized) {
              await NfcManager.instance.stopSession();
              if (mounted) {
                setState(() {
                  _isNfcAuthReading = false;
                  _nfcAuthStatus = '';
                  isAuthenticated = true;
                });
                _loadId();
              }
            } else {
              if (mounted) {
                setState(() {
                  _nfcAuthStatus = 'Tarjeta no autorizada';
                });
              }
              await Future.delayed(const Duration(seconds: 2));
              await NfcManager.instance.stopSession();
              if (mounted) {
                setState(() {
                  _isNfcAuthReading = false;
                  _nfcAuthStatus = '';
                });
                _startNfcAuthReading();
              }
            }
          } else {
            await NfcManager.instance.stopSession();
            if (mounted) {
              setState(() {
                _isNfcAuthReading = false;
                _nfcAuthStatus = 'No se pudo leer la tarjeta';
              });
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isNfcAuthReading = false;
          _nfcAuthStatus = 'Error NFC: $e';
        });
      }
    }
  }

  Future<void> _stopNfcAuthReading() async {
    await NfcManager.instance.stopSession();
    if (mounted) {
      setState(() {
        _isNfcAuthReading = false;
        _nfcAuthStatus = '';
      });
    }
  }

  Future<void> _removeNfcCard(String cardId) async {
    setState(() {
      _linkedNfcCards.remove(cardId);
    });
    await _saveLinkedNfcCards();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Tarjeta NFC desvinculada'),
          ],
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _loadSumUpEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sumUpEnabled = prefs.getBool('sumUpEnabled') ?? true;
    });
  }

  Future<void> _loadSumUpAffiliateKey() async {
    final prefs = await SharedPreferences.getInstance();
    final affiliateKey = prefs.getString('sumup_affiliate_key') ?? 
        'sup_afk_BydGVQ41DbNaM3Mm441GRPxon06MIkXu'; // Valor por defecto
    _sumUpAffiliateKeyController.text = affiliateKey;
  }

  Future<void> _saveSumUpAffiliateKey() async {
    final prefs = await SharedPreferences.getInstance();
    final newKey = _sumUpAffiliateKeyController.text.trim();
    
    if (newKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('El Affiliate Key no puede estar vacío'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    await prefs.setString('sumup_affiliate_key', newKey);
    _settingsChanged = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Affiliate Key guardado correctamente'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _saveSumUpEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sumUpEnabled', value);
    setState(() {
      _sumUpEnabled = value;
    });

    // Set flag that settings have changed
    _settingsChanged = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text(value
                ? 'Pago con tarjeta habilitado'
                : 'Pago con tarjeta deshabilitado'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // When navigating back, if settings have changed, return true
        // to indicate changes to home screen
        Navigator.pop(context, _settingsChanged);
        return false; // Prevent default back action since we handle it manually
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.settings_rounded, size: 24),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Configuración',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Sistema POS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          elevation: 0,
          actions: [
            if (!isAuthenticated && _isNfcAvailable)
              Container(
                margin: EdgeInsets.only(right: 4),
                child: IconButton(
                  icon: Icon(
                    _isNfcAuthReading ? Icons.nfc : Icons.nfc_outlined,
                  ),
                  tooltip: _isNfcAuthReading
                      ? 'Detener lectura NFC'
                      : 'Leer tarjeta NFC',
                  onPressed: _isNfcAuthReading
                      ? _stopNfcAuthReading
                      : _startNfcAuthReading,
                ),
              ),
            if (isAuthenticated)
              Container(
                margin: EdgeInsets.only(right: 12),
                child: IconButton(
                  icon: Icon(Icons.logout_rounded),
                  tooltip: 'Cerrar sesión',
                  onPressed: () {
                    setState(() {
                      isAuthenticated = false;
                      passwordController.clear();
                    });
                    // Reiniciar lectura NFC de autenticación
                    if (_isNfcAvailable) _startNfcAuthReading();
                  },
                ),
              ),
          ],
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              // Pass the _settingsChanged flag when popping
              Navigator.pop(context, _settingsChanged);
            },
          ),
        ),
        body: isAuthenticated
            ? _buildSettingsContent()
            : _buildAuthenticationForm(),
      ),
    );
  }

  Widget _buildAuthenticationForm() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primaryColor, Colors.amber[100]!],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.security,
                    size: 60,
                    color: primaryColor,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Ingrese la Contraseña',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña (6 dígitos)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.password, color: primaryColor),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, letterSpacing: 8),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        'Ingresar',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // ── Sección NFC ──────────────────────────────────────────
                  if (_isNfcAvailable) ...[
                    SizedBox(height: 24),
                    Divider(),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.nfc, color: primaryColor, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Acceso rápido con NFC',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      width: double.infinity,
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: _isNfcAuthReading
                            ? primaryColor.withOpacity(0.12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isNfcAuthReading
                              ? primaryColor
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_isNfcAuthReading)
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                            )
                          else
                            Icon(Icons.nfc_outlined,
                                color: Colors.grey, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _nfcAuthStatus.isEmpty
                                  ? 'Lectura NFC inactiva'
                                  : _nfcAuthStatus,
                              style: TextStyle(
                                fontSize: 13,
                                color: _isNfcAuthReading
                                    ? primaryColor
                                    : Colors.grey,
                                fontWeight: _isNfcAuthReading
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        icon: Icon(
                          _isNfcAuthReading ? Icons.stop : Icons.play_arrow,
                          size: 18,
                        ),
                        label: Text(
                          _isNfcAuthReading
                              ? 'Detener lectura'
                              : 'Iniciar lectura NFC',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isNfcAuthReading
                            ? _stopNfcAuthReading
                            : _startNfcAuthReading,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    final ticketModel = Provider.of<TicketModel>(context);
    final sundayTicketModel = Provider.of<SundayTicketModel>(context);

    return Column(
      children: [
        // Tabs modernizadas con diseño material
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryDark, primaryColor],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            labelColor: primaryColor,
            unselectedLabelColor: Colors.white.withOpacity(0.8),
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(
                icon: Icon(Icons.tune_rounded, size: 22),
                text: 'General',
                height: 65,
              ),
              Tab(
                icon: Icon(Icons.payments_rounded, size: 22),
                text: 'Precios',
                height: 65,
              ),
              Tab(
                icon: Icon(Icons.palette_rounded, size: 22),
                text: 'Apariencia',
                height: 65,
              ),
              Tab(
                icon: Icon(Icons.notes_rounded, size: 22),
                text: 'Abreviaturas',
                height: 65,
              ),
            ],
          ),
        ),

        // Contenido de las tabs
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Pestaña 1: Configuración General
              _buildGeneralSettings(),

              // Pestaña 2: Configuración de Precios
              _buildPriceSettings(ticketModel, sundayTicketModel),

              // Pestaña 3: Configuración de Apariencia
              _buildAppearanceSettings(),

              // Pestaña 4: Configuración de Abreviaturas
              _buildAbbreviationSettings(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'ID de Terminal',
            icon: Icons.tag,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identificador único para este dispositivo (1-99)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: idController,
                          decoration: InputDecoration(
                            labelText: 'ID',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _saveId,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: EdgeInsets.symmetric(
                              vertical: 15, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),
          _buildSectionCard(
            title: 'N° Comprobante',
            icon: Icons.confirmation_number,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Reinicia aquí el contador de comprobantes.'),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (await _showComprobanteAuthDialog()) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ComprobanteModelSettings()),
                        );
                      }
                    },
                    child: Text('Reiniciar Contador'),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildSectionCard(
            title: 'Tarjetas NFC Vinculadas',
            icon: Icons.nfc,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Vincula tarjetas NFC para acceso rápido al sistema',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  if (_nfcStatus.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: primaryColor),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _nfcStatus,
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_nfcStatus.isNotEmpty) SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isReadingNfc
                              ? _stopNfcLinking
                              : _startNfcLinking,
                          icon: Icon(_isReadingNfc ? Icons.stop : Icons.add),
                          label: Text(
                              _isReadingNfc ? 'Detener' : 'Vincular Tarjeta'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isReadingNfc ? Colors.red : buttonColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (_linkedNfcCards.isEmpty)
                    Center(
                      child: Text(
                        'No hay tarjetas vinculadas',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._linkedNfcCards
                        .map((cardId) => Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(Icons.nfc, color: primaryColor),
                                title: Text(cardId),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeNfcCard(cardId),
                                ),
                              ),
                            ))
                        .toList(),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildSectionCard(
            title: 'Margen Final PDF',
            icon: Icons.picture_as_pdf,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajuste el margen antes de la línea negra final en los PDFs',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Margen: ${_pdfEndMargin.toInt()}px',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Slider(
                              value: _pdfEndMargin,
                              min: 10,
                              max: 150,
                              divisions: 14,
                              label: '${_pdfEndMargin.toInt()}px',
                              activeColor: primaryColor,
                              onChanged: (value) {
                                setState(() {
                                  _pdfEndMargin = value;
                                });
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('10px',
                                    style: TextStyle(color: Colors.grey[600])),
                                Text('Default: 69px',
                                    style: TextStyle(color: Colors.grey[600])),
                                Text('150px',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _savePdfEndMargin,
                      icon: Icon(Icons.save),
                      label: Text('Guardar Margen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildBackupRestoreSection(),
          SizedBox(height: 20),

          _buildSectionCard(
            title: 'Seguridad',
            icon: Icons.security,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cambiar contraseña de acceso (6 dígitos)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Nueva Contraseña',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.password),
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, letterSpacing: 8),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _savePassword(passwordController.text);
                      },
                      icon: Icon(Icons.save),
                      label: Text('Guardar Contraseña'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          _buildSectionCard(
            title: 'Métodos de Pago',
            icon: Icons.payment,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Habilita o deshabilita los pagos con tarjeta SumUp',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        'Pago con Tarjeta (SumUp)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        _sumUpEnabled
                            ? 'Los usuarios podrán pagar con tarjeta'
                            : 'Solo se permitirá pago en efectivo',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _sumUpEnabled,
                      activeColor: primaryColor,
                      onChanged: (bool value) {
                        _saveSumUpEnabled(value);
                      },
                      secondary: Icon(
                        _sumUpEnabled
                            ? Icons.credit_card
                            : Icons.credit_card_off,
                        color: _sumUpEnabled ? primaryColor : Colors.grey,
                        size: 32,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  if (!_sumUpEnabled)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700]),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El botón de pago con tarjeta estará oculto en la pantalla principal',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          _buildSectionCard(
            title: 'Configuración SumUp',
            icon: Icons.credit_card,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configura el Affiliate Key de tu cuenta SumUp',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _sumUpAffiliateKeyController,
                    decoration: InputDecoration(
                      labelText: 'Affiliate Key',
                      hintText: 'sup_afk_...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.key),
                      helperText: 'Ingrese su Affiliate Key de SumUp',
                      helperMaxLines: 2,
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveSumUpAffiliateKey,
                      icon: Icon(Icons.save),
                      label: Text('Guardar Affiliate Key'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'El Affiliate Key se usa para identificar tu cuenta en las transacciones con SumUp. Puedes obtenerlo desde tu dashboard de SumUp.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Version information added at the bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Versión de la Aplicación: $appVersion',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSettings(
      TicketModel ticketModel, SundayTicketModel sundayTicketModel) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Precios Lunes a Sábado',
            icon: Icons.calendar_today,
            child: ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: ticketModel.pasajes.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: _getIconForTicketType(
                        ticketModel.pasajes[index]['nombre']),
                  ),
                  title: Text(
                    ticketModel.pasajes[index]['nombre'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Text(
                          '\$${NumberFormat('#,##0', 'es_ES').format(ticketModel.pasajes[index]['precio'])}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.edit, color: primaryColor),
                        onPressed: () {
                          _showEditDialog(context, ticketModel, index, true);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20),
          _buildSectionCard(
            title: 'Precios Domingo y Feriados',
            icon: Icons.weekend,
            child: ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: sundayTicketModel.pasajes.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red[100],
                    child: _getIconForTicketType(
                        sundayTicketModel.pasajes[index]['nombre']),
                  ),
                  title: Text(
                    sundayTicketModel.pasajes[index]['nombre'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          '\$${NumberFormat('#,##0', 'es_ES').format(sundayTicketModel.pasajes[index]['precio'])}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.red[800],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.edit, color: primaryColor),
                        onPressed: () {
                          _showEditDialog(
                              context, sundayTicketModel, index, false);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 10),
          Center(
            child: Text(
              'Toque en el icono de lápiz para editar el nombre y precio',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSettings() {
    final ticketModel = Provider.of<TicketModel>(context);
    final sundayTicketModel = Provider.of<SundayTicketModel>(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Colores de Botones - Lunes a Sábado',
            icon: Icons.palette,
            child: ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: ticketModel.pasajes.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Icon(Icons.color_lens, color: Colors.blue),
                  ),
                  title: Text(
                    ticketModel.pasajes[index]['nombre'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.palette, color: primaryColor),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ButtonColorSettingsScreen(
                            buttonName: ticketModel.pasajes[index]['nombre'],
                            ticketType: 'weekday',
                            buttonIndex: index,
                          ),
                        ),
                      );
                      if (result == true) {
                        _settingsChanged = true;
                      }
                    },
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20),
          _buildSectionCard(
            title: 'Colores de Botones - Domingo/Feriado',
            icon: Icons.palette,
            child: ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: sundayTicketModel.pasajes.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red[100],
                    child: Icon(Icons.color_lens, color: Colors.red),
                  ),
                  title: Text(
                    sundayTicketModel.pasajes[index]['nombre'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.palette, color: primaryColor),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ButtonColorSettingsScreen(
                            buttonName:
                                sundayTicketModel.pasajes[index]['nombre'],
                            ticketType: 'sunday',
                            buttonIndex: index,
                          ),
                        ),
                      );
                      if (result == true) {
                        _settingsChanged = true;
                      }
                    },
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20),
          _buildSectionCard(
            title: 'Apariencia de Botones',
            icon: Icons.palette,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Switch para mostrar/ocultar íconos
                  SwitchListTile(
                    title: Text(
                      'Mostrar Íconos',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle:
                        Text('Muestra íconos junto al texto en los botones'),
                    value: _showIcons,
                    activeColor: primaryColor,
                    onChanged: (value) {
                      setState(() {
                        _showIcons = value;
                      });
                    },
                    secondary: CircleAvatar(
                      backgroundColor: Colors.amber[100],
                      child: Icon(
                        _showIcons ? Icons.visibility : Icons.visibility_off,
                        color: primaryColor,
                      ),
                    ),
                  ),

                  Divider(),

                  // Add new section for icon spacing
                  if (_showIcons) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Pequeño',
                                  style: TextStyle(color: Colors.grey[600])),
                              Text('Normal',
                                  style: TextStyle(color: Colors.grey[600])),
                              Text('Grande',
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                          Slider(
                            value: _iconSpacing,
                            min: 2,
                            max: 20,
                            divisions: 9,
                            label: '${_iconSpacing.toInt()}px',
                            activeColor: primaryColor,
                            onChanged: (value) {
                              setState(() {
                                _iconSpacing = value;
                              });
                            },
                          ),
                          Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Espacio: ${_iconSpacing.toInt()}px',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  Divider(),

                  // Slider para ajustar el tamaño del texto
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber[100],
                      child: Icon(Icons.format_size, color: primaryColor),
                    ),
                    title: Text(
                      'Tamaño del Texto',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Ajuste el tamaño del texto en los botones'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pequeño',
                                style: TextStyle(color: Colors.grey[600])),
                            Text('Normal',
                                style: TextStyle(color: Colors.grey[600])),
                            Text('Grande',
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                        Slider(
                          value: _textSizeMultiplier,
                          min: 0.5,
                          max: 1.1,
                          // Changed from 1.2 to 1.1 (110%)
                          divisions: 4,
                          // Changed from 7 to 4 divisions
                          label: '${(_textSizeMultiplier * 100).toInt()}%',
                          activeColor: primaryColor,
                          onChanged: (value) {
                            setState(() {
                              _textSizeMultiplier = value;
                            });
                          },
                        ),
                        Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Tamaño: ${(_textSizeMultiplier * 100).toInt()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(),

                  // Control de transparencia
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber[100],
                      child: Icon(Icons.opacity, color: primaryColor),
                    ),
                    title: Text(
                      'Transparencia',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Ajuste la opacidad de los botones'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Transparente',
                                style: TextStyle(color: Colors.grey[600])),
                            Text('Medio',
                                style: TextStyle(color: Colors.grey[600])),
                            Text('Sólido',
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                        Slider(
                          value: _buttonOpacity,
                          min: 0.3,
                          max: 1.0,
                          divisions: 7,
                          label: '${(_buttonOpacity * 100).toInt()}%',
                          activeColor: primaryColor,
                          onChanged: (value) {
                            setState(() {
                              _buttonOpacity = value;
                            });
                          },
                        ),
                        Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Opacidad: ${(_buttonOpacity * 100).toInt()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Vista previa de botón
                  Text(
                    'Vista Previa:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Opacity(
                      opacity: _buttonOpacity,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.blue,
                          disabledForegroundColor: Colors.white,
                          side: BorderSide(color: Colors.black, width: 3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_showIcons) ...[
                            Icon(Icons.directions_bus,
                                size: 24 * _textSizeMultiplier),
                            SizedBox(width: _iconSpacing),
                            // Use the configurable spacing
                          ],
                          Text(
                            'Botón de Ejemplo',
                            style: TextStyle(
                              fontSize: 18 * _textSizeMultiplier,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Botón para guardar las preferencias
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _saveDisplayPreferences();
                        _saveButtonIconPreferences();
                      },
                      icon: Icon(Icons.save),
                      label: Text(
                        'Guardar Preferencias',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Nueva sección para configurar las abreviaturas
  Widget _buildAbbreviationSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Abreviaturas para Reportes',
            icon: Icons.short_text,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure las abreviaturas que aparecerán en los reportes de caja',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),

                  ..._abbreviations.keys.map((key) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre original
                        Text(
                          'Texto original: $key',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),

                        // Campo de entrada para la abreviatura
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _abbreviationControllers[key],
                                decoration: InputDecoration(
                                  labelText: 'Abreviatura',
                                  hintText: 'Ejemplo: PG, Esc, AM',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  prefixIcon: Icon(Icons.edit_note),
                                ),
                                maxLength:
                                    10, // Limitar longitud de abreviaturas
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Divider(),
                        SizedBox(height: 8),
                      ],
                    );
                  }),

                  SizedBox(height: 20),

                  // Botón para guardar todas las abreviaturas
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveAbbreviations,
                      icon: Icon(Icons.save),
                      label: Text(
                        'Guardar Abreviaturas',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Información de ayuda
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[800]),
                            SizedBox(width: 8),
                            Text(
                              'Información',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Las abreviaturas se utilizan en los reportes de caja para mostrar el tipo de transacción de forma compacta.',
                          style: TextStyle(color: Colors.blue[800]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para crear tarjetas de sección
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 3,
      shadowColor: primaryColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryLight.withOpacity(0.15), accentColor.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: primaryColor.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: primaryColor, size: 22),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: primaryDark,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  // Función para obtener el ícono apropiado según el tipo de pasaje
  Icon _getIconForTicketType(String ticketName) {
    // First, check if we have a direct mapping for this ticket name
    if (_buttonIcons.containsKey(ticketName)) {
      String iconName = _buttonIcons[ticketName]!;
      IconData iconData = _getIconFromString(iconName);

      // Determine color based on ticket type (keeping consistent with original color scheme)
      Color iconColor;
      if (ticketName.contains('Público General')) {
        iconColor = Colors.orange;
      } else if (ticketName.contains('Escolar')) {
        iconColor = Colors.orange;
      } else if (ticketName.contains('Adulto Mayor')) {
        iconColor = Colors.orange;
      } else if (ticketName.contains('Int. hasta 15')) {
        iconColor = Colors.orange;
      } else if (ticketName.contains('Int. hasta 50')) {
        iconColor = Colors.orange;
      } else {
        iconColor = Colors.orange;
      }

      return Icon(iconData, color: iconColor);
    }

    // Fallback: if no custom icon is defined, use the default mapping
    if (ticketName.contains('Público General')) {
      return Icon(Icons.people, color: Colors.orange);
    } else if (ticketName.contains('Escolar')) {
      return Icon(Icons.school, color: Colors.orange);
    } else if (ticketName.contains('Adulto Mayor')) {
      return Icon(Icons.elderly, color: Colors.orange);
    } else if (ticketName.contains('Int. hasta 15')) {
      return Icon(Icons.directions_bus, color: Colors.orange);
    } else if (ticketName.contains('Int. hasta 50')) {
      return Icon(Icons.map, color: Colors.orange);
    } else {
      return Icon(Icons.mail, color: Colors.orange);
    }
  }

  void _showEditDialog(
      BuildContext context, dynamic model, int index, bool isTicketModel) {
    TextEditingController priceController =
        TextEditingController(text: model.pasajes[index]['precio'].toString());
    TextEditingController nameController =
        TextEditingController(text: model.pasajes[index]['nombre']);
    String originalName = model.pasajes[index]['nombre'];
    bool isEditing = true;

    // Obtener el ícono actual para este tipo de ticket
    String currentIconName = _buttonIcons[originalName] ?? 'people';
    IconData currentIcon = _getIconFromString(currentIconName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        isTicketModel ? Colors.blue[100] : Colors.red[100],
                    child: Icon(currentIcon,
                        color: isTicketModel ? Colors.blue : Colors.red),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Editar Ticket',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          originalName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: isEditing
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nombre actual: $originalName',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700]),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Nuevo nombre',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.edit),
                            ),
                            autofocus: true,
                          ),
                          SizedBox(height: 15),
                          Text(
                            'Precio actual: \$${NumberFormat('#,##0', 'es_ES').format(model.pasajes[index]['precio'])}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700]),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: priceController,
                            decoration: InputDecoration(
                              labelText: 'Nuevo precio',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.attach_money),
                              prefixText: '\$',
                              helperText:
                                  'Ingrese el nuevo precio sin puntos ni comas',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                          SizedBox(height: 15),
                          Text(
                            'Seleccione un ícono:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700]),
                          ),
                          SizedBox(height: 10),
                          // Selección de íconos
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: GridView.builder(
                              padding: EdgeInsets.all(8),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1,
                              ),
                              itemCount: _availableIcons.length,
                              itemBuilder: (context, iconIndex) {
                                final iconInfo = _availableIcons[iconIndex];
                                final bool isSelected =
                                    currentIcon == iconInfo['icon'];

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      currentIcon = iconInfo['icon'];
                                      currentIconName =
                                          _getStringFromIcon(iconInfo['icon']);
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primaryColor.withOpacity(0.2)
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                      border: isSelected
                                          ? Border.all(
                                              color: primaryColor, width: 2)
                                          : null,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        iconInfo['icon'],
                                        size: 24,
                                        color: isSelected
                                            ? primaryColor
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    : Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Nombre actualizado a:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    nameController.text,
                                    style: TextStyle(color: Colors.green[800]),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Precio actualizado a:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '\$${NumberFormat('#,##0', 'es_ES').format(double.parse(priceController.text))}',
                                    style: TextStyle(color: Colors.green[800]),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Ícono actualizado:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Row(
                                    children: [
                                      Icon(currentIcon,
                                          color: Colors.green[800]),
                                      SizedBox(width: 5),
                                      Text(
                                        _availableIcons.firstWhere(
                                            (icon) =>
                                                icon['icon'] == currentIcon,
                                            orElse: () => {
                                                  'name': 'Desconocido'
                                                })['name'],
                                        style:
                                            TextStyle(color: Colors.green[800]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cerrar'),
                ),
                if (isEditing)
                  ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text('Guardar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      double newPrice =
                          double.tryParse(priceController.text) ?? 0;
                      String newName = nameController.text.trim();

                      // Validar datos antes de guardar
                      if (newPrice > 0 && newName.isNotEmpty) {
                        // Actualizar ticket
                        model.editPasaje(index, newName, newPrice);

                        // Actualizar el ícono para el nuevo nombre
                        _buttonIcons[newName] = currentIconName;

                        // Si el nombre cambió, eliminar la asignación anterior de ícono
                        if (newName != originalName) {
                          _buttonIcons.remove(originalName);
                        }

                        // Guardar preferencias de íconos
                        _saveButtonIconPreferences();

                        // Indicar que la configuración ha cambiado
                        _settingsChanged = true;

                        setState(() {
                          isEditing = false;
                        });
                      } else {
                        // Mostrar un mensaje de error si los datos son inválidos
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.error, color: Colors.white),
                                SizedBox(width: 10),
                                Text(
                                    'Por favor, ingrese un nombre y precio válidos'),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBackupRestoreSection() {
    return _buildSectionCard(
      title: 'Respaldo y Recuperación',
      icon: Icons.backup,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cree copias de seguridad de sus datos y restaure en caso de actualización o cambio de dispositivo',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BackupScreen()),
                  );
                },
                icon: Icon(Icons.backup),
                label: Text(
                  'Gestionar Copias de Seguridad',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Método para cargar el margen final del PDF
  Future<void> _loadPdfEndMargin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pdfEndMargin = prefs.getDouble('pdfEndMargin') ?? 69.0;
      });
      print('PDF end margin loaded: $_pdfEndMargin');
    } catch (e) {
      print('Error loading PDF end margin: $e');
    }
  }

// Método para guardar el margen final del PDF
  Future<void> _savePdfEndMargin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('pdfEndMargin', _pdfEndMargin);

      // Set flag that settings have changed
      _settingsChanged = true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Margen PDF guardado correctamente'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
      print('PDF end margin saved: $_pdfEndMargin');
    } catch (e) {
      print('Error saving PDF end margin: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar margen PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
