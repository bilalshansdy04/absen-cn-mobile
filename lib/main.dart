import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/change_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const PresensiApp());
}

class PresensiApp extends StatelessWidget {
  const PresensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presensi Lapangan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF059669)),
        useMaterial3: true,
      ),
      home: const _BootstrapScreen(),
    );
  }
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await ApiService.getToken();
    if (token == null) {
      _goTo(const LoginScreen());
      return;
    }

    try {
      final data = await ApiService.getMe();
      final user = data['user'] as Map<String, dynamic>;
      if (user['is_first_login'] == true) {
        _goTo(ChangePasswordScreen(user: user, isForced: true));
      } else {
        _goTo(HomeScreen(user: user));
      }
    } catch (_) {
      await ApiService.clearToken();
      _goTo(const LoginScreen());
    }
  }

  void _goTo(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/logo.png',
                width: 96,
                height: 96,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Presensi Lapangan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Memeriksa sesi...',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF059669),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
