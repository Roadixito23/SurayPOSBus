import 'package:url_launcher/url_launcher.dart';

/// Servicio para integrar pagos con tarjeta vía SumUp Deep Link.
///
/// No usa el SDK nativo de SumUp; en su lugar abre la app oficial
/// mediante un URI `sumupmerchant://pay/1.0` y recibe el resultado
/// a través del callback `posbus://sumup-result`.
class SumUpService {
  static const String _affiliateKey =
      'sup_afk_BydGVQ41DbNaM3Mm441GRPxon06MIkXu';
  static const String _currency = 'CLP';
  static const String _callbackScheme = 'posbus';
  static const String _callbackHost = 'sumup-result';

  /// Abre la app de SumUp para cobrar [monto] con el [titulo] indicado.
  ///
  /// Lanza [Exception] si la app de SumUp no está instalada o no se
  /// puede abrir el deep link.
  static Future<void> cobrar({
    required double monto,
    required String titulo,
  }) async {
    final uri = Uri(
      scheme: 'sumupmerchant',
      host: 'pay',
      path: '/1.0',
      queryParameters: {
        'affiliate-key': _affiliateKey,
        'app-id': 'posbus',
        'amount': monto.toStringAsFixed(2),
        'currency': _currency,
        'title': titulo,
        'callback': '$_callbackScheme://$_callbackHost',
      },
    );

    final canOpen = await canLaunchUrl(uri);
    if (!canOpen) {
      throw Exception('App de SumUp no instalada');
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
