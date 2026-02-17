import 'package:flutter/material.dart';
import '../services/statistics/statistics_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final StatisticsService _statsService = StatisticsService();
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _weeklySales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final stats = await _statsService.getSalesStatistics(days: 30);
      final weeklySales = await _statsService.getWeeklySales();

      if (mounted) {
        setState(() {
          _stats = stats;
          _weeklySales = weeklySales;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error cargando estadísticas: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estadísticas de Ventas'),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resumen General
                    _buildSectionTitle('Resumen General (30 días)'),
                    SizedBox(height: 12),
                    _buildStatsGrid(),

                    SizedBox(height: 24),

                    // Gráfico de Ventas Semanales
                    _buildSectionTitle('Ventas de la Semana'),
                    SizedBox(height: 12),
                    _buildWeeklyChart(),

                    SizedBox(height: 24),

                    // Ventas por Tipo de Pasaje
                    _buildSectionTitle('Ventas por Tipo de Pasaje'),
                    SizedBox(height: 12),
                    _buildPassengerTypeList(),

                    SizedBox(height: 24),

                    // Datos Destacados
                    _buildSectionTitle('Datos Destacados'),
                    SizedBox(height: 12),
                    _buildHighlights(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.amber.shade900,
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Ventas',
          '\$${_formatNumber(_stats['totalVentas'] ?? 0)}',
          Icons.attach_money,
          Colors.green,
        ),
        _buildStatCard(
          'Transacciones',
          '${_stats['totalTransacciones'] ?? 0}',
          Icons.receipt_long,
          Colors.blue,
        ),
        _buildStatCard(
          'Promedio Diario',
          '\$${_formatNumber(_stats['promedioDiario'] ?? 0)}',
          Icons.trending_up,
          Colors.orange,
        ),
        _buildStatCard(
          'Días Activos',
          '${_stats['diasConVentas'] ?? 0}',
          Icons.calendar_today,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    if (_weeklySales.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No hay datos de ventas',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Encontrar el valor máximo para escalar el gráfico
    double maxValue = 1;
    for (var sale in _weeklySales) {
      if ((sale['ventas'] as double) > maxValue) {
        maxValue = sale['ventas'] as double;
      }
    }

    return Container(
      height: 220,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _weeklySales.map((sale) {
                final double ventas = sale['ventas'] as double;
                final double height =
                    maxValue > 0 ? (ventas / maxValue) * 120 : 0;
                final bool isToday =
                    _weeklySales.indexOf(sale) == _weeklySales.length - 1;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '\$${_formatNumberShort(ventas)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: height.clamp(4, 120),
                      decoration: BoxDecoration(
                        color: isToday
                            ? Colors.amber.shade700
                            : Colors.amber.shade300,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _weeklySales.map((sale) {
              final bool isToday =
                  _weeklySales.indexOf(sale) == _weeklySales.length - 1;
              return SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Text(
                      sale['dia'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday
                            ? Colors.amber.shade900
                            : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      sale['fecha'],
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerTypeList() {
    final ventasPorTipo = _stats['ventasPorTipo'] as Map<String, int>? ?? {};
    final ingresosPorTipo =
        _stats['ingresosPorTipo'] as Map<String, double>? ?? {};

    if (ventasPorTipo.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No hay datos de pasajes',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Ordenar por cantidad vendida
    final sortedTypes = ventasPorTipo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: sortedTypes.length > 6 ? 6 : sortedTypes.length,
        separatorBuilder: (_, __) => Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = sortedTypes[index];
          final ingresos = ingresosPorTipo[entry.key] ?? 0.0;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getTypeColor(index),
              child: Text(
                '${index + 1}',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              entry.key,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('${entry.value} ventas'),
            trailing: Text(
              '\$${_formatNumber(ingresos)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHighlights() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade50, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        children: [
          _buildHighlightRow(
            Icons.star,
            'Mejor día',
            '${_stats['mejorDia'] ?? '-'} (\$${_formatNumber(_stats['maxVentas'] ?? 0)})',
            Colors.amber,
          ),
          Divider(height: 24),
          _buildHighlightRow(
            Icons.favorite,
            'Pasaje más vendido',
            '${_stats['pasajeMasVendido'] ?? '-'} (${_stats['cantidadPasajeMasVendido'] ?? 0})',
            Colors.red,
          ),
          Divider(height: 24),
          _buildHighlightRow(
            Icons.local_shipping,
            'Correspondencias',
            '\$${_formatNumber(_stats['totalCorrespondencias'] ?? 0)}',
            Colors.purple,
          ),
          Divider(height: 24),
          _buildHighlightRow(
            Icons.cancel,
            'Anulaciones',
            '\$${_formatNumber(_stats['totalAnulaciones'] ?? 0)}',
            Colors.red.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Color _getTypeColor(int index) {
    final colors = [
      Colors.amber.shade700,
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.purple.shade600,
      Colors.orange.shade600,
      Colors.teal.shade600,
    ];
    return colors[index % colors.length];
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _formatNumberShort(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}
