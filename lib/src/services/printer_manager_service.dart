import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mpj_job_printer/src/models/job_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

abstract class PrintStrategy {
  Future<Uint8List> generateBytes(List<JobModel> jobs);
}

class PdfPrintStrategy implements PrintStrategy {
  @override
  Future<Uint8List> generateBytes(List<JobModel> jobs) async {
    final fontData = await rootBundle.load('assets/fonts/Kanit-Regular.ttf');
    final fontBytes = fontData.buffer.asUint8List();

    return await compute(_buildPdfInIsolate, _PdfPayload(jobs, fontBytes));
  }
}

class _PdfPayload {
  final List<JobModel> jobs;
  final Uint8List fontBytes;
  _PdfPayload(this.jobs, this.fontBytes);
}

Future<Uint8List> _buildPdfInIsolate(_PdfPayload payload) async {
  final doc = pw.Document();
  final ttf = pw.Font.ttf(payload.fontBytes.buffer.asByteData());
  final style = pw.TextStyle(font: ttf, fontSize: 11);
  final pageFormat =
      PdfPageFormat(8.5 * PdfPageFormat.inch, 5.5 * PdfPageFormat.inch);

  for (final job in payload.jobs) {
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.only(left: 30, top: 20, right: 20),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Positioned(
                  left: 402, top: 0, child: pw.Text(job.jobNo, style: style)),
              pw.Positioned(
                  left: 42,
                  top: 36,
                  child: pw.Text(job.formattedJobStart, style: style)),
            ],
          );
        },
      ),
    );
  }
  return await doc.save();
}

class PrinterManagerService extends GetxService {
  Future<void> printJobs({
    required String printerName,
    required List<JobModel> jobs,
    required PrintStrategy strategy,
  }) async {
    try {
      final Uint8List printBytes = await strategy.generateBytes(jobs);

      if (strategy is PdfPrintStrategy) {
        await _sendToPdfPrinter(printerName, printBytes);
      } else {
        await _sendToRawPrinter(printerName, printBytes);
      }
    } catch (e) {
      throw Exception('Print Pipeline Error: $e');
    }
  }

  Future<void> _sendToPdfPrinter(String printerName, Uint8List pdfBytes) async {
    final printers = await Printing.listPrinters();
    final targetPrinter = printers.firstWhere(
      (p) => p.name == printerName,
      orElse: () => throw Exception('ไม่พบเครื่องปริ้นเตอร์: $printerName'),
    );

    final success = await Printing.directPrintPdf(
      printer: targetPrinter,
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );

    if (!success) throw Exception('Spooler ปฏิเสธคำสั่งพิมพ์');
  }

  Future<void> _sendToRawPrinter(
      String printerName, Uint8List rawBytes) async {}
}
