import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import '../../../thai_print_utils.dart';

class Lq310FormBuilder {
  static const String escInit = '\x1B\x40';
  static const String escPageLen = '\x1B\x43\x21';
  static const String escCancelSkip = '\x1B\x4F';
  static const String escThaiTis620 = '\x1B\x74\x15';
  static const String escThai3Pass = '\x1C\x70\x03';
  static const String font12Cpi = '\x1B\x4D';

  static const List<String> _thaiMonths = [
    '',
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.'
  ];

  String _printWithOffset(String text, int downOffset) {
    if (text.isEmpty) text = '';
    if (downOffset == 0) return '$text\r\n';
    return '\x1B\x4A${String.fromCharCode(downOffset)}$text\r\x1B\x4A${String.fromCharCode(36 - downOffset)}';
  }

  String _formatThaiDate(String? dateString) {
    if (dateString == null ||
        dateString.isEmpty ||
        dateString.startsWith('0000-00-00')) return '';
    try {
      final d = DateTime.parse(dateString);
      return '${d.day} ${_thaiMonths[d.month]} ${d.year + 543}';
    } catch (_) {
      return dateString.split(RegExp(r'[ T]')).first;
    }
  }

  String _formatTime(String? dateString) {
    if (dateString == null ||
        dateString.isEmpty ||
        dateString.startsWith('0000-00-00')) return '';
    try {
      final d = DateTime.parse(dateString);
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (_) {
      final parts = dateString.split(RegExp(r'[ T]'));
      if (parts.length > 1) {
        final timeStr = parts[1];
        return timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr;
      }
      return '';
    }
  }

  Future<Uint8List> buildPrintBuffer(
      List<Map<String, dynamic>> printData) async {
    final StringBuffer contentBuffer = StringBuffer();

    for (final item in printData) {
      String formContent =
          '$escInit$escPageLen$escCancelSkip$font12Cpi$escThaiTis620$escThai3Pass';
      final List<String> formLines = List.filled(33, '');

      final jobNo =
          item['job_no']?.toString() ?? item['order_number']?.toString() ?? '';

      final String? actualJobStart =
          (item['job_start'] != null && item['job_start'].toString().isNotEmpty)
              ? item['job_start'].toString()
              : item['order_start_date']?.toString();

      final String? actualJobEnd =
          (item['job_end'] != null && item['job_end'].toString().isNotEmpty)
              ? item['job_end'].toString()
              : item['order_end_date']?.toString();

      final jobStartStr = actualJobStart != null && actualJobStart.isNotEmpty
          ? '${_formatThaiDate(actualJobStart)} ${_formatTime(actualJobStart)}'
          : '';

      final jobEndDate = _formatThaiDate(actualJobEnd);
      final jobEndTime = _formatTime(actualJobEnd);
      final consignee = item['consignee_name']?.toString() ?? '';
      final customer = item['customer_name']?.toString() ?? '';
      final bookingNo = item['booking_no']?.toString() ?? '';
      final agent = item['agent']?.toString() ?? '';
      final size = item['container_size']?.toString() ?? '';
      final containerNo = item['container_no']?.toString() ?? '';
      final seal = item['seal_desc']?.toString() ?? '';

      final drop1 = item['drop1']?.toString() ?? '';
      final drop2 = item['drop2']?.toString() ?? '';
      final drop3 = item['drop3']?.toString() ?? '';
      // final drop4 = item['drop4']?.toString() ?? '';

      final driver = item['driver']?.toString() ?? '';
      final carNo = item['vehicle_name']?.toString() ?? '';
      final carCode = item['veh_code']?.toString() ?? '';

      formLines[0] = ThaiPrintUtils.buildLine([PrintItem(jobNo, 67)]);
      formLines[3] = ThaiPrintUtils.buildLine([PrintItem(jobStartStr, 4)]);
      formLines[4] = ThaiPrintUtils.buildLine([PrintItem(customer, 8)]);
      formLines[5] = ThaiPrintUtils.buildLine([PrintItem(agent, 8)]);
      formLines[6] = ThaiPrintUtils.buildLine(
          [PrintItem(consignee, 8), PrintItem(bookingNo, 52)]);
      formLines[8] = ThaiPrintUtils.buildLine(
          [PrintItem(drop1, 23), PrintItem(drop2, 54)]);
      formLines[9] = ThaiPrintUtils.buildLine([
        PrintItem(size, 1),
        PrintItem(containerNo, 20),
        PrintItem(seal, 73)
      ]);
      if (drop3.trim().isNotEmpty) {
        formLines[10] = ThaiPrintUtils.buildLine(
            [PrintItem(drop2, 23), PrintItem(drop3, 54)]);
      }
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
