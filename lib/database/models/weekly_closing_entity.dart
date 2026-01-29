/// Entidad que representa un cierre de caja semanal
class WeeklyClosingEntity {
  final int? id;
  final int year;
  final int weekNumber; // ISO week number (1-53)
  final String startDate; // YYYY-MM-DD (Lunes)
  final String endDate; // YYYY-MM-DD (Domingo)
  final double totalPasajes;
  final double totalCorrespondencias;
  final double totalAnulaciones;
  final double grandTotal;
  final int transactionCount;
  final int dailyClosingCount;
  final int createdAt; // Unix timestamp
  final String? pdfFilename;

  const WeeklyClosingEntity({
    this.id,
    required this.year,
    required this.weekNumber,
    required this.startDate,
    required this.endDate,
    required this.totalPasajes,
    required this.totalCorrespondencias,
    required this.totalAnulaciones,
    required this.grandTotal,
    required this.transactionCount,
    required this.dailyClosingCount,
    required this.createdAt,
    this.pdfFilename,
  });

  /// Convierte el entity a Map para guardar en DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year': year,
      'week_number': weekNumber,
      'start_date': startDate,
      'end_date': endDate,
      'total_pasajes': totalPasajes,
      'total_correspondencias': totalCorrespondencias,
      'total_anulaciones': totalAnulaciones,
      'grand_total': grandTotal,
      'transaction_count': transactionCount,
      'daily_closing_count': dailyClosingCount,
      'created_at': createdAt,
      'pdf_filename': pdfFilename,
    };
  }

  /// Crea un entity desde un Map de la DB
  factory WeeklyClosingEntity.fromMap(Map<String, dynamic> map) {
    return WeeklyClosingEntity(
      id: map['id'] as int?,
      year: map['year'] as int,
      weekNumber: map['week_number'] as int,
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String,
      totalPasajes: (map['total_pasajes'] as num).toDouble(),
      totalCorrespondencias: (map['total_correspondencias'] as num).toDouble(),
      totalAnulaciones: (map['total_anulaciones'] as num).toDouble(),
      grandTotal: (map['grand_total'] as num).toDouble(),
      transactionCount: map['transaction_count'] as int,
      dailyClosingCount: map['daily_closing_count'] as int,
      createdAt: map['created_at'] as int,
      pdfFilename: map['pdf_filename'] as String?,
    );
  }

  /// Crea una copia del entity con algunos campos modificados
  WeeklyClosingEntity copyWith({
    int? id,
    int? year,
    int? weekNumber,
    String? startDate,
    String? endDate,
    double? totalPasajes,
    double? totalCorrespondencias,
    double? totalAnulaciones,
    double? grandTotal,
    int? transactionCount,
    int? dailyClosingCount,
    int? createdAt,
    String? pdfFilename,
  }) {
    return WeeklyClosingEntity(
      id: id ?? this.id,
      year: year ?? this.year,
      weekNumber: weekNumber ?? this.weekNumber,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalPasajes: totalPasajes ?? this.totalPasajes,
      totalCorrespondencias: totalCorrespondencias ?? this.totalCorrespondencias,
      totalAnulaciones: totalAnulaciones ?? this.totalAnulaciones,
      grandTotal: grandTotal ?? this.grandTotal,
      transactionCount: transactionCount ?? this.transactionCount,
      dailyClosingCount: dailyClosingCount ?? this.dailyClosingCount,
      createdAt: createdAt ?? this.createdAt,
      pdfFilename: pdfFilename ?? this.pdfFilename,
    );
  }

  @override
  String toString() {
    return 'WeeklyClosingEntity(id: $id, year: $year, week: $weekNumber, total: $grandTotal)';
  }
}
