import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../thai_print_utils.dart'; // ตรวจสอบ path ให้ตรงกับโปรเจกต์ของคุณ

class Lq310FuelOrderBuilder {
  // แปลงตัวเลขเป็นคำอ่านภาษาไทย
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

  Future<Uint8List> buildPrintBuffer(List<Map<String, dynamic>> printData,
      {String printByUsername = ''}) async {
    await initializeDateFormatting('th_TH', null);
    await initializeDateFormatting('en_GB', null);

    final StringBuffer contentBuffer = StringBuffer();

    for (final item in printData) {
      // 1. ส่งคำสั่งตั้งค่าเริ่มต้นไปยังเครื่องพิมพ์
      contentBuffer.write(Lq310Commands.escInit);
      contentBuffer.write(Lq310Commands.escLeftMargin0);
      contentBuffer.write(Lq310Commands.escPageLen);
      contentBuffer.write(Lq310Commands.font12Cpi);
      contentBuffer.write(Lq310Commands.forceTIS620); // บังคับตารางภาษาไทย
      contentBuffer.write(Lq310Commands.forceITP); // ระบบพิมพ์อัจฉริยะ (ITP)

      final List<String> formLines = List.filled(33, '');

      // 2. ดึงข้อมูลและจัดการ Format
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
      final displayUser = printByUsername.isEmpty ? '' : printByUsername;

      final vName = vehicle.length > 28 ? vehicle.substring(0, 28) : vehicle;

      // 3. เริ่มการประกอบฟอร์ม (จัด Layout แบบระบุแกน X)
      // บรรทัดที่ 0 และ 2 มีเรื่องการขยายฟอนต์ (font10Cpi) จึงใส่แยกไว้ ป้องกันการกวนตำแหน่ง X
      formLines[0] =
          '${Lq310Commands.font10Cpi}             MPJ Logistics Public Company Limited${Lq310Commands.font12Cpi}';
      formLines[2] =
          '${Lq310Commands.font10Cpi}                           [ ใบสั่งเติมน้ำมัน ]${Lq310Commands.font12Cpi}   เลขที่ใบสั่งเติม $fleetId';

      formLines[3] = '-' * 80;

      // บรรทัดที่ 5-18 ใช้ ThaiPrintUtils.buildLine เพื่อความเป๊ะของคอลัมน์
      formLines[5] = ThaiPrintUtils.buildLine([
        PrintItem('ชื่อปั๊มที่เติม', 0),
        PrintItem('......................', 18),
        PrintItem('วันที่', 46),
        PrintItem(dateStr, 56),
      ]);

      formLines[6] = ThaiPrintUtils.buildLine([
        PrintItem('ทะเบียนรถที่เติม', 0),
        PrintItem(vName, 18),
        PrintItem('ชื่อ พขร.', 46),
        PrintItem(driver, 56),
      ]);

      formLines[7] = ThaiPrintUtils.buildLine([
        PrintItem('ชนิดเชื้อเพลิง', 0),
        PrintItem(fuelName, 18),
        PrintItem('เลขไมล์', 46),
        PrintItem(mileage, 56),
      ]);

      formLines[9] = ThaiPrintUtils.buildLine([
        PrintItem('ปริมาณ (ลิตร/กก.)', 0),
        PrintItem(fuelQty, 18),
        PrintItem('( $thaiText )', 28),
        PrintItem('Job no. :', 46),
        PrintItem(jobNo, 56),
      ]);

      formLines[10] = ThaiPrintUtils.buildLine([
        PrintItem('จำนวนเงิน (บาท)', 0),
        PrintItem('(                    )', 28),
      ]);

      formLines[12] = ThaiPrintUtils.buildLine([
        PrintItem('ใบสั่งเติมน้ำมันมีอายุสามวันนับจากวันที่ระบุในบิลนี้', 0),
      ]);

      formLines[14] = ThaiPrintUtils.buildLine([
        PrintItem('ลงชื่อ .................... พนักงานขับรถ', 0),
        PrintItem('ลงชื่อ .................... ผู้สั่งเติม', 46),
      ]);

      formLines[16] = ThaiPrintUtils.buildLine([
        PrintItem('ลงชื่อ .................... พนักงานปั๊มน้ำมัน', 0),
        PrintItem('USER ID: ${displayUser.padRight(8)} $printTime', 46),
      ]);

      formLines[18] = ThaiPrintUtils.buildLine([
        PrintItem('หมายเหตุ : ...................', 0),
        PrintItem('FM-OP-40, Rev01 (19-05-68)', 45),
      ]);

      // 4. เขียนลง Buffer
      for (int i = 0; i <= 18; i++) {
        contentBuffer.write(formLines[i]);
        contentBuffer.write('\r\n');
      }

      contentBuffer.write('\r\n' * 4);
      contentBuffer.write(Lq310Commands.formFeed); // ดันกระดาษขึ้นหน้าใหม่
    }

    // 5. แปลงเป็น TIS-620 Bytes
    final Uint8List? tis620Bytes =
        await CharsetConverter.encode('TIS620', contentBuffer.toString());
    if (tis620Bytes == null)
      throw Exception('ไม่สามารถเข้ารหัสภาษาไทย TIS-620 ได้');

    return tis620Bytes;
  }
}
