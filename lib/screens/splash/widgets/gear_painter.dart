import 'package:flutter/material.dart';
import 'dart:math' as math;

/// CustomPainter para dibujar engranajes industriales con estética Steampunk
class GearPainter extends CustomPainter {
  final double rotation;
  final Color color;
  final int teeth;

  const GearPainter({
    required this.rotation,
    this.color = const Color(0xFFB87333), // Cobre
    this.teeth = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Pintura principal con gradiente radial para profundidad
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha:0.4),
          color.withValues(alpha:0.2),
          color.withValues(alpha:0.1),
        ],
        stops: const [0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    // Pintura para bordes
    final strokePaint = Paint()
      ..color = color.withValues(alpha:0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Dibujar círculo base del engranaje
    canvas.drawCircle(center, radius * 0.7, paint);
    canvas.drawCircle(center, radius * 0.7, strokePaint);

    // Dibujar dientes del engranaje
    final toothPath = Path();
    final angleStep = (2 * math.pi) / teeth;
    final innerRadius = radius * 0.7;
    final outerRadius = radius * 0.9;
    final toothWidth = angleStep * 0.4;

    for (int i = 0; i < teeth; i++) {
      final angle = (angleStep * i) + rotation;

      // Punto interno izquierdo
      final innerLeft = Offset(
        center.dx + innerRadius * math.cos(angle - toothWidth / 2),
        center.dy + innerRadius * math.sin(angle - toothWidth / 2),
      );

      // Punto externo izquierdo
      final outerLeft = Offset(
        center.dx + outerRadius * math.cos(angle - toothWidth / 2),
        center.dy + outerRadius * math.sin(angle - toothWidth / 2),
      );

      // Punto externo derecho
      final outerRight = Offset(
        center.dx + outerRadius * math.cos(angle + toothWidth / 2),
        center.dy + outerRadius * math.sin(angle + toothWidth / 2),
      );

      // Punto interno derecho
      final innerRight = Offset(
        center.dx + innerRadius * math.cos(angle + toothWidth / 2),
        center.dy + innerRadius * math.sin(angle + toothWidth / 2),
      );

      toothPath.moveTo(innerLeft.dx, innerLeft.dy);
      toothPath.lineTo(outerLeft.dx, outerLeft.dy);
      toothPath.lineTo(outerRight.dx, outerRight.dy);
      toothPath.lineTo(innerRight.dx, innerRight.dy);
      toothPath.close();
    }

    canvas.drawPath(toothPath, paint);
    canvas.drawPath(toothPath, strokePaint);

    // Círculo central con agujero
    final centerHolePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha:0.5),
          color.withValues(alpha:0.3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.3))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.3, centerHolePaint);
    canvas.drawCircle(center, radius * 0.3, strokePaint);

    // Agujero central interior
    final innerHolePaint = Paint()
      ..color = Colors.black.withValues(alpha:0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.15, innerHolePaint);
  }

  @override
  bool shouldRepaint(GearPainter oldDelegate) {
    return rotation != oldDelegate.rotation;
  }
}
