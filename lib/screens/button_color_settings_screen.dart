import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ButtonColorSettingsScreen extends StatefulWidget {
  final String buttonName;
  final String ticketType; // 'weekday' o 'sunday'
  final int buttonIndex;

  const ButtonColorSettingsScreen({
    super.key,
    required this.buttonName,
    required this.ticketType,
    required this.buttonIndex,
  });

  @override
  _ButtonColorSettingsScreenState createState() =>
      _ButtonColorSettingsScreenState();
}

class _ButtonColorSettingsScreenState
    extends State<ButtonColorSettingsScreen> {
  // Colores para background
  double _bgRed = 0;
  double _bgGreen = 0;
  double _bgBlue = 0;
  double _bgOpacity = 0.70;

  // Colores para border
  double _borderRed = 0;
  double _borderGreen = 0;
  double _borderBlue = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadColors();
  }

  Future<void> _loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        'button_colors_${widget.ticketType}_${widget.buttonIndex}';
    final String? colorsJson = prefs.getString(key);

    if (colorsJson != null) {
      final Map<String, dynamic> colors = json.decode(colorsJson);
      setState(() {
        _bgRed = colors['bgRed'] ?? 0;
        _bgGreen = colors['bgGreen'] ?? 0;
        _bgBlue = colors['bgBlue'] ?? 0;
        _bgOpacity = (colors['bgOpacity'] as num?)?.toDouble() ?? 0.70;
        _borderRed = colors['borderRed'] ?? 0;
        _borderGreen = colors['borderGreen'] ?? 0;
        _borderBlue = colors['borderBlue'] ?? 0;
        _isLoading = false;
      });
    } else {
      // Establecer colores predeterminados según el botón
      _setDefaultColors();
    }
  }

  void _setDefaultColors() {
    // Colores predeterminados del sistema
    // Lunes a Sábado (weekday)
    if (widget.ticketType == 'weekday') {
      switch (widget.buttonIndex) {
        case 0: // Público General
          _bgRed = 239;
          _bgGreen = 83;
          _bgBlue = 80; // Colors.red.shade400
          _borderRed = 0;
          _borderGreen = 0;
          _borderBlue = 0; // Colors.black
          break;
        case 1: // Escolar
          _bgRed = 102;
          _bgGreen = 187;
          _bgBlue = 106; // Colors.green.shade400
          _borderRed = 0;
          _borderGreen = 0;
          _borderBlue = 0;
          break;
        case 2: // Adulto Mayor
          _bgRed = 66;
          _bgGreen = 165;
          _bgBlue = 245; // Colors.blue.shade400
          _borderRed = 0;
          _borderGreen = 0;
          _borderBlue = 0;
          break;
        case 3: // Intermedio 15km
          _bgRed = 66;
          _bgGreen = 165;
          _bgBlue = 245;
          _borderRed = 0;
          _borderGreen = 0;
          _borderBlue = 0;
          break;
        case 4: // Intermedio 50km
          _bgRed = 102;
          _bgGreen = 187;
          _bgBlue = 106;
          _borderRed = 0;
          _borderGreen = 0;
          _borderBlue = 0;
          break;
        case 5: // Escolar Intermedio
          _bgRed = 255;
          _bgGreen = 255;
          _bgBlue = 255; // Colors.white
          _borderRed = 0;
          _borderGreen = 0;
          _borderBlue = 0;
          break;
      }
    } else if (widget.ticketType == 'sunday') {
      // Domingo/Feriado (sunday)
      switch (widget.buttonIndex) {
        case 0: // Público General
          _bgRed = 189;
          _bgGreen = 189;
          _bgBlue = 189; // Colors.grey.shade400
          _borderRed = 100;
          _borderGreen = 181;
          _borderBlue = 246; // Colors.blue.shade300
          break;
        case 1: // Escolar
          _bgRed = 239;
          _bgGreen = 83;
          _bgBlue = 80;
          _borderRed = 248;
          _borderGreen = 187;
          _borderBlue = 208; // Colors.pink.shade300
          break;
        case 2: // Adulto Mayor
          _bgRed = 102;
          _bgGreen = 187;
          _bgBlue = 106;
          _borderRed = 255;
          _borderGreen = 241;
          _borderBlue = 118; // Colors.yellow.shade300
          break;
        case 3: // Intermedio 15km
          _bgRed = 239;
          _bgGreen = 83;
          _bgBlue = 80;
          _borderRed = 248;
          _borderGreen = 187;
          _borderBlue = 208;
          break;
        case 4: // Intermedio 50km
          _bgRed = 239;
          _bgGreen = 83;
          _bgBlue = 80;
          _borderRed = 248;
          _borderGreen = 187;
          _borderBlue = 208;
          break;
        case 5: // Escolar Intermedio
          _bgRed = 255;
          _bgGreen = 255;
          _bgBlue = 255;
          _borderRed = 0;
          _borderGreen = 0;
          _borderBlue = 0;
          break;
      }
    } else {
      // OTROS: OFERTA (0) y CARGO (1)
      // Ambos usan naranja por defecto
      _bgRed = 255;
      _bgGreen = 152;
      _bgBlue = 0; // Colors.orange
      _borderRed = 0;
      _borderGreen = 0;
      _borderBlue = 0;
    }
    setState(() {
      _bgOpacity = 0.70;
      _isLoading = false;
    });
  }

  Future<void> _saveColors() async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        'button_colors_${widget.ticketType}_${widget.buttonIndex}';
    final colors = {
      'bgRed': _bgRed,
      'bgGreen': _bgGreen,
      'bgBlue': _bgBlue,
      'bgOpacity': _bgOpacity,
      'borderRed': _borderRed,
      'borderGreen': _borderGreen,
      'borderBlue': _borderBlue,
    };
    await prefs.setString(key, json.encode(colors));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('Colores guardados correctamente'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetToDefault() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restablecer colores'),
        content: Text(
            '¿Desea restablecer los colores predeterminados del sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Restablecer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _setDefaultColors();
      await _saveColors();
    }
  }

  Color get _backgroundColor =>
      Color.fromRGBO(_bgRed.toInt(), _bgGreen.toInt(), _bgBlue.toInt(), _bgOpacity);

  Color get _backgroundColorFull =>
      Color.fromRGBO(_bgRed.toInt(), _bgGreen.toInt(), _bgBlue.toInt(), 1);

  Color get _borderColor => Color.fromRGBO(
      _borderRed.toInt(), _borderGreen.toInt(), _borderBlue.toInt(), 1);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Cargando...'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Colores del Botón'),
        backgroundColor: Color(0xFF4F8FC0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.restore),
            onPressed: _resetToDefault,
            tooltip: 'Restablecer valores predeterminados',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Información del botón
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configurando colores para:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      widget.buttonName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F8FC0),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.ticketType == 'weekday'
                          ? 'Lunes a Sábado'
                          : 'Domingo / Feriado',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Previsualización
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Previsualización',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _backgroundColor,
                          side: BorderSide(
                            color: _borderColor,
                            width: 3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.buttonName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _backgroundColorFull.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Control de color de fondo
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette, color: Color(0xFF4F8FC0)),
                        SizedBox(width: 8),
                        Text(
                          'Color de Fondo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F8FC0),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildColorSlider(
                      'Rojo',
                      _bgRed,
                      Colors.red.shade400,
                      (value) => setState(() => _bgRed = value),
                    ),
                    SizedBox(height: 12),
                    _buildColorSlider(
                      'Verde',
                      _bgGreen,
                      Colors.green.shade400,
                      (value) => setState(() => _bgGreen = value),
                    ),
                    SizedBox(height: 12),
                    _buildColorSlider(
                      'Azul',
                      _bgBlue,
                      Colors.blue.shade400,
                      (value) => setState(() => _bgBlue = value),
                    ),
                    SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey.shade300),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.opacity, size: 18, color: Colors.grey[600]),
                        SizedBox(width: 6),
                        Text(
                          'Opacidad del relleno',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Text(
                            '${(_bgOpacity * 100).round()}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.grey.shade600,
                        inactiveTrackColor: Colors.grey.shade300,
                        thumbColor: Colors.grey.shade700,
                        overlayColor: Colors.grey.withOpacity(0.2),
                        trackHeight: 6,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        value: _bgOpacity,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        onChanged: (value) => setState(() => _bgOpacity = value),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Control de color de borde
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.border_color, color: Color(0xFF4F8FC0)),
                        SizedBox(width: 8),
                        Text(
                          'Color de Borde',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F8FC0),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: _borderColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildColorSlider(
                      'Rojo',
                      _borderRed,
                      Colors.red.shade400,
                      (value) => setState(() => _borderRed = value),
                    ),
                    SizedBox(height: 12),
                    _buildColorSlider(
                      'Verde',
                      _borderGreen,
                      Colors.green.shade400,
                      (value) => setState(() => _borderGreen = value),
                    ),
                    SizedBox(height: 12),
                    _buildColorSlider(
                      'Azul',
                      _borderBlue,
                      Colors.blue.shade400,
                      (value) => setState(() => _borderBlue = value),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Botón Guardar
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _saveColors();
                  Navigator.pop(context, true);
                },
                icon: Icon(Icons.save, size: 24),
                label: Text(
                  'Guardar Colores',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4F8FC0),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSlider(
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.3),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 6,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            divisions: 255,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
