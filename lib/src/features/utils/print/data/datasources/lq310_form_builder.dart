import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import 'package:intl/intl.dart';
import '../../../thai_print_utils.dart';

class Lq310FormBuilder {
  static const String escInit = '\x1B\x40';
  static const String escPageLen = '\x1B\x43\x21';
  static const String escCancelSkip = '\x1B\x4F';
  static const String escThaiTis620 = '\x1B\x74\x15';
  static const String escThai3Pass = '\x1C\x70\x03';
  static const String font12Cpi = '\x1B\x4D';

  String _printWithOffset(String text, int downOffset) {
    if (text.isEmpty) text = '';
    if (downOffset == 0) return '$text\r\n';
    return '\x1B\x4A${String.fromCharCode(downOffset)}$text\r\x1B\x4A${String.fromCharCode(36 - downOffset)}';
  }

  String _formatThaiDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final d = DateTime.parse(dateString);
      return DateFormat('d MMM yyyy', 'th_TH').format(d);
    } catch (_) {
      return dateString;
    }
  }

  String _formatTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final d = DateTime.parse(dateString);
      return DateFormat('HH:mm', 'th_TH').format(d);
    } catch (_) {
      return dateString;
    }
  }

  Future<Uint8List> buildPrintBuffer(
      List<Map<String, dynamic>> printData) async {
    final StringBuffer contentBuffer = StringBuffer();

    for (final item in printData) {
      String formContent =
          '$escInit$escPageLen$escCancelSkip$font12Cpi$escThaiTis620$escThai3Pass';
      final List<String> formLines = List.filled(33, '');

      final jobNo = item['job_no']?.toString() ?? '';
      final jobStartStr = item['job_start'] != null
          ? '${_formatThaiDate(item['job_start'])} ${_formatTime(item['job_start'])}'
          : '';
      final customer = item['customer_name']?.toString() ?? '';
      final bookingNo = item['booking_no']?.toString() ?? '';

      final size = item['container_size']?.toString() ?? '';
      final containerNo = item['container_no']?.toString() ?? '';
      final seal = item['seal_desc']?.toString() ?? '';

      final drop1 = item['drop1']?.toString() ?? '';
      final drop2 = item['drop2']?.toString() ?? '';
      final drop3 = item['drop3']?.toString() ?? '';
      final drop4 = item['drop4']?.toString() ?? '';

      final jobEndDate = _formatThaiDate(item['job_end']);
      final jobEndTime = _formatTime(item['job_end']);

      final driver = item['driver']?.toString() ?? '';
      final carNo = item['vehicle_name']?.toString() ?? '';
      final carCode = item['veh_code']?.toString() ?? '';

      formLines[0] = ThaiPrintUtils.buildLine([PrintItem(jobNo, 67)]);
      formLines[3] = ThaiPrintUtils.buildLine([PrintItem(jobStartStr, 4)]);
      formLines[4] = ThaiPrintUtils.buildLine([PrintItem(customer, 8)]);
      formLines[6] = ThaiPrintUtils.buildLine([PrintItem(bookingNo, 52)]);
      formLines[8] = ThaiPrintUtils.buildLine(
          [PrintItem(drop1, 23), PrintItem(drop2, 54)]);
      formLines[9] = ThaiPrintUtils.buildLine([
        PrintItem(size, 1),
        PrintItem(containerNo, 20),
        PrintItem(seal, 73)
      ]);
      formLines[10] = ThaiPrintUtils.buildLine(
          [PrintItem(drop3, 23), PrintItem(drop4, 54)]);
      formLines[12] = ThaiPrintUtils.buildLine(
          [PrintItem(jobEndDate, 18), PrintItem(jobEndTime, 50)]);
      formLines[14] = ThaiPrintUtils.buildLine([
        PrintItem(driver, 12),
        PrintItem(carNo, 48),
        PrintItem(carCode, 72)
      ]);
      formLines[17] = ThaiPrintUtils.buildLine([PrintItem(driver, 54)]);

      for (int i = 0; i <= 17; i++) {
        if (i == 8)
          formContent += _printWithOffset(formLines[i], 12);
        else if (i == 9)
          formContent += _printWithOffset(formLines[i], 18);
        else if (i == 10)
          formContent += _printWithOffset(formLines[i], 26);
        else if (i == 12)
          formContent += _printWithOffset(formLines[i], 32);
        else if (i == 14)
          formContent += _printWithOffset(formLines[i], 28);
        else
          formContent += _printWithOffset(formLines[i], 0);
      }

      formContent += '\r\n' * 5;
      contentBuffer.write(formContent);
    }

    final Uint8List? tis620Bytes =
        await CharsetConverter.encode('TIS620', contentBuffer.toString());
    if (tis620Bytes == null) {
      throw Exception('ไม่สามารถเข้ารหัสภาษาไทย TIS-620 ได้');
    }
    return tis620Bytes;
  }
}
