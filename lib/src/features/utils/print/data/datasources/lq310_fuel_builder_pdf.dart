import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

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
        if (pos == 1 && n == 1)
          res += 'สิบ';
        else if (pos == 1 && n == 2)
          res += 'ยี่สิบ';
        else if (pos == 0 &&
            n == 1 &&
            str.length > 1 &&
            str[str.length - 2] != '0')
          res += 'เอ็ด';
        else
          res += d[n] + p[pos];
      }
    }
    return res;
  }

  Future<Uint8List> buildPdf(List<Map<String, dynamic>> printData,
      {String printByUsername = ''}) async {
    await initializeDateFormatting('th_TH', null);
    await initializeDateFormatting('en_GB', null);

    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Kanit-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final style = pw.TextStyle(font: ttf, fontSize: 11);
    final pageFormat =
        PdfPageFormat(8.5 * PdfPageFormat.inch, 5.5 * PdfPageFormat.inch);

    pw.Widget _pos(String text, int col, int line) {
      return pw.Positioned(
        left: (col + 3) * 6.0,
        top: line * 12.0,
        child: pw.Text(text, style: style),
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

      final now = DateTime.now();
      final printTime = DateFormat('dd/MM/yy HH:mm', 'en_GB').format(now);
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

      String displayUser = printByUsername.isEmpty ? '' : printByUsername;
      if (displayUser.length > 8) displayUser = displayUser.substring(0, 8);

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                _pos('MPJ Logistics Public Company Limited', 13, 0),
                _pos('[ ใบสั่งเติมน้ำมัน ]', 27, 2),
                _pos('เลขที่ใบสั่งเติม $fleetId', 48, 2),
                _pos('-' * 80, 0, 3),
                _pos('ชื่อปั๊มที่เติม', 0, 5),
                _pos('......................', 18, 5),
                _pos('วันที่', 48, 5),
                _pos(dateStr, 58, 5),
                _pos('ทะเบียนรถที่เติม', 0, 6),
                _pos(vehicle, 18, 6),
                _pos('ชื่อ พขร.', 48, 6),
                _pos(driver, 58, 6),
                _pos('ชนิดเชื้อเพลิง', 0, 7),
                _pos(fuelName, 18, 7),
                _pos('เลขไมล์', 48, 7),
                _pos(mileage, 58, 7),
                _pos('ปริมาณ (ลิตร/กก.)', 0, 9),
                _pos(fuelQty, 18, 9),
                _pos('( ', 28, 9),
                _pos(thaiText, 30, 9),
                _pos(' )', 46, 9),
                _pos('Job no. :', 48, 9),
                _pos(jobNo, 58, 9),
                _pos('จำนวนเงิน (บาท)', 0, 10),
                _pos('(                  )', 28, 10),
                _pos('ใบสั่งเติมน้ำมันมีอายุสามวันนับจากวันที่ระบุในบิลนี้', 0,
                    12),
                _pos('ลงชื่อ', 0, 14),
                _pos('..................', 6, 14),
                _pos('พนักงานขับรถ', 26, 14),
                _pos('ลงชื่อ', 48, 14),
                _pos('..................', 54, 14),
                _pos('ผู้สั่งเติม', 74, 14),
                _pos('ลงชื่อ', 0, 16),
                _pos('..................', 6, 16),
                _pos('พนักงานปั๊มน้ำมัน', 26, 16),
                _pos('USER ID:', 48, 16),
                _pos(displayUser, 57, 16),
                _pos(printTime, 66, 16),
                _pos('หมายเหตุ : ...................', 0, 18),
                _pos('FM-OP-40, Rev01 (19-05-68)', 48, 18),
              ],
            );
          },
        ),
      );
    }
    return await doc.save();
  }
}
