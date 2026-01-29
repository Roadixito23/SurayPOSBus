/// Entidad que representa un cierre de caja diario en la base de datos
class DailyClosingEntity {
  final int? id;
  final String date; // YYYY-MM-DD
  final int year;
  final int month;
  final int day;
  final String dayOfWeek; // LUNES, MARTES, etc.
  final double totalPasajes;
  final double totalCorrespondencias;
  final double totalAnulaciones;
  final double grandTotal;
  final int transactionCount;
  final String? ticketId;
  final ClosingStatus status;
  final int createdAt; // Unix timestamp
  final int closedAt; // Unix timestamp
  final String? pdfFilename;

  const DailyClosingEntity({
    this.id,
    required this.date,
    required this.year,
    required this.month,
    required this.day,
    required this.dayOfWeek,
    required this.totalPasajes,
    required this.totalCorrespondencias,
    required this.totalAnulaciones,
    required this.grandTotal,
    required this.transactionCount,
    this.ticketId,
    required this.status,
    required this.createdAt,
    required this.closedAt,
    this.pdfFilename,
  });

  /// Convierte el entity a Map para guardar en DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'year': year,
      'month': month,
      'day': day,
      'day_of_week': dayOfWeek,
      'total_pasajes': totalPasajes,
      'total_correspondencias': totalCorrespondencias,
      'total_anulaciones': totalAnulaciones,
      'grand_total': grandTotal,
      'transaction_count': transactionCount,
      'ticket_id': ticketId,
      'status': status.toString().split('.').last,
      'created_at': createdAt,
      'closed_at': closedAt,
      'pdf_filename': pdfFilename,
    };
  }

  /// Crea un entity desde un Map de la DB
  factory DailyClosingEntity.fromMap(Map<String, dynamic> map) {
    return DailyClosingEntity(
      id: map['id'] as int?,
      date: map['date'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      day: map['day'] as int,
      dayOfWeek: map['day_of_week'] as String,
      totalPasajes: (map['total_pasajes'] as num).toDouble(),
      totalCorrespondencias: (map['total_correspondencias'] as num).toDouble(),
      totalAnulaciones: (map['total_anulaciones'] as num).toDouble(),
      grandTotal: (map['grand_total'] as num).toDouble(),
      transactionCount: map['transaction_count'] as int,
      ticketId: map['ticket_id'] as String?,
      status: ClosingStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => ClosingStatus.closed,
      ),
      createdAt: map['created_at'] as int,
      closedAt: map['closed_at'] as int,
      pdfFilename: map['pdf_filename'] as String?,
    );
  }

  /// Crea una copia del entity con algunos campos modificados
  DailyClosingEntity copyWith({
    int? id,
    String? date,
    int? year,
    int? month,
    int? day,
    String? dayOfWeek,
    double? totalPasajes,
    double? totalCorrespondencias,
    double? totalAnulaciones,
    double? grandTotal,
    int? transactionCount,
    String? ticketId,
    ClosingStatus? status,
    int? createdAt,
    int? closedAt,
    String? pdfFilename,
  }) {
    return DailyClosingEntity(
      id: id ?? this.id,
      date: date ?? this.date,
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      totalPasajes: totalPasajes ?? this.totalPasajes,
      totalCorrespondencias: totalCorrespondencias ?? this.totalCorrespondencias,
      totalAnulaciones: totalAnulaciones ?? this.totalAnulaciones,
      grandTotal: grandTotal ?? this.grandTotal,
      transactionCount: transactionCount ?? this.transactionCount,
      ticketId: ticketId ?? this.ticketId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
      pdfFilename: pdfFilename ?? this.pdfFilename,
    );
  }

  @override
  String toString() {
    return 'DailyClosingEntity(id: $id, date: $date, dayOfWeek: $dayOfWeek, grandTotal: $grandTotal, transactionCount: $transactionCount)';
  }
}

/// Estado del cierre de caja
enum ClosingStatus {
  closed, // Cierres diarios son siempre definitivos
}
