import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../home.dart';
import '../../services/pdf/pdf_resource_manager.dart';
import '../../services/pdf/pdf_optimizer.dart';
import '../../services/pdf/generateTicket.dart';
import '../../services/pdf/generate_mo_ticket.dart';
import '../../services/pdf/generateCargo_Ticket.dart';
import '../../models/ComprobanteModel.dart';
import '../../models/ReporteCaja.dart';
import 'widgets/gear_painter.dart';
import 'widgets/industrial_door.dart';
import 'widgets/steam_effect.dart';

/// Splash Screen con estética Steampunk/Industrial
class SteampunkSplashScreen extends StatefulWidget {
  const SteampunkSplashScreen({super.key});

  @override
  State<SteampunkSplashScreen> createState() => _SteampunkSplashScreenState();
}

class _SteampunkSplashScreenState extends State<SteampunkSplashScreen>
    with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _doorsController;
  late AnimationController _gearsController;
  late AnimationController _steamController;
  late AnimationController _logoController;

  // Animations
  late Animation<double> _doorAnimation;
  late Animation<double> _logoAnimation;

  // Estado de precarga
  bool _resourcesLoaded = false;
  double _steamOpacity = 0.0;

  // Colores Naranjas y Azules
  static const _darkBlue = Color(0xFF0D47A1);
  static const _mediumBlue = Color(0xFF1976D2);
  static const _orange = Color(0xFFFF9800);
  static const _darkOrange = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
    _preloadResources();
  }

  void _initializeAnimations() {
    // Doors animation: 2000ms
    _doorsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _doorAnimation = CurvedAnimation(
      parent: _doorsController,
      curve: Curves.easeInOutCubic,
    );

    // Gears animation: infinite loop
    _gearsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Steam animation: 800ms
    _steamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Logo animation: 1000ms with elastic effect
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
  }

  Future<void> _startAnimationSequence() async {
    // 1. Espera inicial
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Iniciar engranajes + vapor simultáneo
    _steamController.forward();
    setState(() {
      _steamOpacity = 0.6;
    });

    // 3. Espera
    await Future.delayed(const Duration(milliseconds: 800));

    // 4. Abrir puertas
    await _doorsController.forward();

    // 5. Espera
    await Future.delayed(const Duration(milliseconds: 1200));

    // 6. Mostrar logo
    await _logoController.forward();

    // 7. Esperar recursos si aún no están listos
    while (!_resourcesLoaded) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 8. Espera final
    await Future.delayed(const Duration(milliseconds: 1500));

    // 9. Navegar a Home
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Home()),
      );
    }
  }

  Future<void> _preloadResources() async {
    try {
      // Inicializar resource manager
      final resourceManager = PdfResourceManager();
      await resourceManager.initialize();

      // Inicializar PDF optimizer
      final pdfOptimizer = PdfOptimizer();
      await pdfOptimizer.preloadResources();

      // Inicializar generadores de tickets en paralelo
      await Future.wait([
        _preloadGenerateTicket(),
        _preloadMoTicket(),
        _preloadCargoTicket(),
      ]);

      // Marcar recursos como cargados
      if (mounted) {
        setState(() {
          _resourcesLoaded = true;
        });
      }
    } catch (e) {
      print('Splash: Error durante la precarga: $e');
      // Continuar de todos modos
      if (mounted) {
        setState(() {
          _resourcesLoaded = true;
        });
      }
    }
  }

  Future<void> _preloadGenerateTicket() async {
    try {
      final generateTicket = GenerateTicket();
      await generateTicket.preloadResources();
    } catch (e) {
      print('Error precargando GenerateTicket: $e');
    }
  }

  Future<void> _preloadMoTicket() async {
    try {
      final moTicketGenerator = MoTicketGenerator();
      await moTicketGenerator.preloadResources();
    } catch (e) {
      print('Error precargando MoTicketGenerator: $e');
    }
  }

  Future<void> _preloadCargoTicket() async {
    try {
      final comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);
      final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);

      final cargoGen = CargoTicketGenerator(comprobanteModel, reporteCaja);
      await cargoGen.preloadResources();
    } catch (e) {
      print('Error precargando CargoTicketGenerator: $e');
    }
  }

  @override
  void dispose() {
    _doorsController.dispose();
    _gearsController.dispose();
    _steamController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _darkBlue,
      body: Stack(
        children: [
          // Fondo con textura
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  _mediumBlue,
                  _darkBlue,
                  Colors.black,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Efecto de vapor
          SteamEffect(opacity: _steamOpacity),

          // Puerta izquierda
          AnimatedBuilder(
            animation: _doorAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-screenWidth * 0.5 * _doorAnimation.value, 0),
                child: SizedBox(
                  width: screenWidth * 0.5,
                  child: const IndustrialDoor(isLeft: true),
                ),
              );
            },
          ),

          // Puerta derecha
          AnimatedBuilder(
            animation: _doorAnimation,
            builder: (context, child) {
              return Align(
                alignment: Alignment.centerRight,
                child: Transform.translate(
                  offset: Offset(screenWidth * 0.5 * _doorAnimation.value, 0),
                  child: SizedBox(
                    width: screenWidth * 0.5,
                    child: const IndustrialDoor(isLeft: false),
                  ),
                ),
              );
            },
          ),

          // Logo central con engranaje rotatorio
          Center(
            child: AnimatedBuilder(
              animation: _logoAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoAnimation.value,
                  child: Transform.scale(
                    scale: _logoAnimation.value,
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Engranaje rotatorio detrás del logo
                          AnimatedBuilder(
                            animation: _gearsController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _gearsController.value * 2 * math.pi,
                                child: SizedBox(
                                  width: 250,
                                  height: 250,
                                  child: CustomPaint(
                                    painter: GearPainter(
                                      rotation: 0,
                                      color: _orange,
                                      teeth: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Logo en el centro
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _darkBlue.withValues(alpha: 0.9),
                              boxShadow: [
                                BoxShadow(
                                  color: _orange.withValues(alpha: 0.6),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Indicador de carga en la parte inferior
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _resourcesLoaded ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(_orange),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cargando recursos...',
                      style: TextStyle(
                        color: _orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
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
  }
}
