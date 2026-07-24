import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class WindowsPrinterService {
  Future<List<String>> getInstalledPrinters() async {
    try {
      if (!Platform.isWindows) {
        return ['Epson LQ-310 (Mock for Mac/Linux)'];
      }

      final ProcessResult result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-Command',
          'Get-Printer | Select-Object -ExpandProperty Name'
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        throw Exception('ดึงข้อมูลเครื่องพิมพ์ล้มเหลว: ${result.stderr}');
      }

      final String output = result.stdout as String;
      return output
          .split('\r\n')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[WindowsPrinterService] Error: $e');
      rethrow;
    }
  }

  Future<void> printRawData({
    required String printerName,
    required Uint8List rawTis620Bytes,
  }) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String tempFilePath =
        '${tempDir.path}\\mpj_flutter_job_${DateTime.now().millisecondsSinceEpoch}.bin';
    final File tempFile = File(tempFilePath);

    try {
      await tempFile.writeAsBytes(rawTis620Bytes);

      final ProcessResult printResult = await Process.run(
        'cmd.exe',
        ['/c', 'copy', '/B', tempFilePath, r'\\localhost\LQ310'],
        runInShell: true,
      );

      if (printResult.exitCode != 0) {
        throw Exception('เกิดข้อผิดพลาดในการพิมพ์: ${printResult.stderr}');
      }
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
