import 'dart:typed_data';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfJobOrderBuilder {
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
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Future<Uint8List> buildPdf(
      List<Map<String, dynamic>> printData, Uint8List fontBytes) async {
    await initializeDateFormatting('th_TH', null);
    await initializeDateFormatting('en_GB', null);

    final doc = pw.Document();
    final ttf = pw.Font.ttf(fontBytes.buffer.asByteData());
    final style = pw.TextStyle(font: ttf, fontSize: 11);
    final pageFormat =
        PdfPageFormat(8.5 * PdfPageFormat.inch, 5.5 * PdfPageFormat.inch);

    pw.Widget _pos(String text, int col, int line, [int downOffset = 0]) {
      return pw.Positioned(
        left: (col + 3) * 6.0,
        top: (line * 12.0) + (downOffset / 3.0),
        child: pw.Text(text, style: style),
      );
    }

    for (final item in printData) {
      final jobNo =
          item['job_no']?.toString() ?? item['order_number']?.toString() ?? '';
      final actualJobStart =
          (item['job_start'] != null && item['job_start'].toString().isNotEmpty)
              ? item['job_start'].toString()
              : item['order_start_date']?.toString();
      final jobStartStr = actualJobStart != null && actualJobStart.isNotEmpty
          ? '${_formatThaiDate(actualJobStart)} ${_formatTime(actualJobStart)}'
          : '';

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
      final driver = item['driver']?.toString() ?? '';
      final carNo = item['vehicle_name']?.toString() ?? '';
      final carCode = item['veh_code']?.toString() ?? '';

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                _pos(jobNo, 67, 0),
                _pos(jobStartStr, 4, 3),
                _pos(customer, 8, 4),
                _pos(agent, 4, 5),
                _pos(consignee, 8, 6),
                _pos(bookingNo, 52, 6),
                _pos(drop1, 23, 8, 12),
                _pos(drop2, 54, 8, 12),
                _pos(size, 1, 9, 18),
                _pos(containerNo, 20, 9, 18),
                _pos(seal, 73, 9, 18),
                if (drop3.trim().isNotEmpty) ...[
                  _pos(drop2, 23, 10, 26),
                  _pos(drop3, 54, 10, 26),
                ],
                _pos(driver, 12, 14, 28),
                _pos(carNo, 48, 14, 28),
                _pos(carCode, 72, 14, 28),
                _pos(driver, 54, 17),
              ],
            );
          },
        ),
      );
    }
    return await doc.save();
  }
}
