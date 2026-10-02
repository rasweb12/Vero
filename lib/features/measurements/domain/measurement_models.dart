enum BodyMetric {
  weight('Peso', 'kg', 20, 500),
  waist('Cintura', 'cm', 10, 300),
  hip('Quadril', 'cm', 10, 300),
  chest('Peito', 'cm', 10, 300),
  thigh('Coxa', 'cm', 5, 150),
  arm('Braco', 'cm', 5, 100),
  calf('Panturrilha', 'cm', 5, 100),
  shoulders('Ombros', 'cm', 10, 300),
  neck('Pescoco', 'cm', 5, 100);

  const BodyMetric(this.label, this.unit, this.minimum, this.maximum);
  final String label;
  final String unit;
  final double minimum;
  final double maximum;
  bool accepts(double value) =>
      value.isFinite && value >= minimum && value <= maximum;
}

class RegistroMedida {
  RegistroMedida({
    required this.id,
    required this.date,
    this.weight,
    Map<BodyMetric, double> circumferences = const {},
    this.notes = '',
  }) : circumferences = Map.unmodifiable(circumferences);
  final String id;
  final DateTime date;
  final double? weight;
  final Map<BodyMetric, double> circumferences;
  final String notes;
  Map<BodyMetric, double> get values => {
    BodyMetric.weight: ?weight,
    ...circumferences,
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toUtc().toIso8601String(),
    'weight': weight,
    'circumferences': circumferences.map(
      (key, value) => MapEntry(key.name, value),
    ),
    'notes': notes,
  };
  factory RegistroMedida.fromJson(Map<String, dynamic> json) => RegistroMedida(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String).toLocal(),
    weight: (json['weight'] as num?)?.toDouble(),
    notes: json['notes'] as String? ?? '',
    circumferences: (json['circumferences'] as Map<String, dynamic>).map(
      (key, value) =>
          MapEntry(BodyMetric.values.byName(key), (value as num).toDouble()),
    ),
  );
}

class MeasurementData {
  MeasurementData({
    List<RegistroMedida> records = const [],
    List<BodyMetric> selected = const [
      BodyMetric.weight,
      BodyMetric.waist,
      BodyMetric.hip,
      BodyMetric.chest,
      BodyMetric.thigh,
    ],
  }) : records = List.unmodifiable(
         <RegistroMedida>[...records]..sort((a, b) => a.date.compareTo(b.date)),
       ),
       selected = List.unmodifiable(selected);
  final List<RegistroMedida> records;
  final List<BodyMetric> selected;
  List<BodyMetric> allowedMetrics(int? limit) =>
      limit == null ? selected : selected.take(limit).toList();
  List<RegistroMedida> forMetric(BodyMetric metric) =>
      records.where((record) => record.values.containsKey(metric)).toList();
  Map<String, dynamic> toJson() => {
    'version': 1,
    'records': records.map((record) => record.toJson()).toList(),
    'selected': selected.map((metric) => metric.name).toList(),
  };
  factory MeasurementData.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported measurements version.');
    }
    return MeasurementData(
      records: (json['records'] as List)
          .map(
            (record) => RegistroMedida.fromJson(record as Map<String, dynamic>),
          )
          .toList(),
      selected: (json['selected'] as List)
          .map((metric) => BodyMetric.values.byName(metric as String))
          .toList(),
    );
  }
}
