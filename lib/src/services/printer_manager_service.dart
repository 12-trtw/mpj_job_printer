import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../features/utils/print/data/datasources/lq310_form_builder_pdf.dart';
import '../features/utils/print/data/datasources/lq310_fuel_builder_pdf.dart';
import '../features/utils/print/data/datasources/lq310_form_builder.dart';
import '../features/utils/print/data/datasources/lq310_fuel_builder.dart'
    hide Lq310FormBuilder;

class _PdfPayload {
  final List<Map<String, dynamic>> jobs;
  final Uint8List fontBytes;
  final String username;
  _PdfPayload(this.jobs, this.fontBytes, {this.username = ''});
}

abstract class PrintStrategy {
  Future<Uint8List> generateBytes(List<Map<String, dynamic>> jobs);
}

class PdfJobPrintStrategy implements PrintStrategy {
  @override
  Future<Uint8List> generateBytes(List<Map<String, dynamic>> jobs) async {
    final fontData = await rootBundle.load('assets/fonts/Kanit-Regular.ttf');
    return await compute(
        _generatePdfJob, _PdfPayload(jobs, fontData.buffer.asUint8List()));
  }
}

Future<Uint8List> _generatePdfJob(_PdfPayload payload) async {
  return await PdfJobOrderBuilder().buildPdf(payload.jobs, payload.fontBytes);
}

class PdfFuelPrintStrategy implements PrintStrategy {
  final String username;
  PdfFuelPrintStrategy(this.username);
  @override
  Future<Uint8List> generateBytes(List<Map<String, dynamic>> jobs) async {
    final fontData = await rootBundle.load('assets/fonts/Kanit-Regular.ttf');
    return await compute(_generatePdfFuel,
        _PdfPayload(jobs, fontData.buffer.asUint8List(), username: username));
  }
}

Future<Uint8List> _generatePdfFuel(_PdfPayload payload) async {
  return await PdfFuelOrderBuilder().buildPdf(payload.jobs, payload.fontBytes,
      printByUsername: payload.username);
}

class RawJobPrintStrategy implements PrintStrategy {
  @override
  Future<Uint8List> generateBytes(List<Map<String, dynamic>> jobs) async {
    return await compute(_generateRawJob, jobs);
  }
}

Future<Uint8List> _generateRawJob(List<Map<String, dynamic>> jobs) async {
  return await Lq310FormBuilder().buildPrintBuffer(jobs);
}

class RawFuelPrintStrategy implements PrintStrategy {
  final String username;
  RawFuelPrintStrategy(this.username);
  @override
  Future<Uint8List> generateBytes(List<Map<String, dynamic>> jobs) async {
    return await compute(
        _generateRawFuel, {'jobs': jobs, 'username': username});
  }
}

Future<Uint8List> _generateRawFuel(Map<String, dynamic> payload) async {
  return await Lq310FuelOrderBuilder()
      .buildPrintBuffer(payload['jobs'], printByUsername: payload['username']);
}

class PrinterManagerService extends GetxService {
  Future<List<String>> getInstalledPrinters() async {
    try {
      final printers = await Future.value(Printing.listPrinters()).timeout(
        const Duration(seconds: 5),
        onTimeout: () => <Printer>[],
      );
      return printers.where((p) => p.isAvailable).map((p) => p.name).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> printJobs({
    required String printerName,
    required List<Map<String, dynamic>> jobs,
    required PrintStrategy strategy,
  }) async {
    try {
      final Uint8List printBytes =
          await Future.value(strategy.generateBytes(jobs)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('การประมวลผลไฟล์หมดเวลา (Timeout)'),
      );

      if (strategy is PdfJobPrintStrategy || strategy is PdfFuelPrintStrategy) {
        await _sendToPdfPrinter(printerName, printBytes);
      } else {
        await _sendToRawPrinter(printerName, printBytes);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _sendToPdfPrinter(String printerName, Uint8List pdfBytes) async {
    final printers = await Future.value(Printing.listPrinters()).timeout(
      const Duration(seconds: 5),
      onTimeout: () =>
          throw Exception('ระบบปริ้นเตอร์ของ macOS (CUPS) ไม่ตอบสนอง'),
    );

    final targetPrinter = printers.firstWhere(
      (p) => p.name == printerName,
      orElse: () => throw Exception('ไม่พบเครื่องพิมพ์: $printerName'),
    );

    final bool success = await Future.value(Printing.directPrintPdf(
      printer: targetPrinter,
      onLayout: (PdfPageFormat format) async => pdfBytes,
    )).timeout(
      const Duration(seconds: 10),
      onTimeout: () => false,
    );

    if (!success) {
      throw Exception(
          'คิวพิมพ์ของ macOS ไม่ตอบสนอง (Spooler Timeout) กรุณาใช้พิมพ์ RAW แทน');
    }
  }

  Future<void> _sendToRawPrinter(String printerName, Uint8List rawBytes) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String separator = Platform.pathSeparator;
    final String tempFilePath =
        '${tempDir.path}${separator}mpj_flutter_job_${DateTime.now().millisecondsSinceEpoch}.bin';
    final File tempFile = File(tempFilePath);

    try {
      await tempFile.writeAsBytes(rawBytes);

      if (Platform.isWindows) {
        String targetPrinterPath = printerName.startsWith(r'\\')
            ? printerName
            : '\\\\localhost\\$printerName';

        final ProcessResult printResult = await Future.value(Process.run(
          'cmd.exe',
          ['/c', 'copy', '/B', tempFilePath, targetPrinterPath],
          runInShell: true,
        )).timeout(
          const Duration(seconds: 8),
          onTimeout: () =>
              throw Exception('ส่งคำสั่งพิมพ์ไปยัง Windows ล้มเหลว (Timeout)'),
        );

        if (printResult.exitCode != 0) throw Exception(printResult.stderr);
      } else if (Platform.isMacOS || Platform.isLinux) {
        final ProcessResult printResult = await Future.value(Process.run(
          'lp',
          ['-d', printerName, '-o', 'raw', tempFilePath],
        )).timeout(
          const Duration(seconds: 8),
          onTimeout: () =>
              throw Exception('ส่งคำสั่งพิมพ์ lp บน macOS ล้มเหลว (Timeout)'),
        );

        if (printResult.exitCode != 0) throw Exception(printResult.stderr);
      } else {
        throw Exception('ระบบปฏิบัติการไม่รองรับการพิมพ์แบบ RAW');
      }
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
