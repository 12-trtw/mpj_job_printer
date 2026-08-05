import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfFuelOrderBuilder {
  String _toThaiText(double? numVal) {
    if (numVal == null || numVal == 0) return 'ศูนย์';
    final d = [
      'ศูนย์',
      'หนึ่ง',
      'สอง',
      'สาม',
      'สี่',
      'ห้า',
      'หก',
      'เจ็ด',
      'แปด',
      'เก้า'
    ];
    final p = ['', 'สิบ', 'ร้อย', 'พัน', 'หมื่น', 'แสน', 'ล้าน'];
    String str = numVal.floor().toString();
    String res = '';
    for (int i = 0; i < str.length; i++) {
      int n = int.parse(str[i]);
      int pos = str.length - 1 - i;
      if (n != 0) {
        if (pos == 1 && n == 1) {
          res += 'สิบ';
        } else if (pos == 1 && n == 2) {
          res += 'ยี่สิบ';
        } else if (pos == 0 &&
            n == 1 &&
            str.length > 1 &&
            str[str.length - 2] != '0') {
          res += 'เอ็ด';
        } else {
          res += d[n] + p[pos];
        }
      }
    }
    return res;
  }

  Future<Uint8List> buildPdf(
      List<Map<String, dynamic>> printData, Uint8List fontBytes,
      {String printByUsername = ''}) async {
    await initializeDateFormatting('th_TH', null);
    await initializeDateFormatting('en_GB', null);

    final doc = pw.Document();
    final ttf = pw.Font.ttf(fontBytes.buffer.asByteData());

    final style12Cpi = pw.TextStyle(font: ttf, fontSize: 10);
    final style10Cpi =
        pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold);

    // ขนาดกระดาษ 8.5 x 5.5 นิ้ว (ต่อเนื่องครึ่งแผ่น)
    final pageFormat =
        PdfPageFormat(8.5 * PdfPageFormat.inch, 5.5 * PdfPageFormat.inch);

    const double charWidth12 = 6.0; // 12 CPI = 6pt/char
    const double linePitch = 12.0; // 6 LPI = 12pt/line

    pw.Widget _pos(String text, int col, int line, {pw.TextStyle? fontStyle}) {
      return pw.Positioned(
        left: (col + 3) * charWidth12,
        top: line * linePitch,
        child: pw.Text(text, style: fontStyle ?? style12Cpi),
      );
    }

    for (final item in printData) {
      final fleetId = item['fleet_id']?.toString() ?? '';
      String dateStr = '....................';
      if (item['finish_date'] != null &&
          !item['finish_date'].toString().startsWith('0000-00-00')) {
        try {
          final d = DateTime.parse(item['finish_date'].toString());
          dateStr = DateFormat('d MMM yyyy', 'th_TH').format(d);
        } catch (_) {}
      }

      final printTime =
          DateFormat('dd/MM/yy HH:mm', 'en_GB').format(DateTime.now());
      final vehicle =
          item['vehicle_name']?.toString() ?? '....................';
      final driver = item['driver']?.toString() ?? '....................';
      final fuelName = item['fuel_name']?.toString() ?? '....................';
      final double fuelQtyNum = item['fuel_qty'] != null
          ? double.tryParse(item['fuel_qty'].toString()) ?? 0.0
          : 0.0;
      final fuelQty =
          fuelQtyNum > 0 ? fuelQtyNum.toStringAsFixed(2) : '..........';
      final thaiText = fuelQtyNum > 0 ? _toThaiText(fuelQtyNum) : '';
      final jobNo = item['job_no']?.toString() ??
          item['order_number']?.toString() ??
          '....................';
      final mileage =
          item['start_mileage']?.toString() ?? '....................';
      final displayUser = printByUsername.isEmpty ? '' : printByUsername;

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                _pos('MPJ Logistics Public Company Limited', 13, 0,
                    fontStyle: style10Cpi),
                _pos('[ ใบสั่งเติมน้ำมัน ]', 27, 2, fontStyle: style10Cpi),
                _pos('เลขที่ใบสั่งเติม $fleetId', 54, 2),
                _pos('-' * 80, 0, 3),
                _pos('ชื่อปั๊มที่เติม', 0, 5),
                _pos('......................', 18, 5),
                _pos('วันที่', 46, 5),
                _pos(dateStr, 56, 5),
                _pos('ทะเบียนรถที่เติม', 0, 6),
                _pos(vehicle, 18, 6),
                _pos('ชื่อ พขร.', 46, 6),
                _pos(driver, 56, 6),
                _pos('ชนิดเชื้อเพลิง', 0, 7),
                _pos(fuelName, 18, 7),
                _pos('เลขไมล์', 46, 7),
                _pos(mileage, 56, 7),
                _pos('ปริมาณ (ลิตร/กก.)', 0, 9),
                _pos(fuelQty, 18, 9),
                _pos('( $thaiText )', 28, 9),
                _pos('Job no. :', 46, 9),
                _pos(jobNo, 56, 9),
                _pos('จำนวนเงิน (บาท)', 0, 10),
                _pos('(                    )', 28, 10),
                _pos('ใบสั่งเติมน้ำมันมีอายุสามวันนับจากวันที่ระบุในบิลนี้', 0,
                    12),
                _pos('ลงชื่อ .................... พนักงานขับรถ', 0, 14),
                _pos('ลงชื่อ .................... ผู้สั่งเติม', 46, 14),
                _pos('ลงชื่อ .................... พนักงานปั๊มน้ำมัน', 0, 16),
                _pos('USER ID: ${displayUser.padRight(8)} $printTime', 46, 16),
                _pos('หมายเหตุ : ...................', 0, 18),
                _pos('FM-OP-40, Rev01 (19-05-68)', 45, 18),
              ],
            );
          },
        ),
      );
    }
    return await doc.save();
  }
}
