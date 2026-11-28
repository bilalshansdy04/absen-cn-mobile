import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isForced;

  const ChangePasswordScreen({
    super.key,
    required this.user,
    this.isForced = false,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pass = _passCtrl.text;
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(pass);
    final hasNumber = RegExp(r'[0-9]').hasMatch(pass);

    if (pass.length < 8 || !hasLetter || !hasNumber) {
      setState(() {
        _error =
            'Kata sandi minimal 8 karakter dan wajib kombinasi huruf serta angka.';
      });
      return;
    }

    if (pass != _confirmCtrl.text) {
      setState(() => _error = 'Konfirmasi kata sandi tidak cocok.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService.changePassword(pass);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kata sandi berhasil diperbarui.')),
      );

      if (widget.isForced) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(user: widget.user)),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isForced,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Buat Kata Sandi Baru'),
          automaticallyImplyLeading: !widget.isForced,
          actions: [
            if (widget.isForced)
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await ApiService.clearToken();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isForced)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'Demi keamanan, Anda wajib mengganti kata sandi bawaan sebelum dapat melakukan presensi.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                  ),
                ),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
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
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Baru',
                  hintText: 'Minimal 8 karakter (huruf & angka)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Ulangi Kata Sandi Baru',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
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
                    : const Text('Simpan Kata Sandi Baru'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
