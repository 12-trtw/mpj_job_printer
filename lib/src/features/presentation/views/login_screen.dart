import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpj_job_printer/src/features/presentation/controller/auth_controller.dart';
import 'dashboard_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  void _handleLogin() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('กรุณากรอก Username และ Password'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).login(
          _usernameCtrl.text.trim(),
          _passwordCtrl.text.trim(),
        );

    if (success) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      if (!mounted) return;
      final errorMsg = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          Positioned(
            top: 20,
            right: 20,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: authState.isDemoMode
                        ? Colors.red.shade600
                        : Colors.green.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    authState.isDemoMode ? 'DEMO MODE' : 'PRODUCTION',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<bool>(
                  icon: const Icon(Icons.settings, color: Colors.grey),
                  tooltip: 'ตั้งค่า',
                  offset: const Offset(0, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onSelected: (bool isDemo) {
                    authNotifier.setEnvironment(isDemo);
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<bool>(
                      value: false,
                      child: Row(
                        children: [
                          Icon(Icons.rocket_launch,
                              color: !authState.isDemoMode
                                  ? Colors.green
                                  : Colors.grey,
                              size: 20),
                          const SizedBox(width: 12),
                          Text('Production',
                              style: TextStyle(
                                  fontWeight: !authState.isDemoMode
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<bool>(
                      value: true,
                      child: Row(
                        children: [
                          Icon(Icons.bug_report,
                              color: authState.isDemoMode
                                  ? Colors.red
                                  : Colors.grey,
                              size: 20),
                          const SizedBox(width: 12),
                          Text('Demo',
                              style: TextStyle(
                                  fontWeight: authState.isDemoMode
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1), blurRadius: 10)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_shipping,
                      size: 60, color: Color(0xFFF97316)),
                  const SizedBox(height: 16),
                  const Text('MPJ Print Management',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: authState.isLoading ? null : _handleLogin,
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('เข้าสู่ระบบ',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
