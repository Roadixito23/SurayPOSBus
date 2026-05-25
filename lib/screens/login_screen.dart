import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
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
          final tagId = NfcA.from(tag)?.identifier ??
              NfcB.from(tag)?.identifier ??
              IsoDep.from(tag)?.identifier;
          if (tagId != null) {
            final tagIdHex = tagId
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(':')
                .toUpperCase();

            setState(() {
              _nfcStatus = 'Tarjeta detectada\nID: $tagIdHex';
            });

            // Cargar IDs autorizados desde SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            final cardsJson = prefs.getString('linked_nfc_cards') ?? '[]';
            final List<String> authorizedIds =
                List<String>.from(json.decode(cardsJson));

            // Verificar si el UID está en la lista O si la lista está vacía (permite todas)
            bool isAuthorized =
                authorizedIds.isEmpty || authorizedIds.contains(tagIdHex);

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
        elevation: 0,
        actions: [
          if (_isNfcAvailable)
            IconButton(
              onPressed: _isReadingNfc ? _stopNfcReading : _startNfcReading,
              icon: Icon(
                _isReadingNfc ? Icons.nfc : Icons.nfc_outlined,
                color: Colors.white,
              ),
              tooltip:
                  _isReadingNfc ? 'Detener lectura NFC' : 'Iniciar lectura NFC',
            ),
        ],
      ),
      body: Container(
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
                    const SizedBox(height: 20),
                    Text(
                      'Ingrese la Contraseña',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                      style: const TextStyle(fontSize: 18, letterSpacing: 8),
                      onSubmitted: (_) => _authenticate(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _authenticate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Ingresar',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // ── Sección NFC ────────────────────────────────────────
                    if (_isNfcAvailable) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.nfc, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
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
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: _isReadingNfc
                              ? primaryColor.withOpacity(0.12)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isReadingNfc
                                ? primaryColor
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_isReadingNfc)
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryColor),
                                ),
                              )
                            else
                              Icon(Icons.nfc_outlined,
                                  color: Colors.grey, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _nfcStatus.isEmpty
                                    ? 'Lectura NFC inactiva'
                                    : _nfcStatus,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _isReadingNfc
                                      ? primaryColor
                                      : Colors.grey,
                                  fontWeight: _isReadingNfc
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          icon: Icon(
                            _isReadingNfc ? Icons.stop : Icons.play_arrow,
                            size: 18,
                          ),
                          label: Text(
                            _isReadingNfc
                                ? 'Detener lectura'
                                : 'Iniciar lectura NFC',
                            style: const TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isReadingNfc
                              ? _stopNfcReading
                              : _startNfcReading,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
