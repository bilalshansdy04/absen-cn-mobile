import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'change_password_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _openServerSettings() async {
    final current = await ApiConfig.getBaseUrl();
    if (!mounted) return;
    final ctrl = TextEditingController(text: current);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alamat Server API'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Base URL',
            hintText: 'https://domain-anda.vercel.app',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiConfig.setBaseUrl(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (_codeCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'ID Karyawan dan kata sandi wajib diisi.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.login(_codeCtrl.text, _passCtrl.text);
      final user = data['user'] as Map<String, dynamic>;
      final isFirstLogin = user['is_first_login'] == true;

      if (!mounted) return;
      if (isFirstLogin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChangePasswordScreen(
              user: user,
              isForced: true,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(user: user),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF475569)),
            tooltip: 'Pengaturan Server API',
            onPressed: _openServerSettings,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 48,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Presensi Lapangan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Masuk menggunakan ID Karyawan Anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'ID Karyawan',
                        hintText: 'Contoh: CHK-001',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Masuk',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
