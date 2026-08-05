import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final bool isLoading;
  final bool isDemoMode;
  final String? username;
  final String? employeeName;
  final String error;

  AuthState({
    this.isLoading = false,
    this.isDemoMode = false,
    this.username,
    this.employeeName,
    this.error = '',
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isDemoMode,
    String? username,
    String? employeeName,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      username: username ?? this.username,
      employeeName: employeeName ?? this.employeeName,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  String get _baseUrl => state.isDemoMode
      ? 'http://tmsthai.com:9100/mpj-v1'
      : 'https://tms.mpjdc.com:7049/mpj-v1';

  void setEnvironment(bool isDemo) {
    state = state.copyWith(isDemoMode: isDemo, error: '');
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: '');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/employee/login'),
            headers: {
              'Content-Type': 'application/json',
              'auth':
                  'd7b2b7793038644a54392c1f1113128ef0dd0504b806d8eec2fc8e17c3e78920',
              'license': 'mpj'
            },
            body: jsonEncode([
              {"username": username, "password": password}
            ]),
          )
          .timeout(const Duration(seconds: 15));

      dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {}

      String? apiMessage;
      if (decoded is List && decoded.isNotEmpty) {
        apiMessage = decoded[0]['message']?.toString();

        if (decoded[0]['status'] == 'success') {
          final dataList = decoded[0]['data'];
          if (dataList is List && dataList.isNotEmpty) {
            final data = dataList[0];
            final loggedInUser = data['user_name']?.toString() ?? username;
            final fName = data['user_fname']?.toString() ?? '';
            final lName = data['user_lname']?.toString() ?? '';

            state = state.copyWith(
              isLoading: false,
              username: loggedInUser,
              employeeName: '$fName $lName'.trim(),
            );
            return true;
          }
        }
      } else if (decoded is Map) {
        apiMessage = decoded['message']?.toString();
      }

      final errorMsg = apiMessage ??
          (response.statusCode == 200
              ? 'รูปแบบข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง'
              : 'เซิร์ฟเวอร์มีปัญหา: HTTP ${response.statusCode}');

      state = state.copyWith(isLoading: false, error: errorMsg);
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'เชื่อมต่อเซิร์ฟเวอร์ล้มเหลว ($e)');
      return false;
    }
  }

  void logout() {
    state = AuthState(isDemoMode: state.isDemoMode);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
