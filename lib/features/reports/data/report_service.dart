import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as material;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportSnapshot {
  const ReportSnapshot({
    required this.userName,
    required this.periodLabel,
    required this.consistencyScore,
    required this.trainingCount,
    required this.totalVolume,
    required this.weightStart,
    required this.weightEnd,
    required this.goalWeight,
    required this.measurementChanges,
  });

  final String userName;
  final String periodLabel;
  final double consistencyScore;
  final int trainingCount;
  final double totalVolume;
  final double? weightStart;
  final double? weightEnd;
  final double? goalWeight;
  final List<ReportMeasurementChange> measurementChanges;
}

class ReportMeasurementChange {
  const ReportMeasurementChange({
    required this.label,
    required this.unit,
    required this.change,
  });
  final String label;
  final String unit;
  final double change;
}

class ReportService {
  Future<Uint8List> buildPdf(ReportSnapshot snapshot) async {
    final document = pw.Document();
    const teal = PdfColor.fromInt(0xFF0D9488);
    document.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(36),
        ),
        build: (context) => [
          pw.Text(
            'Vero',
            style: const pw.TextStyle(
              color: teal,
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Resumo de progresso', style: pw.Theme.of(context).header2),
          pw.Text('${snapshot.userName} · ${snapshot.periodLabel}'),
          pw.SizedBox(height: 24),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              _row(
                'Pontuacao de constancia',
                '${snapshot.consistencyScore.toStringAsFixed(0)} / 100',
              ),
              _row('Treinos concluidos', '${snapshot.trainingCount}'),
              _row(
                'Volume total',
                '${snapshot.totalVolume.toStringAsFixed(1)} kg',
              ),
              _row('Peso', _weightSummary(snapshot)),
              if (snapshot.goalWeight != null)
                _row(
                  'Meta de peso',
                  '${snapshot.goalWeight!.toStringAsFixed(1)} kg',
                ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('Variacao de medidas', style: pw.Theme.of(context).header3),
          pw.SizedBox(height: 8),
          if (snapshot.measurementChanges.isEmpty)
            pw.Text('Ainda nao ha duas leituras para comparar.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _row('Medida', 'Variacao'),
                ...snapshot.measurementChanges.map(
                  (item) => _row(
                    item.label,
                    '${item.change >= 0 ? '+' : ''}${item.change.toStringAsFixed(1)} ${item.unit}',
                  ),
                ),
              ],
            ),
          pw.SizedBox(height: 30),
          pw.Text(
            'Seu ritmo. Seus resultados.',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<Uint8List> buildShareImage(ReportSnapshot snapshot) async {
    const width = 1200.0;
    const height = 900.0;
    final recorder = ui.PictureRecorder();
    final canvas = material.Canvas(recorder);
    final background = material.Paint()
      ..color = const material.Color(0xFFF8F9FA);
    canvas.drawRect(
      const material.Rect.fromLTWH(0, 0, width, height),
      background,
    );
    final accent = material.Paint()..color = const material.Color(0xFF0D9488);
    canvas.drawRect(const material.Rect.fromLTWH(0, 0, width, 18), accent);
    _text(canvas, 'Vero', 72, 58, 54, const material.Color(0xFF0D9488), true);
    _text(
      canvas,
      'Resumo de progresso',
      72,
      132,
      38,
      const material.Color(0xFF121417),
      true,
    );
    _text(
      canvas,
      '${snapshot.userName} · ${snapshot.periodLabel}',
      72,
      184,
      24,
      const material.Color(0xFF6B7280),
    );
    _metric(
      canvas,
      'CONSTANCIA',
      '${snapshot.consistencyScore.toStringAsFixed(0)} / 100',
      72,
      270,
    );
    _metric(canvas, 'TREINOS', '${snapshot.trainingCount}', 420, 270);
    _metric(
      canvas,
      'VOLUME',
      '${snapshot.totalVolume.toStringAsFixed(0)} kg',
      768,
      270,
    );
    _text(canvas, 'Peso', 72, 470, 26, const material.Color(0xFF6B7280), true);
    _text(
      canvas,
      _weightSummary(snapshot),
      72,
      516,
      42,
      const material.Color(0xFF121417),
      true,
    );
    if (snapshot.goalWeight != null) {
      _text(
        canvas,
        'Meta: ${snapshot.goalWeight!.toStringAsFixed(1)} kg',
        72,
        586,
        24,
        const material.Color(0xFF6B7280),
      );
    }
    _text(
      canvas,
      'Seu ritmo. Seus resultados.',
      72,
      790,
      24,
      const material.Color(0xFF0D9488),
      true,
    );
    final image = await recorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const FormatException('Nao foi possivel criar a imagem.');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  pw.TableRow _row(String label, String value) => pw.TableRow(
    children: [
      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label)),
      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(value)),
    ],
  );

  String _weightSummary(ReportSnapshot snapshot) {
    if (snapshot.weightStart == null || snapshot.weightEnd == null) {
      return 'Sem dados suficientes';
    }
    final change = snapshot.weightEnd! - snapshot.weightStart!;
    return '${snapshot.weightEnd!.toStringAsFixed(1)} kg (${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg)';
  }

  void _metric(
    ui.Canvas canvas,
    String label,
    String value,
    double x,
    double y,
  ) {
    _text(canvas, label, x, y, 20, const material.Color(0xFF6B7280), true);
    _text(canvas, value, x, y + 42, 38, const material.Color(0xFF121417), true);
  }

  void _text(
    ui.Canvas canvas,
    String value,
    double x,
    double y,
    double size,
    material.Color color, [
    bool bold = false,
  ]) {
    final painter = material.TextPainter(
      text: material.TextSpan(
        text: value,
        style: material.TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold
              ? material.FontWeight.w700
              : material.FontWeight.w400,
        ),
      ),
      textDirection: material.TextDirection.ltr,
    )..layout(maxWidth: 1050);
    painter.paint(canvas, material.Offset(x, y));
  }
}
