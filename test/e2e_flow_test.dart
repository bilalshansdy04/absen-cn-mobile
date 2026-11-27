import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:absen_mobile/config/api_config.dart';
import 'package:absen_mobile/screens/login_screen.dart';
import 'package:absen_mobile/screens/home_screen.dart';
import 'package:absen_mobile/services/api_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    ApiConfig.baseUrlOverride = 'http://localhost:3000';
    ApiService.skipSecureStorage = true;
  });

  tearDown(() {
    ApiService.httpClient = http.Client();
    ApiService.inMemoryTokenOverride = null;
  });

  testWidgets(
    'E2E: Login -> Wajib Ganti Sandi -> Beranda (NOT_CHECKED_IN)',
    (WidgetTester tester) async {
      ApiService.httpClient = MockClient((req) async {
        if (req.url.path.endsWith('/api/v1/auth/login')) {
          return http.Response(
            jsonEncode({
              'token': 'jwt-mock-token',
              'user': {
                'id': 'u-1',
                'employee_code': 'MBR-014',
                'full_name': 'Budi Santoso',
                'role_code': 'fld_member',
                'role_label': 'Operasional / Checker',
                'is_first_login': true,
              },
            }),
            200,
          );
        }
        if (req.url.path.endsWith('/api/v1/auth/change-password')) {
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        if (req.url.path.endsWith('/api/v1/attendance/status')) {
          return http.Response(
            jsonEncode({
              'server_time_wib': '2026-11-28T07:30:00+07:00',
              'today_date': '2026-11-28',
              'status': 'NOT_CHECKED_IN',
              'today_log': null,
              'history': [],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      await tester.enterText(find.byType(TextField).at(0), 'MBR-014');
      await tester.enterText(find.byType(TextField).at(1), 'Presensi#014');
      await tester.ensureVisible(find.text('Masuk'));
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Buat Kata Sandi Baru'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Rahasia123');
      await tester.enterText(find.byType(TextField).at(1), 'Rahasia123');
      await tester.ensureVisible(find.text('Simpan Kata Sandi Baru'));
      await tester.tap(find.text('Simpan Kata Sandi Baru'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Check-In Sekarang'), findsOneWidget);
      expect(find.text('Beranda'), findsOneWidget);
    },
  );

  testWidgets(
    'E2E: Animated BottomNav (Beranda -> Riwayat -> Foto In/Out -> Profil)',
    (WidgetTester tester) async {
      ApiService.inMemoryTokenOverride = 'jwt-mock-token';
      ApiService.httpClient = MockClient((req) async {
        if (req.url.path.endsWith('/api/v1/attendance/status')) {
          return http.Response(
            jsonEncode({
              'server_time_wib': '2026-11-28T17:15:00+07:00',
              'today_date': '2026-11-28',
              'status': 'COMPLETED',
              'today_log': {
                'id': 'log-1',
                'attendance_date': '2026-11-28',
                'check_in_at': '2026-11-28T08:00:00+07:00',
                'check_in_address': 'Jl. Raya Gempol, Pasuruan',
                'check_in_tg_file_id': 'tg-in-123',
                'check_out_at': '2026-11-28T17:00:00+07:00',
                'check_out_address': 'Jl. Raya Gempol, Pasuruan',
                'check_out_tg_file_id': 'tg-out-456',
              },
              'history': [
                {
                  'id': 'log-1',
                  'attendance_date': '2026-11-28',
                  'check_in_at': '2026-11-28T08:00:00+07:00',
                  'check_in_address': 'Jl. Raya Gempol, Pasuruan',
                  'check_in_tg_file_id': 'tg-in-123',
                  'check_out_at': '2026-11-28T17:00:00+07:00',
                  'check_out_address': 'Jl. Raya Gempol, Pasuruan',
                  'check_out_tg_file_id': 'tg-out-456',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(
            user: {
              'id': 'u-1',
              'employee_code': 'MBR-014',
              'full_name': 'Budi Santoso',
              'role_label': 'Operasional / Checker',
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Presensi Hari Ini Selesai'), findsOneWidget);
      expect(find.text('Durasi Kerja: 9 jam 0 menit'), findsOneWidget);

      // Pindah ke tab Riwayat
      await tester.tap(find.byIcon(Icons.history_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('1 Hari (1 Selesai)'), findsOneWidget);
      expect(find.text('9 jam 0 mnt'), findsOneWidget);

      final photoHint = find.text('Ketuk untuk lihat foto In / Out');
      await tester.ensureVisible(photoHint);
      await tester.pump();
      await tester.tap(photoHint);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Lihat Foto Check-In (In)'), findsOneWidget);
      expect(find.text('Lihat Foto Check-Out (Out)'), findsOneWidget);

      // Tutup bottom sheet
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Pindah ke tab Profil
      await tester.tap(find.byIcon(Icons.person_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Ubah Kata Sandi'), findsOneWidget);
      expect(find.text('Keluar dari Akun'), findsOneWidget);
    },
  );
}
