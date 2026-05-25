import 'package:flutter/material.dart';

const _hunterGreen = Color(0xFF355E3B);
const _hunterGreenDark = Color(0xFF1E3B22);
const _hunterGreenLight = Color(0xFF4A7A50);
const _hunterGreenSurface = Color(0xFFEAF2EB);

class TransferenciaScreen extends StatelessWidget {
  const TransferenciaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_hunterGreenDark, _hunterGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'TRANSFERENCIA',
          style: TextStyle(
            fontFamily: 'Hemiheads',
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: _hunterGreenDark.withOpacity(0.6),
      ),
      backgroundColor: const Color(0xFFF2F6F2),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;
          final pad = w * 0.03;
          final fs = h * 0.032;

          return Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              children: [
                // ── Tarjeta datos bancarios (ocupa ~57% del espacio) ──
                Flexible(
                  flex: 57,
                  child: Card(
                    elevation: 5,
                    shadowColor: _hunterGreen.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Column(
                        children: [
                          // Cabecera con degradado
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                horizontal: pad * 1.5, vertical: pad * 0.75),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_hunterGreenDark, _hunterGreen],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.account_balance_rounded,
                                    color: Colors.white, size: fs * 1.4),
                                SizedBox(width: w * 0.02),
                                Text(
                                  'Datos de Transferencia',
                                  style: TextStyle(
                                    fontSize: fs * 1.05,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Filas de datos
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: pad * 1.5, vertical: pad * 0.4),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _DataRow(
                                      label: 'Nombre',
                                      value: 'TRANSPORTE SURAY LTDA',
                                      fs: fs,
                                      labelW: w * 0.22,
                                      index: 0),
                                  _DataRow(
                                      label: 'RUT',
                                      value: '77799670-3',
                                      fs: fs,
                                      labelW: w * 0.22,
                                      index: 1),
                                  _DataRow(
                                      label: 'Banco',
                                      value: 'BCI',
                                      fs: fs,
                                      labelW: w * 0.22,
                                      index: 2),
                                  _DataRow(
                                      label: 'Tipo',
                                      value: 'Cta. Corriente',
                                      fs: fs,
                                      labelW: w * 0.22,
                                      index: 3),
                                  _DataRow(
                                      label: 'Cuenta',
                                      value: '95018948',
                                      fs: fs,
                                      labelW: w * 0.22,
                                      index: 4),
                                  _DataRow(
                                      label: 'Asunto',
                                      value: 'PASAJE',
                                      fs: fs,
                                      labelW: w * 0.22,
                                      index: 5),
                                  _DataRow(
                                      label: 'Correo',
                                      value: 'ARIEL@SURAY.CL',
                                      fs: fs,
                                      labelW: w * 0.22,
                                      index: 6),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: pad),
                // ── Tarjeta QR WhatsApp (ocupa ~40% del espacio) ──────
                Flexible(
                  flex: 40,
                  child: Card(
                    elevation: 5,
                    shadowColor: _hunterGreen.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Barra lateral decorativa
                          Container(
                            width: pad * 0.6,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_hunterGreenDark, _hunterGreenLight],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          // QR datos de transferencia (izquierda)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(pad * 0.8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Escanea los Datos',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: fs * 0.75,
                                      fontWeight: FontWeight.w700,
                                      color: _hunterGreenDark,
                                    ),
                                  ),
                                  SizedBox(height: pad * 0.4),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        'assets/qr_codes/qr-suray.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // QR WhatsApp (derecha)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(pad * 0.8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Envía tu comprobante a WhatsApp',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: fs * 0.75,
                                      fontWeight: FontWeight.w700,
                                      color: _hunterGreenDark,
                                    ),
                                  ),
                                  SizedBox(height: pad * 0.4),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        'assets/qr_codes/wspqr.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: pad * 0.4),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: pad * 0.5,
                                        vertical: pad * 0.25),
                                    decoration: BoxDecoration(
                                      color: _hunterGreenSurface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: _hunterGreenLight, width: 1),
                                    ),
                                    child: Text(
                                      '+56 9 4583 4172',
                                      style: TextStyle(
                                        fontSize: fs * 0.78,
                                        fontWeight: FontWeight.w800,
                                        color: _hunterGreen,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final double fs;
  final double labelW;
  final int index;

  const _DataRow({
    required this.label,
    required this.value,
    required this.fs,
    required this.labelW,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isEven = index.isEven;
    return Container(
      decoration: BoxDecoration(
        color: isEven ? _hunterGreenSurface : Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: labelW,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _hunterGreenDark,
                fontSize: fs,
              ),
            ),
          ),
          Container(
            width: 2,
            height: fs * 1.2,
            decoration: BoxDecoration(
              color: _hunterGreenLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
