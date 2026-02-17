import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'dart:convert';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController passwordController = TextEditingController();
  bool isAuthenticated = false;
  bool _isNfcAvailable = false;
  bool _isReadingNfc = false;
  String _nfcStatus = '';

  // Colores de la aplicación (mismos que settings)
  final Color primaryColor = Colors.amber[800]!;
  final Color accentColor = Colors.orange;
  final Color backgroundColor = Colors.grey[100]!;
  final Color cardColor = Colors.white;
  final Color textColor = Colors.black87;
  final Color buttonColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    _stopNfcReading();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    bool available = await NfcManager.instance.isAvailable();
    setState(() {
      _isNfcAvailable = available;
    });
    // Iniciar lectura NFC automáticamente si está disponible
    if (available) {
      _startNfcReading();
    }
  }

  Future<void> _startNfcReading() async {
    if (!_isNfcAvailable) {
      _showMessage('NFC no está disponible en este dispositivo');
      return;
    }

    setState(() {
      _isReadingNfc = true;
      _nfcStatus = 'Acerca la tarjeta NFC...';
    });

    try {
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          // Leer el UID de la tarjeta (ID único que todas las tarjetas tienen)
          final nfcTag = NfcTagAndroid.from(tag);
          if (nfcTag != null) {
            final tagId = nfcTag.id;
            final tagIdHex = tagId.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
            
            setState(() {
              _nfcStatus = 'Tarjeta detectada\nID: $tagIdHex';
            });

            // Cargar IDs autorizados desde SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            final cardsJson = prefs.getString('linked_nfc_cards') ?? '[]';
            final List<String> authorizedIds = List<String>.from(json.decode(cardsJson));

            // Verificar si el UID está en la lista O si la lista está vacía (permite todas)
            bool isAuthorized = authorizedIds.isEmpty || authorizedIds.contains(tagIdHex);
            
            if (isAuthorized) {
              await NfcManager.instance.stopSession();
              setState(() {
                _isReadingNfc = false;
              });
              _loginSuccess();
            } else {
              setState(() {
                _nfcStatus = 'Tarjeta no autorizada\nID: $tagIdHex';
              });
              await Future.delayed(const Duration(seconds: 2));
              await NfcManager.instance.stopSession();
              setState(() {
                _isReadingNfc = false;
                _nfcStatus = '';
              });
            }
          } else {
            setState(() {
              _nfcStatus = 'No se pudo leer la tarjeta';
            });
            await Future.delayed(const Duration(seconds: 2));
            await NfcManager.instance.stopSession();
            setState(() {
              _isReadingNfc = false;
              _nfcStatus = '';
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _isReadingNfc = false;
        _nfcStatus = 'Error: $e';
      });
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _nfcStatus = '';
      });
    }
  }

  Future<void> _stopNfcReading() async {
    await NfcManager.instance.stopSession();
    setState(() {
      _isReadingNfc = false;
      _nfcStatus = '';
    });
  }

  Future<void> _authenticate() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPassword = prefs.getString('password') ?? '123456';

    if (passwordController.text == savedPassword) {
      _loginSuccess();
    } else {
      _showMessage('Contraseña incorrecta');
    }
  }

  void _loginSuccess() {
    setState(() {
      isAuthenticated = true;
    });
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const Home()),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'Inicio de Sesión',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 4,
        actions: [
          if (_isNfcAvailable)
            IconButton(
              onPressed: _isReadingNfc ? _stopNfcReading : _startNfcReading,
              icon: Icon(
                _isReadingNfc ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
              tooltip: _isReadingNfc ? 'Detener lectura NFC' : 'Iniciar lectura NFC',
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: cardColor,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ingrese su Contraseña',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: TextStyle(fontSize: 18, color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Contraseña (6 dígitos)',
                      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                      prefixIcon: Icon(Icons.lock, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: backgroundColor,
                    ),
                    onSubmitted: (_) => _authenticate(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _authenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Ingresar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Icon(
                    Icons.lock_person,
                    size: 80,
                    color: primaryColor.withOpacity(0.3),
                  ),
                  if (_nfcStatus.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isReadingNfc ? Icons.nfc : Icons.info_outline,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _nfcStatus,
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
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
}
