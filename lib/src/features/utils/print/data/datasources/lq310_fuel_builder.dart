import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import 'package:intl/intl.dart';
import '../../../thai_print_utils.dart';
import 'package:intl/date_symbol_data_local.dart';

class Lq310FuelOrderBuilder {
  static const String escInit = '\x1B\x40';
  static const String escPageLen = '\x1B\x43\x21';
  static const String escCancelSkip = '\x1B\x4F';
  static const String escThaiTis620 = '\x1B\x74\x15';
  static const String escThaiITP = '\x1C\x70\x00';

  static const String font10Cpi = '\x1B\x50';
  static const String font12Cpi = '\x1B\x4D';
  static const String font15Cpi = '\x1B\x67';

  static const String escLeftMargin0 = '\x1B\x6C\x00';

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

  String _padRight(String str, int targetLength) {
    final dLen = ThaiPrintUtils.displayLength(str);
    if (dLen >= targetLength) return str;
    return str + (' ' * (targetLength - dLen));
  }

  Future<Uint8List> buildPrintBuffer(List<Map<String, dynamic>> printData,
      {String printByUsername = ''}) async {
    await initializeDateFormatting('th_TH', null);
    await initializeDateFormatting('en_GB', null);

    final String escSetTab = '\x1B\x44${String.fromCharCode(48)}\x00';
    final StringBuffer contentBuffer = StringBuffer();

    for (final item in printData) {
      String formContent =
          '$escInit$escLeftMargin0$escPageLen$escCancelSkip$font12Cpi$escThaiTis620$escThaiITP$escSetTab';

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
          '             $font10Cpi MPJ Logistics Public Company Limited$font12Cpi';
      formLines[2] =
          '                         [ ใบสั่งเติมน้ำมัน ]\tเลขที่ใบสั่งเติม $fleetId';
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
        formContent += formLines[i] + '\r\n';
      }

      formContent += '\r\n' * 4;

      contentBuffer.write(formContent);
    }

    final Uint8List? tis620Bytes =
        await CharsetConverter.encode('TIS620', contentBuffer.toString());
    if (tis620Bytes == null)
      throw Exception('ไม่สามารถเข้ารหัสภาษาไทย TIS-620 ได้');
    return tis620Bytes;
  }
}
