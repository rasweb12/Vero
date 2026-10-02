class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.date,
    required this.fileName,
  });
  final String id;
  final DateTime date;
  final String fileName;
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toUtc().toIso8601String(),
    'file_name': fileName,
  };
  factory ProgressPhoto.fromJson(Map<String, dynamic> json) => ProgressPhoto(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String).toLocal(),
    fileName: json['file_name'] as String,
  );
}
