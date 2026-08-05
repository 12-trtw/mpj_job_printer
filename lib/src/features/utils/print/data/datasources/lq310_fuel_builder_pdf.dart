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
      if (displayUser.length > 12) displayUser = displayUser.substring(0, 12);

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.only(left: 30, top: 20, right: 20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                    child: pw.Text('MPJ Logistics Public Company Limited',
                        style: style)),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('[ ใบสั่งเติมน้ำมัน ]', style: style),
                    pw.SizedBox(width: 40),
                    pw.Text('เลขที่ใบสั่งเติม $fleetId', style: style),
                  ],
                ),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 10),

                // จัดคอลัมน์ซ้าย (กว้าง 280) และขวา
                _buildRow('ชื่อปั๊มที่เติม', '......................', 'วันที่',
                    dateStr, style),
                _buildRow(
                    'ทะเบียนรถที่เติม', vehicle, 'ชื่อ พขร.', driver, style),
                _buildRow(
                    'ชนิดเชื้อเพลิง', fuelName, 'เลขไมล์', mileage, style),
                _buildRow('ปริมาณ (ลิตร/กก.)', '$fuelQty   ( $thaiText )',
                    'Job no. :', jobNo, style),
                _buildRow('จำนวนเงิน (บาท)',
                    '..........   ( .................... )', '', '', style),

                pw.SizedBox(height: 15),
                pw.Text('ใบสั่งเติมน้ำมันมีอายุสามวันนับจากวันที่ระบุในบิลนี้',
                    style: style),
                pw.SizedBox(height: 15),

                _buildRow('ลงชื่อ', '.................. พนักงานขับรถ', 'ลงชื่อ',
                    '.................. ผู้สั่งเติม', style),
                _buildRow('ลงชื่อ', '.................. พนักงานปั๊มน้ำมัน',
                    'USER ID:', '$displayUser  $printTime', style),

                pw.Spacer(),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('หมายเหตุ : ...................', style: style),
                      pw.Text('FM-OP-40, Rev01 (19-05-68)', style: style),
                    ])
              ],
            );
          },
        ),
      );
    }
    return await doc.save();
  }

  pw.Widget _buildRow(String label1, String val1, String label2, String val2,
      pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
              width: 280,
              child: pw.Row(children: [
                pw.SizedBox(width: 90, child: pw.Text(label1, style: style)),
                pw.Expanded(child: pw.Text(val1, style: style)),
              ])),
          if (label2.isNotEmpty)
            pw.SizedBox(width: 60, child: pw.Text(label2, style: style)),
          pw.Expanded(child: pw.Text(val2, style: style)),
        ],
      ),
    );
  }
}
