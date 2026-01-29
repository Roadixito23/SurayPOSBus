import 'package:flutter/material.dart';

/// Widget que crea un efecto de vapor/humo animado
class SteamEffect extends StatelessWidget {
  final double opacity;
  final Alignment alignment;

  const SteamEffect({
    super.key,
    required this.opacity,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 800),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.15),
                  Colors.grey.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
