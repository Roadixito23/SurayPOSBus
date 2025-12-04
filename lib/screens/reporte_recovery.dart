import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../theme/app_theme.dart';
import '../theme/app_animations.dart';
import '../services/report/report_cleaner.dart';

class RecoveryReport extends StatefulWidget {
  @override
  _RecoveryReportState createState() => _RecoveryReportState();
}

class _RecoveryReportState extends State<RecoveryReport> with TickerProviderStateMixin {
  // Variables para gestionar la retención de archivos
  final int _retentionPeriodDays = 30; // Período de retención: 30 días

  List<FileSystemEntity> pdfFiles = [];
  bool isLoading = true;
  String searchQuery = '';

  // Propiedades para estadísticas
  Map<String, dynamic> _reportStats = {};

  // Controladores para animaciones
  late AnimationController _fadeController;
  late AnimationController _staggeredController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    // Inicializar los datos de formato de fecha para español
    initializeDateFormatting('es_ES', null);

    // Inicializar controladores de animación
    _fadeController = AnimationController(
      vsync: this,
      duration: AppTheme.animationDuration,
    );

    _staggeredController = AnimationController(
      vsync: this,
      duration: AppTheme.longAnimationDuration,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    // Iniciar las animaciones
    _fadeController.forward();
    _staggeredController.forward();

    _loadPdfFiles(); // Cargar los archivos PDF al iniciar
    _loadReportStatistics();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggeredController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // Método para cargar estadísticas de reportes
  Future<void> _loadReportStatistics() async {
    try {
      final stats = await ReportCleaner.getReportStatistics();

      if (mounted) {
        setState(() {
          _reportStats = stats;
        });
      }
    } catch (e) {
      print('Error al cargar estadísticas: $e');
    }
  }

  Future<void> _loadPdfFiles() async {
    setState(() {
      isLoading = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> files = directory.listSync();
      final DateTime cutoffDate = DateTime.now().subtract(Duration(days: _retentionPeriodDays));

      // Filtrar por archivos PDF
      final List<FileSystemEntity> allPdfFiles = files.where((file) => file.path.endsWith('.pdf')).toList();

      // Filtrar archivos más antiguos que el período de retención
      List<FileSystemEntity> filesToKeep = [];

      for (var file in allPdfFiles) {
        final fileStats = File(file.path).statSync();
        final fileDate = fileStats.modified;

        if (fileDate.isAfter(cutoffDate) || fileDate.isAtSameMomentAs(cutoffDate)) {
          // Archivo dentro del período de retención
          filesToKeep.add(file);
        }
      }

      // Ordenar por fecha de modificación (más reciente primero)
      filesToKeep.sort((a, b) => File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync()));

      setState(() {
        pdfFiles = filesToKeep;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackBar('Error al cargar archivos: $e', AppTheme.coral);
    }
  }

  // Filtrar archivos PDF por búsqueda
  List<FileSystemEntity> get filteredPdfFiles {
    if (searchQuery.isEmpty) {
      return pdfFiles;
    }

    return pdfFiles.where((file) {
      final fileName = file.path.split('/').last.toLowerCase();
      return fileName.contains(searchQuery.toLowerCase());
    }).toList();
  }

  // Método para mostrar SnackBar con estilo personalizado
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontFamily: AppTheme.fontDefault,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(8),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Obtener la fecha de creación formateada
  String _getFormattedDate(FileSystemEntity file) {
    try {
      final fileStats = File(file.path).statSync();
      final DateTime dateTime = fileStats.modified;
      return DateFormat('dd/MM/yyyy - HH:mm', 'es_ES').format(dateTime);
    } catch (e) {
      return 'Fecha desconocida';
    }
  }

  // Formatear el nombre del archivo para mostrar día de semana y fecha
  String _formatFileName(FileSystemEntity file) {
    try {
      final fileStats = File(file.path).statSync();
      final DateTime dateTime = fileStats.modified;
      // Formato: "Lunes 22/Mar"
      final dayOfWeek = _getDayOfWeekInSpanish(dateTime.weekday);
      // Formatear para mostrar el nombre del mes en español con primera letra mayúscula
      final month = DateFormat('MMM', 'es_ES').format(dateTime);
      final capitalizedMonth = month[0].toUpperCase() + month.substring(1);
      return "$dayOfWeek ${dateTime.day}/$capitalizedMonth";
    } catch (e) {
      // Si hay un error, mostrar el nombre del archivo original
      return file.path.split('/').last;
    }
  }

  // Extraer el número del archivo si existe
  String _extractFileNumber(String fileName) {
    // Buscar patrón de número entre paréntesis como (1), (2), etc.
    final RegExp regExp = RegExp(r'\((\d+)\)');
    final match = regExp.firstMatch(fileName);

    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return "";
  }

  // Convertir número de día de la semana a texto en español
  String _getDayOfWeekInSpanish(int weekday) {
    switch (weekday) {
      case 1: return "Lunes";
      case 2: return "Martes";
      case 3: return "Miércoles";
      case 4: return "Jueves";
      case 5: return "Viernes";
      case 6: return "Sábado";
      case 7: return "Domingo";
      default: return "";
    }
  }

  // Calcular los días restantes antes de la eliminación del archivo
  int _getDaysRemainingBeforeDeletion(FileSystemEntity file) {
    try {
      final fileStats = File(file.path).statSync();
      final creationDate = fileStats.modified;
      final expirationDate = creationDate.add(Duration(days: _retentionPeriodDays));
      final now = DateTime.now();

      // Calcular la diferencia en días
      final daysRemaining = expirationDate.difference(now).inDays;

      // Asegurarse de que no devuelva valores negativos
      return daysRemaining > 0 ? daysRemaining : 0;
    } catch (e) {
      return 0;
    }
  }

  // Obtener el color para el indicador de tiempo restante
  Color _getTimeRemainingColor(int daysRemaining) {
    if (daysRemaining > 7) {
      return AppTheme.turquoise; // Más de 1 semana: turquesa
    } else if (daysRemaining > 3) {
      return AppTheme.coral.withOpacity(0.7); // Entre 3-7 días: coral con opacidad
    } else {
      return AppTheme.coral; // Menos de 3 días: coral
    }
  }

  // Obtener el tamaño del archivo
  String _getFileSize(FileSystemEntity file) {
    try {
      final fileStats = File(file.path).statSync();
      final sizeInBytes = fileStats.size;

      if (sizeInBytes < 1024) {
        return '${sizeInBytes} B';
      } else if (sizeInBytes < 1024 * 1024) {
        return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Tamaño desconocido';
    }
  }

  Future<void> _printPdf(FileSystemEntity file) async {
    // Mostrar un indicador de progreso con diseño personalizado
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.turquoise),
              ),
              SizedBox(height: 20),
              Text(
                'Enviando a impresora...',
                style: TextStyle(
                  fontFamily: AppTheme.fontHemiheads,
                  fontSize: 16,
                  color: AppTheme.turquoiseDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final pdfData = await File(file.path).readAsBytes(); // Leer el archivo PDF

      // Imprimir el PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return pdfData;
        },
        format: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity), // Tamaño de rollo de 58 mm
      );

      // Mostrar mensaje de éxito
      _showSnackBar('Documento enviado a impresora', AppTheme.turquoise);
    } catch (e) {
      // Mostrar un mensaje de error
      _showSnackBar('Error al imprimir el PDF: $e', AppTheme.coral);
    } finally {
      // Cerrar el indicador de progreso
      Navigator.of(context).pop(); // Cerrar el diálogo de carga
    }
  }

  // Widget para mostrar estadísticas
  Widget _buildStatsWidget() {
    final totalReports = _reportStats['totalReports'] ?? 0;
    final sizeMB = _reportStats['totalSizeMB'] ?? '0';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard(
            icon: Icons.folder,
            title: 'Total',
            value: '$totalReports',
            color: AppTheme.turquoiseDark,
          ),
          _buildStatCard(
            icon: Icons.date_range,
            title: 'Últimos 7 días',
            value: '${_reportStats['reportsLastWeek'] ?? 0}',
            color: AppTheme.coral,
          ),
          _buildStatCard(
            icon: Icons.storage,
            title: 'Espacio',
            value: '$sizeMB MB',
            color: AppTheme.turquoiseDark,
          ),
        ],
      ),
    );
  }

  // Construir tarjeta de estadística
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.28,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppTheme.fontHemiheads,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Histórico',
              style: TextStyle(
                fontFamily: AppTheme.fontHemiheads,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.turquoise,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () {
              _loadPdfFiles();
              _loadReportStatistics();
            },
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            tooltip: 'Información',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Información',
                    style: TextStyle(
                      fontFamily: AppTheme.fontHemiheads,
                      color: AppTheme.turquoiseDark,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Esta sección le permite ver e imprimir los reportes generados por el sistema.'),
                      SizedBox(height: 12),
                      Text('Política de retención:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('• Se conservan todos los reportes de los últimos $_retentionPeriodDays días.'),
                      Text('• Los reportes más antiguos se eliminan automáticamente.'),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: AppTheme.turquoise),
                          SizedBox(width: 4),
                          Text('Más de 7 días restantes'),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: AppTheme.coral.withOpacity(0.7)),
                          SizedBox(width: 4),
                          Text('Entre 3-7 días restantes'),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: AppTheme.coral),
                          SizedBox(width: 4),
                          Text('Menos de 3 días restantes'),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      child: Text('OK', style: TextStyle(color: AppTheme.turquoise)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar reportes...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.turquoise),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: AppTheme.coral),
                    onPressed: () {
                      setState(() {
                        searchQuery = '';
                      });
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.turquoise, width: 2),
                  ),
                ),
              ),
            ),

            // Estadísticas
            AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeController,
                  child: child,
                );
              },
              child: _buildStatsWidget(),
            ),

            // Lista de reportes
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadPdfFiles();
                  await _loadReportStatistics();
                },
                color: AppTheme.turquoise,
                child: isLoading
                    ? Center(
                  child: AppAnimations.shimmerLoading(
                    controller: _shimmerController,
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(height: 16),
                        Container(
                          width: 200,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : filteredPdfFiles.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        searchQuery.isEmpty ? Icons.folder_open : Icons.search_off,
                        size: 80,
                        color: AppTheme.turquoiseLight,
                      ),
                      SizedBox(height: 16),
                      Text(
                        searchQuery.isEmpty
                            ? 'No hay reportes guardados'
                            : 'No se encontraron resultados',
                        style: TextStyle(
                          fontFamily: AppTheme.fontHemiheads,
                          fontSize: 18,
                          color: AppTheme.turquoiseDark,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        searchQuery.isEmpty
                            ? 'Los reportes se generarán automáticamente'
                            : 'Intenta con otra búsqueda',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    : AnimatedBuilder(
                  animation: _staggeredController,
                  builder: (context, child) {
                    return ListView.builder(
                      itemCount: filteredPdfFiles.length,
                      padding: EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        final file = filteredPdfFiles[index];
                        final originalFileName = file.path.split('/').last;
                        final formattedFileName = _formatFileName(file);
                        final fileNumber = _extractFileNumber(originalFileName);
                        final daysRemaining = _getDaysRemainingBeforeDeletion(file);

                        // Crear animación escalonada
                        final Animation<double> animation = CurvedAnimation(
                          parent: _staggeredController,
                          curve: Interval(
                            0.05 * (index % 15), // Repetir cada 15 elementos
                            1.0,
                            curve: Curves.easeOutQuart,
                          ),
                        );

                        return AppAnimations.fadeInUp(
                          animation: animation,
                          child: Card(
                            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            elevation: 3,
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                // Mostrar opciones
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                    ),
                                    padding: EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 5,
                                          margin: EdgeInsets.only(bottom: 24),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                        Text(
                                          fileNumber.isNotEmpty
                                              ? '$formattedFileName - Reporte #$fileNumber'
                                              : formattedFileName,
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontHemiheads,
                                            fontSize: 20,
                                            color: AppTheme.turquoiseDark,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          originalFileName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(height: 24),
                                        ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: AppTheme.turquoiseLight,
                                            child: Icon(Icons.print, color: AppTheme.turquoiseDark),
                                          ),
                                          title: Text(
                                            'Imprimir reporte',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text('Enviar a impresora conectada'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _printPdf(file);
                                          },
                                        ),
                                        Divider(),
                                        ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: AppTheme.coralLight,
                                            child: Icon(Icons.remove_red_eye, color: AppTheme.coral),
                                          ),
                                          title: Text(
                                            'Ver detalles',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text('Información detallada del reporte'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            // Implementar visualización de detalles aquí
                                            _showSnackBar(
                                                'Función de visualización en desarrollo',
                                                Colors.blue
                                            );
                                          },
                                        ),
                                        SizedBox(height: 16),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    // Icono del PDF con círculo de número
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 5,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.picture_as_pdf,
                                            color: AppTheme.coral,
                                            size: 32,
                                          ),
                                          if (fileNumber.isNotEmpty)
                                            Positioned(
                                              right: -8,
                                              top: -8,
                                              child: Container(
                                                padding: EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.turquoise,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.1),
                                                      blurRadius: 2,
                                                      offset: Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  fileNumber,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 16),

                                    // Información del reporte
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  formattedFileName,
                                                  style: TextStyle(
                                                    fontFamily: AppTheme.fontHemiheads,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.turquoiseDark,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),

                                          // Días para expiración
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _getTimeRemainingColor(daysRemaining).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _getTimeRemainingColor(daysRemaining),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.timer,
                                                  size: 14,
                                                  color: _getTimeRemainingColor(daysRemaining),
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  daysRemaining > 0
                                                      ? 'Expira en $daysRemaining días'
                                                      : 'Expira hoy',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: _getTimeRemainingColor(daysRemaining),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          SizedBox(height: 8),

                                          // Fecha y tamaño
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                _getFormattedDate(file),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Icon(
                                                Icons.storage,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                _getFileSize(file),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Botón de impresión
                                    ElevatedButton(
                                      onPressed: () => _printPdf(file),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.turquoise,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.print, size: 18)
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      // Botón flotante para gestionar reportes
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestión de Reportes',
                    style: TextStyle(
                      fontFamily: AppTheme.fontHemiheads,
                      fontSize: 20,
                      color: AppTheme.turquoiseDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.coralLight,
                      child: Icon(Icons.cleaning_services, color: AppTheme.coral),
                    ),
                    title: Text('Limpiar reportes antiguos'),
                    subtitle: Text('Eliminar reportes con más de 30 días'),
                    onTap: () async {
                      Navigator.pop(context);
                      bool confirm = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            'Confirmar Limpieza',
                            style: TextStyle(
                              fontFamily: AppTheme.fontHemiheads,
                              color: AppTheme.coral,
                            ),
                          ),
                          content: Text(
                            '¿Está seguro de que desea eliminar los reportes vencidos? Esta acción no se puede deshacer.',
                          ),
                          actions: [
                            TextButton(
                              child: Text('Cancelar'),
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                            ElevatedButton(
                              child: Text('Confirmar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.coral,
                              ),
                              onPressed: () => Navigator.of(context).pop(true),
                            ),
                          ],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ) ?? false;

                      if (confirm) {
                        int count = await ReportCleaner.cleanExpiredReportsOnStartup();
                        _loadPdfFiles();
                        _loadReportStatistics();
                        _showSnackBar(
                            'Se eliminaron $count reportes vencidos',
                            AppTheme.turquoise
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
        backgroundColor: AppTheme.turquoise,
        child: Icon(Icons.more_vert),
      ),
    );
  }
}