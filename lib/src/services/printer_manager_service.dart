import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../features/utils/print/data/datasources/lq310_form_builder_pdf.dart';
import '../features/utils/print/data/datasources/lq310_fuel_builder_pdf.dart';
import '../features/utils/print/data/datasources/lq310_form_builder.dart';
import '../features/utils/print/data/datasources/lq310_fuel_builder.dart'
    hide Lq310FormBuilder;

abstract class PrintStrategy {
  Future<Uint8List> generateBytes(List<Map<String, dynamic>> jobs);
}

class PdfJobPrintStrategy implements PrintStrategy {
  @override
  Future<Uint8List> generateBytes(List<Map<String, dynamic>> jobs) async {
    return await PdfJobOrderBuilder().buildPdf(jobs);
  }
}

class PdfFuelPrintStrategy implements PrintStrategy {
  final String username;

  PdfFuelPrintStrategy(this.username);

  @override
  Future<Uint8List> generateBytes(List<Map<String, dynamic>> jobs) async {
    return await PdfFuelOrderBuilder()
        .buildPdf(jobs, printByUsername: username);
  }
}

class RawJobPrintStrategy implements PrintStrategy {
  @override
  Future<Uint8List> generateBytes(List<Map<String, dynamic>> jobs) async {
    return await Lq310FormBuilder().buildPrintBuffer(jobs);
  }
}

class RawFuelPrintStrategy implements PrintStrategy {
  final String username;

  RawFuelPrintStrategy(this.username);

  @override
  Future<Uint8List> generateBytes(List<Map<String, dynamic>> jobs) async {
    return await Lq310FuelOrderBuilder()
        .buildPrintBuffer(jobs, printByUsername: username);
  }
}

class PrinterManagerService extends GetxService {
  Future<List<String>> getInstalledPrinters() async {
    final printers = await Printing.listPrinters();
    return printers.where((p) => p.isAvailable).map((p) => p.name).toList();
  }

  Future<void> printJobs({
    required String printerName,
    required List<Map<String, dynamic>> jobs,
    required PrintStrategy strategy,
  }) async {
    try {
      final Uint8List printBytes = await strategy.generateBytes(jobs);

      if (strategy is PdfJobPrintStrategy || strategy is PdfFuelPrintStrategy) {
        await _sendToPdfPrinter(printerName, printBytes);
      } else {
        await _sendToRawPrinter(printerName, printBytes);
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> _sendToPdfPrinter(String printerName, Uint8List pdfBytes) async {
    final printers = await Printing.listPrinters();
    final targetPrinter = printers.firstWhere(
      (p) => p.name == printerName,
      orElse: () => throw Exception(printerName),
    );

    final success = await Printing.directPrintPdf(
      printer: targetPrinter,
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );

    if (!success) throw Exception('Spooler Error');
  }

  Future<void> _sendToRawPrinter(String printerName, Uint8List rawBytes) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String tempFilePath =
        '${tempDir.path}\\mpj_flutter_job_${DateTime.now().millisecondsSinceEpoch}.bin';
    final File tempFile = File(tempFilePath);

    try {
      await tempFile.writeAsBytes(rawBytes);

      String targetPrinterPath;
      if (printerName.startsWith(r'\\')) {
        targetPrinterPath = printerName;
      } else {
        targetPrinterPath = '\\\\localhost\\$printerName';
      }

      final ProcessResult printResult = await Process.run(
        'cmd.exe',
        ['/c', 'copy', '/B', tempFilePath, targetPrinterPath],
        runInShell: true,
      );

      if (printResult.exitCode != 0) {
        throw Exception(printResult.stderr);
      }
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
