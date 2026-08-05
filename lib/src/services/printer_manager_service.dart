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

// ---------------------------------------------------------------------------
// 1. Payload & Strategies
// ---------------------------------------------------------------------------

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

Future<T> _safeGuard<T>({
  required Future<T> Function() task,
  required int timeoutSeconds,
  required String timeoutMessage,
}) async {
  try {
    // เนื่องจาก task() คืนค่าเป็น Future<T> อยู่แล้ว จึงเรียกใช้และต่อด้วย .timeout() ได้เลย
    // หากต้องการการทำงานแบบ asynchronous แท้ๆ ครอบอีกชั้น สามารถใช้ Future.sync หรือ Future.microtask ได้
    return await Future.sync(task).timeout(
      Duration(seconds: timeoutSeconds),
      onTimeout: () => throw Exception(timeoutMessage),
    );
  } catch (e) {
    throw Exception(e.toString().replaceAll('Exception: ', ''));
  }
}

class PrinterManagerService extends GetxService {
  Future<List<String>> getInstalledPrinters() async {
    return _safeGuard(
      task: () async {
        final printers = await Printing.listPrinters();
        return printers.where((p) => p.isAvailable).map((p) => p.name).toList();
      },
      timeoutSeconds: 5,
      timeoutMessage: 'โหลดรายชื่อเครื่องพิมพ์ไม่สำเร็จ (Timeout)',
    ).catchError((_) => <String>[]);
  }

  Future<void> printJobs({
    required String printerName,
    required List<Map<String, dynamic>> jobs,
    required PrintStrategy strategy,
  }) async {
    final Uint8List printBytes = await _safeGuard(
      task: () => strategy.generateBytes(jobs),
      timeoutSeconds: 15,
      timeoutMessage: 'การประมวลผลไฟล์ข้อมูลหมดเวลา (Timeout)',
    );

    if (strategy is PdfJobPrintStrategy || strategy is PdfFuelPrintStrategy) {
      await _sendToPdfPrinter(printerName, printBytes);
    } else {
      await _sendToRawPrinter(printerName, printBytes);
    }
  }

  Future<void> _sendToPdfPrinter(String printerName, Uint8List pdfBytes) async {
    final targetPrinter = await _safeGuard(
      task: () async {
        final printers = await Printing.listPrinters();
        return printers.firstWhere(
          (p) => p.name == printerName,
          orElse: () => throw Exception('ไม่พบเครื่องพิมพ์: $printerName'),
        );
      },
      timeoutSeconds: 5,
      timeoutMessage: 'ค้นหาเครื่องพิมพ์ไม่พบ (CUPS Spooler ไม่ตอบสนอง)',
    );

    final success = await _safeGuard(
      task: () async {
        // ห่อหุ้มด้วย Future.value เพื่อแปลง FutureOr ให้เป็น Future แท้
        return await Future.value(Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (PdfPageFormat format) async => pdfBytes,
        ));
      },
      timeoutSeconds: 10,
      timeoutMessage: 'คิวพิมพ์ของระบบ OS ไม่ตอบสนอง (Spooler Timeout)',
    );

    if (!success) {
      throw Exception('เครื่องพิมพ์ยกเลิกคำสั่ง กรุณาใช้พิมพ์ RAW แทน');
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

      await _safeGuard(
        task: () async {
          if (Platform.isWindows) {
            String targetPath = printerName.startsWith(r'\\')
                ? printerName
                : '\\\\localhost\\$printerName';
            final res = await Process.run(
                'cmd.exe', ['/c', 'copy', '/B', tempFilePath, targetPath],
                runInShell: true);
            if (res.exitCode != 0) throw Exception(res.stderr);
          } else if (Platform.isMacOS || Platform.isLinux) {
            final res = await Process.run(
                'lp', ['-d', printerName, '-o', 'raw', tempFilePath]);
            if (res.exitCode != 0) throw Exception(res.stderr);
          } else {
            throw Exception('ระบบปฏิบัติการไม่รองรับ RAW Printing');
          }
        },
        timeoutSeconds: 8,
        timeoutMessage: 'ส่งคำสั่งพิมพ์ไปยัง OS ล้มเหลว (Timeout)',
      );
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
