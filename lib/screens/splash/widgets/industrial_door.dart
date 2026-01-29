import 'package:flutter/material.dart';

/// Widget que representa una puerta industrial con estética Steampunk
class IndustrialDoor extends StatelessWidget {
  final bool isLeft;
  final Color baseColor;
  final Color accentColor;

  const IndustrialDoor({
    super.key,
    required this.isLeft,
    this.baseColor = const Color(0xFF1565C0), // Azul medio
    this.accentColor = const Color(0xFFFF9800), // Naranja
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            baseColor,
            baseColor.withValues(alpha: 0.8),
            const Color(0xFF0D47A1), // Azul oscuro
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 20,
            spreadRadius: 5,
            offset: isLeft ? const Offset(5, 0) : const Offset(-5, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Líneas horizontales (placas metálicas)
          ...List.generate(8, (index) {
            return Positioned(
              top: (index * (1 / 8) * MediaQuery.of(context).size.height),
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      accentColor.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          }),

          // Remaches verticales
          ...List.generate(10, (index) {
            return Positioned(
              top: (index * 10) + 30.0,
              left: isLeft ? 20 : null,
              right: isLeft ? null : 20,
              child: _buildRivet(),
            );
          }),

          // Remaches en el otro lado
          ...List.generate(10, (index) {
            return Positioned(
              top: (index * 10) + 30.0,
              left: isLeft ? null : 20,
              right: isLeft ? 20 : null,
              child: _buildRivet(),
            );
          }),

          // Barra metálica central decorativa
          Positioned(
            top: 0,
            bottom: 0,
            left: isLeft ? null : 0,
            right: isLeft ? 0 : null,
            width: 8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accentColor.withValues(alpha: 0.8),
                    accentColor,
                    accentColor.withValues(alpha: 0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 8,
                    offset: isLeft ? const Offset(2, 0) : const Offset(-2, 0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye un remache individual
  Widget _buildRivet() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accentColor.withValues(alpha: 0.9),
            accentColor.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.4),
          ],
          stops: const [0.3, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
