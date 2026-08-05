import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../thai_print_utils.dart';

class Lq310FuelOrderBuilder {
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

  String _padRight(String str, int targetLength) {
    final dLen = ThaiPrintUtils.displayLength(str);
    if (dLen >= targetLength) return str;
    return str + (' ' * (targetLength - dLen));
  }

  Future<Uint8List> buildPrintBuffer(List<Map<String, dynamic>> printData,
      {String printByUsername = ''}) async {
    await initializeDateFormatting('th_TH', null);
    await initializeDateFormatting('en_GB', null);

    final StringBuffer contentBuffer = StringBuffer();

    for (final item in printData) {
      // ประกอบคำสั่งล้างค่าและตั้งค่าปริ้นเตอร์ (Overrides)
      contentBuffer.write(Lq310Commands.escInit);
      contentBuffer.write(Lq310Commands.escLeftMargin0);
      contentBuffer.write(Lq310Commands.escPageLen);
      contentBuffer.write(Lq310Commands.escCancelSkip);
      contentBuffer.write(Lq310Commands.font12Cpi);
      contentBuffer.write(Lq310Commands.forceTIS620); // บังคับเป็น TIS-620
      contentBuffer.write(Lq310Commands
          .forceITP); // บังคับพิมพ์อัจฉริยะ (ถ้าอยากให้เป็น 3 เที่ยว ให้เปลี่ยนเป็น force3Pass)
      contentBuffer.write(Lq310Commands.escSetTab);

      final List<String> formLines = List.filled(33, '');
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

      final l1Left = _padRight('ชื่อปั๊มที่เติม', 18) +
          _padRight('......................', 28);
      final l1Right = _padRight('วันที่', 10) + dateStr;

      final vName = vehicle.length > 28 ? vehicle.substring(0, 28) : vehicle;
      final l2Left = _padRight('ทะเบียนรถที่เติม', 18) + _padRight(vName, 28);
      final l2Right = _padRight('ชื่อ พขร.', 10) + driver;

      final l3Left = _padRight('ชนิดเชื้อเพลิง', 18) + _padRight(fuelName, 28);
      final l3Right = _padRight('เลขไมล์', 10) + mileage;

      final l4Left = _padRight('ปริมาณ (ลิตร/กก.)', 18) +
          _padRight(fuelQty, 10) +
          '( ' +
          _padRight(thaiText, 16) +
          ' )';
      final l4Right = _padRight('Job no. :', 10) + jobNo;

      final l5Left = _padRight('จำนวนเงิน (บาท)', 18) +
          _padRight('', 10) +
          '( ' +
          _padRight('', 16) +
          ' )';

      final sig1Left = _padRight('ลงชื่อ', 6) +
          _padRight('..................', 20) +
          'พนักงานขับรถ';
      final sig1Right = _padRight('ลงชื่อ', 6) +
          _padRight('..................', 20) +
          'ผู้สั่งเติม';

      final sig2Left = _padRight('ลงชื่อ', 6) +
          _padRight('..................', 20) +
          'พนักงานปั๊มน้ำมัน';
      final displayUser = printByUsername.isEmpty ? '' : printByUsername;

      final sig2Right = 'USER ID: ${_padRight(displayUser, 8)} $printTime';

      const footerLeft = 'หมายเหตุ : ...................';
      const footerRight = 'FM-OP-40, Rev01 (19-05-68)';

      formLines[0] =
          '             ${Lq310Commands.font10Cpi} MPJ Logistics Public Company Limited${Lq310Commands.font12Cpi}';
      formLines[2] =
          '                           [ ใบสั่งเติมน้ำมัน ]\tเลขที่ใบสั่งเติม $fleetId';
      formLines[3] = '-' * 80;

      formLines[5] = '$l1Left\t$l1Right';
      formLines[6] = '$l2Left\t$l2Right';
      formLines[7] = '$l3Left\t$l3Right';
      formLines[9] = '$l4Left\t$l4Right';
      formLines[10] = l5Left;

      formLines[12] = 'ใบสั่งเติมน้ำมันมีอายุสามวันนับจากวันที่ระบุในบิลนี้';

      formLines[14] = '$sig1Left\t$sig1Right';
      formLines[16] = '$sig2Left\t$sig2Right';

      formLines[18] = '${_padRight(footerLeft, 45)}\t$footerRight';

      for (int i = 0; i <= 18; i++) {
        contentBuffer.write(formLines[i]);
        contentBuffer.write('\r\n');
      }

      contentBuffer.write('\r\n' * 4);
      contentBuffer.write(Lq310Commands.formFeed); // ดันกระดาษ
    }

    final Uint8List? tis620Bytes =
        await CharsetConverter.encode('TIS620', contentBuffer.toString());
    if (tis620Bytes == null)
      throw Exception('ไม่สามารถเข้ารหัสภาษาไทย TIS-620 ได้');
    return tis620Bytes;
  }
}

// ==========================================
// 3. FORM BUILDER
// ==========================================
class Lq310FormBuilder {
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
    await initializeDateFormatting('th_TH', null);
    await initializeDateFormatting('en_GB', null);

    final StringBuffer contentBuffer = StringBuffer();

    for (final item in printData) {
      // ประกอบคำสั่งล้างค่าและตั้งค่าปริ้นเตอร์ (Overrides)
      contentBuffer.write(Lq310Commands.escInit);
      contentBuffer.write(Lq310Commands.escPageLen);
      contentBuffer.write(Lq310Commands.escCancelSkip);
      contentBuffer.write(Lq310Commands.font12Cpi);
      contentBuffer.write(Lq310Commands.forceTIS620); // บังคับเป็น TIS-620
      contentBuffer.write(Lq310Commands.forceITP); // บังคับพิมพ์อัจฉริยะ

      final List<String> formLines = List.filled(33, '');

      final jobNo =
          item['job_no']?.toString() ?? item['order_number']?.toString() ?? '';

      final String? actualJobStart =
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

      formLines[0] = ThaiPrintUtils.buildLine([PrintItem(jobNo, 67)]);
      formLines[3] = ThaiPrintUtils.buildLine([PrintItem(jobStartStr, 4)]);
      formLines[4] = ThaiPrintUtils.buildLine([PrintItem(customer, 8)]);
      formLines[5] = ThaiPrintUtils.buildLine([PrintItem(agent, 4)]);
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

      formLines[14] = ThaiPrintUtils.buildLine([
        PrintItem(driver, 12),
        PrintItem(carNo, 48),
        PrintItem(carCode, 72)
      ]);
      formLines[17] = ThaiPrintUtils.buildLine([PrintItem(driver, 54)]);

      for (int i = 0; i <= 17; i++) {
        if (i == 8)
          contentBuffer.write(_printWithOffset(formLines[i], 12));
        else if (i == 9)
          contentBuffer.write(_printWithOffset(formLines[i], 18));
        else if (i == 10)
          contentBuffer.write(_printWithOffset(formLines[i], 26));
        else if (i == 12)
          contentBuffer.write(_printWithOffset(formLines[i], 32));
        else if (i == 14)
          contentBuffer.write(_printWithOffset(formLines[i], 28));
        else
          contentBuffer.write(_printWithOffset(formLines[i], 0));
      }

      contentBuffer.write('\r\n' * 5);
      contentBuffer.write(Lq310Commands.formFeed); // ดันกระดาษ
    }

    final Uint8List? tis620Bytes =
        await CharsetConverter.encode('TIS620', contentBuffer.toString());
    if (tis620Bytes == null) {
      throw Exception('ไม่สามารถเข้ารหัสภาษาไทย TIS-620 ได้');
    }
    return tis620Bytes;
  }
}
