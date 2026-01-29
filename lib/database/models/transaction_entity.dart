/// Entidad que representa una transacción individual vinculada a un cierre diario
class TransactionEntity {
  final int? id;
  final int dailyClosingId; // FK a daily_closings
  final int transactionId; // ID original de ReporteCaja
  final String nombre;
  final double valor;
  final String comprobante;
  final String dia; // DD
  final String mes; // MM
  final String ano; // YYYY
  final String hora; // HH:mm
  final int timestamp; // Unix timestamp
  final TransactionCategory category;
  final bool isCancellation;

  const TransactionEntity({
    this.id,
    required this.dailyClosingId,
    required this.transactionId,
    required this.nombre,
    required this.valor,
    required this.comprobante,
    required this.dia,
    required this.mes,
    required this.ano,
    required this.hora,
    required this.timestamp,
    required this.category,
    this.isCancellation = false,
  });

  /// Convierte el entity a Map para guardar en DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'daily_closing_id': dailyClosingId,
      'transaction_id': transactionId,
      'nombre': nombre,
      'valor': valor,
      'comprobante': comprobante,
      'dia': dia,
      'mes': mes,
      'ano': ano,
      'hora': hora,
      'timestamp': timestamp,
      'category': category.toString().split('.').last,
      'is_cancellation': isCancellation ? 1 : 0,
    };
  }

  /// Crea un entity desde un Map de la DB
  factory TransactionEntity.fromMap(Map<String, dynamic> map) {
    return TransactionEntity(
      id: map['id'] as int?,
      dailyClosingId: map['daily_closing_id'] as int,
      transactionId: map['transaction_id'] as int,
      nombre: map['nombre'] as String,
      valor: (map['valor'] as num).toDouble(),
      comprobante: map['comprobante'] as String,
      dia: map['dia'] as String,
      mes: map['mes'] as String,
      ano: map['ano'] as String,
      hora: map['hora'] as String,
      timestamp: map['timestamp'] as int,
      category: TransactionCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => TransactionCategory.pasaje,
      ),
      isCancellation: (map['is_cancellation'] as int) == 1,
    );
  }

  /// Crea un entity desde un Map de ReporteCaja y un closing ID
  factory TransactionEntity.fromReporteCaja(
    Map<String, dynamic> transaction,
    int dailyClosingId,
  ) {
    // Determinar categoría basándose en el nombre
    TransactionCategory category;
    bool isCancellation = false;

    final nombre = transaction['nombre'] as String;
    if (nombre.startsWith('Anulación:')) {
      category = TransactionCategory.anulacion;
      isCancellation = true;
    } else if (nombre.startsWith('Cargo:')) {
      category = TransactionCategory.correspondencia;
    } else {
      category = TransactionCategory.pasaje;
    }

    return TransactionEntity(
      dailyClosingId: dailyClosingId,
      transactionId: transaction['id'] as int,
      nombre: nombre,
      valor: (transaction['valor'] as num).toDouble(),
      comprobante: transaction['comprobante'] as String,
      dia: transaction['dia'] as String,
      mes: transaction['mes'] as String,
      ano: transaction['ano'] as String,
      hora: transaction['hora'] as String,
      timestamp: transaction['timestamp'] as int,
      category: category,
      isCancellation: isCancellation,
    );
  }

  /// Convierte el entity a formato compatible con ReporteCaja
  Map<String, dynamic> toReporteCajaFormat() {
    return {
      'id': transactionId,
      'nombre': nombre,
      'valor': valor,
      'comprobante': comprobante,
      'dia': dia,
      'mes': mes,
      'ano': ano,
      'hora': hora,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() {
    return 'TransactionEntity(id: $id, nombre: $nombre, valor: $valor, category: $category)';
  }
}

/// Categoría de transacción
enum TransactionCategory {
  pasaje,
  correspondencia,
  anulacion,
}
