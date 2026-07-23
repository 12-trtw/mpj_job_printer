import 'dart:convert';
import 'package:http/http.dart' as http;

class TmsRemoteDataSource {
  static const String _apiUrl =
      'http://tmsthai.com:9100/mpj-v1/report/job-info';

  Future<List<Map<String, dynamic>>> fetchJobOrders({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final Uri uri = Uri.parse(_apiUrl);

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'license': 'mpj',
            },
            body: jsonEncode([
              {
                "job_no": [],
                "start_date": startDate,
                "end_date": endDate,
                "page": 1,
                "limit": 999
              }
            ]),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('TMS API Error: HTTP ${response.statusCode}');
      }

      final List<dynamic> decodedJson =
          jsonDecode(utf8.decode(response.bodyBytes));

      if (decodedJson.isNotEmpty && decodedJson[0]['status'] == 'success') {
        final List<dynamic> rawData = decodedJson[0]['data'] ?? [];
        return rawData.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'เซิร์ฟเวอร์ปฏิเสธการดึงข้อมูล: ${decodedJson.toString()}');
      }
    } catch (e) {
      throw Exception('ไม่สามารถเชื่อมต่อ TMS API ได้: $e');
    }
  }
}
