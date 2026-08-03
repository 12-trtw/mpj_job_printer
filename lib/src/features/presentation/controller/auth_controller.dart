import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final bool isLoading;
  final bool isDemoMode;
  final String? username;
  final String? driverName;
  final String error;

  AuthState({
    this.isLoading = false,
    this.isDemoMode = false,
    this.username,
    this.driverName,
    this.error = '',
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isDemoMode,
    String? username,
    String? driverName,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      username: username ?? this.username,
      driverName: driverName ?? this.driverName,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  String get _baseUrl => state.isDemoMode
      ? 'http://tmsthai.com:9100/mpj-v1' // DEMO
      : 'https://tms.mpjdc.com:7049/mpj-v1'; // Production

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

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));

        if (decoded is List &&
            decoded.isNotEmpty &&
            decoded[0]['status'] == 'success') {
          final data = decoded[0]['data'][0];
          final loggedInUser = data['username']?.toString();
          final fName = data['user_fname']?.toString() ?? '';
          final lName = data['user_lname']?.toString() ?? '';

          state = state.copyWith(
            isLoading: false,
            username: loggedInUser,
            driverName: '$fName $lName'.trim(),
          );
          return true;
        } else {
          state = state.copyWith(
              isLoading: false, error: 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง');
          return false;
        }
      } else {
        state = state.copyWith(
            isLoading: false,
            error: 'เซิร์ฟเวอร์มีปัญหา: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'เชื่อมต่อเซิร์ฟเวอร์ล้มเหลว กรุณาลองใหม่');
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
