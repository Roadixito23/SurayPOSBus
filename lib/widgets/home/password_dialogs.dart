import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Diálogo de contraseña para reimpresión
Future<bool> showReprintPasswordDialog(
  BuildContext context,
  Future<String> Function() loadPassword,
  bool isNfcAvailable,
) async {
  final TextEditingController passwordController = TextEditingController();
  bool isAuthenticated = false;
  bool isReadingNfc = false;
  String nfcStatus = '';

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            elevation: 24,
            title: Row(
              children: [
                Icon(Icons.print, color: Colors.yellow.shade600, size: 32),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reimpresión de Boleta',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.yellow.shade800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.yellow.shade300, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.yellow.shade300, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.yellow.shade500, width: 2),
                    ),
                    helperText: 'Máximo 6 dígitos',
                    prefixIcon: Icon(Icons.password, color: Colors.yellow.shade500),
                    filled: true,
                    fillColor: Colors.blue.shade50,
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: TextStyle(fontSize: 18, letterSpacing: 8),
                ),
                if (isNfcAvailable && isReadingNfc && nfcStatus.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.yellow.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.yellow.shade700),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            nfcStatus,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.yellow.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isNfcAvailable) ...[
                  SizedBox(height: 20),
                  Divider(),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.nfc, color: Colors.yellow.shade600, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Autenticación con NFC',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.yellow.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: isReadingNfc
                          ? Colors.yellow.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isReadingNfc
                            ? Colors.yellow.shade400
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isReadingNfc)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.yellow.shade700),
                            ),
                          )
                        else
                          Icon(Icons.nfc_outlined, color: Colors.grey, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            nfcStatus.isEmpty
                                ? 'Lectura NFC inactiva'
                                : nfcStatus,
                            style: TextStyle(
                              fontSize: 13,
                              color: isReadingNfc
                                  ? Colors.yellow.shade800
                                  : Colors.grey,
                              fontWeight: isReadingNfc
                                  ? FontWeight.w600
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
                        isReadingNfc ? Icons.stop : Icons.play_arrow,
                        size: 18,
                      ),
                      label: Text(
                        isReadingNfc ? 'Detener lectura' : 'Iniciar lectura NFC',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.yellow.shade700,
                        side: BorderSide(color: Colors.yellow.shade700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        if (isReadingNfc) {
                          await NfcManager.instance.stopSession();
                          setState(() {
                            isReadingNfc = false;
                            nfcStatus = '';
                          });
                        } else {
                          setState(() {
                            isReadingNfc = true;
                            nfcStatus = 'Acerca la tarjeta NFC...';
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
                                  
                                  // Cargar tarjetas autorizadas
                                  final prefs = await SharedPreferences.getInstance();
                                  final cardsJson = prefs.getString('linked_nfc_cards') ?? '[]';
                                  final List<String> authorizedIds =
                                      List<String>.from(json.decode(cardsJson));
                                  
                                  final bool isAuthorized =
                                      authorizedIds.isEmpty || authorizedIds.contains(tagIdHex);
                                  
                                  if (isAuthorized) {
                                    await NfcManager.instance.stopSession();
                                    isAuthenticated = true;
                                    Navigator.of(context).pop();
                                  } else {
                                    setState(() {
                                      nfcStatus = 'Tarjeta no autorizada';
                                    });
                                    await Future.delayed(const Duration(seconds: 2));
                                    await NfcManager.instance.stopSession();
                                    setState(() {
                                      isReadingNfc = false;
                                      nfcStatus = '';
                                    });
                                  }
                                } else {
                                  await NfcManager.instance.stopSession();
                                  setState(() {
                                    isReadingNfc = false;
                                    nfcStatus = 'No se pudo leer la tarjeta';
                                  });
                                }
                              },
                            );
                          } catch (e) {
                            setState(() {
                              isReadingNfc = false;
                              nfcStatus = 'Error NFC: $e';
                            });
                          }
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
        actions: [
          Container(
            margin: EdgeInsets.only(bottom: 10, right: 10),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(bottom: 10, right: 10),
            child: ElevatedButton.icon(
              icon: Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                'Continuar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                String inputPassword = passwordController.text;
                String storedPassword = await loadPassword();

                if (inputPassword == storedPassword) {
                  isAuthenticated = true;
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 10),
                          Text('Contraseña incorrecta'),
                        ],
                      ),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }  
              },
            ),
          ),
        ],
        actionsPadding: EdgeInsets.only(right: 10),
        contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 24),
        titlePadding: EdgeInsets.fromLTRB(24, 24, 24, 10),
        backgroundColor: Colors.white,
          );
        },
      );
    },
  );

  return isAuthenticated;
}

/// Diálogo de contraseña para anular venta
Future<void> showPasswordDialog(
  BuildContext context,
  Future<String> Function() loadPassword,
  Future<void> Function() onCancelTransaction,
  bool hasAnulado,
  bool isNfcAvailable,
) async {
  if (hasAnulado) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ya se ha anulado una venta. Genere un nuevo boleto para poder anular de nuevo.'),
      ),
    );
    return;
  }

  final TextEditingController passwordController = TextEditingController();
  bool isReadingNfc = false;
  String nfcStatus = '';

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 24,
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 32,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Anular Última Venta',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade300, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade300, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade500, width: 2),
                ),
                helperText: 'Máximo 6 dígitos',
                prefixIcon: Icon(Icons.password, color: Colors.red.shade500),
                filled: true,
                fillColor: Colors.red.shade50,
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: TextStyle(fontSize: 18, letterSpacing: 8),
            ),
            if (isNfcAvailable && isReadingNfc && nfcStatus.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.red.shade700),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nfcStatus,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isNfcAvailable) ...[
              SizedBox(height: 20),
              Divider(),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.nfc, color: Colors.red.shade600, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Autenticación con NFC',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  icon: Icon(
                    isReadingNfc ? Icons.stop : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(
                    isReadingNfc ? 'Detener lectura' : 'Iniciar lectura NFC',
                    style: TextStyle(fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    if (isReadingNfc) {
                      await NfcManager.instance.stopSession();
                      setState(() {
                        isReadingNfc = false;
                        nfcStatus = '';
                      });
                    } else {
                      setState(() {
                        isReadingNfc = true;
                        nfcStatus = 'Acerca la tarjeta NFC...';
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
                              
                              // Cargar tarjetas autorizadas
                              final prefs = await SharedPreferences.getInstance();
                              final cardsJson = prefs.getString('linked_nfc_cards') ?? '[]';
                              final List<String> authorizedIds =
                                  List<String>.from(json.decode(cardsJson));
                              
                              final bool isAuthorized =
                                  authorizedIds.isEmpty || authorizedIds.contains(tagIdHex);
                              
                              if (isAuthorized) {
                                await NfcManager.instance.stopSession();
                                Navigator.of(context).pop();
                                await onCancelTransaction();
                              } else {
                                setState(() {
                                  nfcStatus = 'Tarjeta no autorizada';
                                });
                                await Future.delayed(const Duration(seconds: 2));
                                await NfcManager.instance.stopSession();
                                setState(() {
                                  isReadingNfc = false;
                                  nfcStatus = '';
                                });
                              }
                            } else {
                              await NfcManager.instance.stopSession();
                              setState(() {
                                isReadingNfc = false;
                                nfcStatus = 'No se pudo leer la tarjeta';
                              });
                            }
                          },
                        );
                      } catch (e) {
                        setState(() {
                          isReadingNfc = false;
                          nfcStatus = 'Error NFC: $e';
                        });
                      }
                    }
                  },
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          Container(
            margin: EdgeInsets.only(bottom: 10, right: 10),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(bottom: 10, right: 10),
            child: ElevatedButton.icon(
              icon: Icon(Icons.delete_outline, color: Colors.white),
              label: Text(
                'Anular',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                String inputPassword = passwordController.text;
                String storedPassword = await loadPassword();

                if (inputPassword == storedPassword) {
                  Navigator.of(context).pop();
                  await onCancelTransaction();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 10),
                          Text('Contraseña incorrecta.'),
                        ],
                      ),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
        actionsPadding: EdgeInsets.only(right: 10),
        contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 24),
        titlePadding: EdgeInsets.fromLTRB(24, 24, 24, 10),
        backgroundColor: Colors.white,
          );
        },
      );
    },
  );
}
