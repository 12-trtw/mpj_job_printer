// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/foundation.dart';
// import 'package:path_provider/path_provider.dart';

// class WindowsPrinterService {
//   Future<List<String>> getInstalledPrinters() async {
//     try {
//       if (!Platform.isWindows) {
//         return ['Epson LQ-310 (Mock for Mac/Linux)'];
//       }

//       final ProcessResult result = await Process.run(
//         'powershell.exe',
//         [
//           '-NoProfile',
//           '-Command',
//           'Get-Printer | Select-Object -ExpandProperty Name'
//         ],
//         runInShell: true,
//       );

//       if (result.exitCode != 0) {
//         throw Exception('ดึงข้อมูลเครื่องพิมพ์ล้มเหลว: ${result.stderr}');
//       }

//       final String output = result.stdout as String;
//       return output
//           .split('\r\n')
//           .map((name) => name.trim())
//           .where((name) => name.isNotEmpty)
//           .toList();
//     } catch (e) {
//       debugPrint('[WindowsPrinterService] Error: $e');
//       rethrow;
//     }
//   }

//   Future<void> printRawData({
//     required String printerName,
//     required Uint8List rawTis620Bytes,
//   }) async {
//     final Directory tempDir = await getTemporaryDirectory();
//     final String tempFilePath =
//         '${tempDir.path}\\mpj_flutter_job_${DateTime.now().millisecondsSinceEpoch}.bin';
//     final File tempFile = File(tempFilePath);

//     try {
//       await tempFile.writeAsBytes(rawTis620Bytes);

//       String targetPrinterPath;
//       if (printerName.startsWith(r'\\')) {
//         targetPrinterPath = printerName;
//       } else {
//         targetPrinterPath = '\\\\localhost\\$printerName';
//       }

//       final ProcessResult printResult = await Process.run(
//         'cmd.exe',
//         ['/c', 'copy', '/B', tempFilePath, targetPrinterPath],
//         runInShell: true,
//       );

//       if (printResult.exitCode != 0) {
//         throw Exception(
//             'เกิดข้อผิดพลาดในการพิมพ์!\nเป้าหมาย: $targetPrinterPath\nสาเหตุ: ${printResult.stderr}');
//       }
//     } finally {
//       if (await tempFile.exists()) {
//         await tempFile.delete();
//       }
//     }
//   }
// }
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class WindowsPrinterService {
  // ดึงรายชื่อเครื่องปริ้นเตอร์ทั้งหมดในเครื่อง (ทั้งต่อสายและวงแลน)
  Future<List<String>> getInstalledPrinters() async {
    final printers = await Printing.listPrinters();
    return printers.where((p) => p.isAvailable).map((p) => p.name).toList();
  }

  // ส่ง PDF เข้าเครื่องปริ้นตรงๆ
  Future<void> printPdfData({
    required String printerName,
    required Uint8List pdfBytes,
  }) async {
    // หา Printer object จากชื่อที่ผู้ใช้เลือก
    final printers = await Printing.listPrinters();
    Printer? targetPrinter;
    try {
      targetPrinter = printers.firstWhere((p) => p.name == printerName);
    } catch (e) {
      throw Exception('ไม่พบเครื่องปริ้นเตอร์ที่ชื่อ: $printerName');
    }

    // สั่งพิมพ์ (directPrintPdf จะยิงตรงเข้าเครื่องโดยไม่เด้งหน้า Preview)
    final result = await Printing.directPrintPdf(
      printer: targetPrinter,
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );

    if (!result) {
      throw Exception('ไม่สามารถส่งคำสั่งพิมพ์ไปยังเครื่องปริ้นได้');
    }
  }
}
