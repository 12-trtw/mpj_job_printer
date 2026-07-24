import 'dart:convert';
import 'package:http/http.dart' as http;

class PrintRepository {
  Future<Map<String, dynamic>> fetchReportData({
    required String mode,
    required String startDate,
    required String endDate,
    required int page,
    required int limit,
    String keyword = '',
  }) async {
    final String apiUrl = mode == 'job'
        ? 'http://tmsthai.com:9100/mpj-v1/report/order-job'
        : 'http://tmsthai.com:9100/mpj-v1/report/order-fuel';

    final Map<String, dynamic> payload = {
      "start_date": startDate,
      "end_date": endDate,
      "page": page,
      "limit": limit,
      "keyword": keyword,
      "approve_status": "",
      "cost_status": ""
    };

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'license': 'mpj',
            },
            body: jsonEncode([payload]),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
            'เซิร์ฟเวอร์ตอบกลับผิดพลาด (HTTP ${response.statusCode})');
      }

      final dynamic decodedJson = jsonDecode(utf8.decode(response.bodyBytes));

      Map<String, dynamic> responseData;

      if (decodedJson is Map<String, dynamic>) {
        responseData = decodedJson;
      } else if (decodedJson is List && decodedJson.isNotEmpty) {
        responseData = decodedJson[0];
      } else {
        throw Exception('รูปแบบข้อมูล JSON จาก API ไม่ถูกต้อง');
      }

      if (responseData['status'] == 'success') {
        return responseData;
      } else {
        final errorMsg = responseData['message'] ?? 'ไม่มีข้อความอธิบาย';
        throw Exception('API แจ้งเตือน: $errorMsg');
      }
    } catch (e) {
      throw Exception('ไม่สามารถดึงข้อมูลจากระบบ TMS ได้: $e');
    }
  }
}
