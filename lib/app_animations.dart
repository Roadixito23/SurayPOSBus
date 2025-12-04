import 'package:flutter/material.dart';

/// Clase contenedora de animaciones personalizadas para la aplicación
class AppAnimations {
  /// Widget para entrada con fundido y movimiento desde abajo
  static Widget fadeInUp({
    required Widget child,
    required Animation<double> animation,
    double yOffset = 20.0,
  }) {
    final Animation<double> fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );

    final Animation<Offset> slideAnimation = Tween<Offset>(
      begin: Offset(0, yOffset / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }

  /// Widget para entrada con fundido y movimiento desde la derecha
  static Widget fadeInRight({
    required Widget child,
    required Animation<double> animation,
    double xOffset = 20.0,
  }) {
    final Animation<double> fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );

    final Animation<Offset> slideAnimation = Tween<Offset>(
      begin: Offset(xOffset / 100, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }

  /// Widget para animación de escala con rebote
  static Widget scaleIn({
    required Widget child,
    required Animation<double> animation,
  }) {
    final Animation<double> scaleAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.elasticOut,
    );

    return ScaleTransition(
      scale: scaleAnimation,
      child: child,
    );
  }

  /// Widget para animación de cartas secuenciales
  static List<Widget> staggeredList({
    required List<Widget> children,
    required AnimationController controller,
    int startIndex = 0,
    double staggerFactor = 0.1,
  }) {
    return List.generate(
      children.length,
          (index) {
        final Animation<double> animation = CurvedAnimation(
          parent: controller,
          curve: Interval(
            staggerFactor * (index + startIndex),
            1.0,
            curve: Curves.easeOutQuart,
          ),
        );

        return fadeInUp(
          animation: animation,
          child: children[index],
        );
      },
    );
  }

  /// Animación de parpadeo para indicadores
  static Widget pulse({
    required Widget child,
    required AnimationController controller,
    Duration duration = const Duration(seconds: 2),
  }) {
    controller.repeat(reverse: true);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Opacity(
          opacity: 0.5 + (controller.value * 0.5),
          child: child,
        );
      },
    );
  }

  /// Animación para tarjetas expandibles
  static Widget expandableCard({
    required Widget child,
    required Animation<double> animation,
    double minHeight = 80.0,
    double maxHeight = 200.0,
  }) {
    final heightAnimation = Tween<double>(
      begin: minHeight,
      end: maxHeight,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
    ));

    return AnimatedBuilder(
      animation: heightAnimation,
      builder: (context, _) {
        return Container(
          height: heightAnimation.value,
          child: child,
        );
      },
    );
  }

  /// Animación de shimmer para estados de carga
  static Widget shimmerLoading({
    required Widget child,
    required AnimationController controller,
    Color baseColor = Colors.grey,
    Color highlightColor = Colors.white,
  }) {
    controller.repeat();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [baseColor.withOpacity(0.5), highlightColor.withOpacity(0.9), baseColor.withOpacity(0.5)],
              stops: [0.0, controller.value, 1.0],
              begin: Alignment(-1.0, -0.3),
              end: Alignment(1.0, 0.3),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}