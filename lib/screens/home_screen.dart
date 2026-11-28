import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'camera_attendance_screen.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  String _status = 'NOT_CHECKED_IN';
  Map<String, dynamic>? _todayLog;
  List<Map<String, dynamic>> _history = [];

  Duration _serverOffset = Duration.zero;
  DateTime _nowServer = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _nowServer = DateTime.now().add(_serverOffset);
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getAttendanceStatus(days: 30);
      final serverIso = data['server_time_wib']?.toString();
      if (serverIso != null) {
        final serverDt = DateTime.parse(serverIso).toLocal();
        _serverOffset = serverDt.difference(DateTime.now());
      }

      final rawHistory = (data['history'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      setState(() {
        _status = data['status']?.toString() ?? 'NOT_CHECKED_IN';
        _todayLog = data['today_log'] as Map<String, dynamic>?;
        _history = rawHistory;
        _nowServer = DateTime.now().add(_serverOffset);
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await ApiService.clearToken();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractWibTime(String? iso) {
    if (iso == null) return '-';
    final m = RegExp(r'T(\d{2}:\d{2}:\d{2})').firstMatch(iso);
    return m != null ? '${m.group(1)} WIB' : iso;
  }

  String _computeDuration(String? inIso, String? outIso) {
    if (inIso == null || outIso == null) return '-';
    try {
      final tIn = DateTime.parse(inIso);
      final tOut = DateTime.parse(outIso);
      final diff = tOut.difference(tIn);
      final hours = diff.inHours;
      final mins = diff.inMinutes.remainder(60);
      return '$hours jam $mins menit';
    } catch (_) {
      return '-';
    }
  }

  Map<String, dynamic> _computeWorkSummary() {
    int totalDays = 0;
    int completedDays = 0;
    Duration totalDuration = Duration.zero;

    for (final item in _history) {
      final inIso = item['check_in_at']?.toString();
      final outIso = item['check_out_at']?.toString();
      if (inIso != null) {
        totalDays++;
        if (outIso != null) {
          completedDays++;
          try {
            final diff = DateTime.parse(outIso).difference(DateTime.parse(inIso));
            if (!diff.isNegative) {
              totalDuration += diff;
            }
          } catch (_) {}
        }
      }
    }

    return {
      'totalDays': totalDays,
      'completedDays': completedDays,
      'totalHours': totalDuration.inHours,
      'totalMinutes': totalDuration.inMinutes.remainder(60),
    };
  }

  Future<void> _openAttendanceFlow(String action) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CameraAttendanceScreen(action: action),
      ),
    );
    if (result == true) {
      _fetchStatus();
    }
  }

  Future<void> _showPhotoChoiceSheet(Map<String, dynamic> item) async {
    final date = item['attendance_date']?.toString() ?? '-';
    final inFileId = item['check_in_tg_file_id']?.toString();
    final outFileId = item['check_out_tg_file_id']?.toString();

    if ((inFileId == null || inFileId.isEmpty) &&
        (outFileId == null || outFileId.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada bukti foto untuk tanggal ini.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bukti Foto Presensi ($date)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih foto Check-In (In) atau Check-Out (Out)',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              if (inFileId != null && inFileId.isNotEmpty)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openPhotoViewer(
                      fileId: inFileId,
                      title: 'Foto Check-In • $date',
                    );
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Lihat Foto Check-In (In)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (inFileId != null &&
                  inFileId.isNotEmpty &&
                  outFileId != null &&
                  outFileId.isNotEmpty)
                const SizedBox(height: 10),
              if (outFileId != null && outFileId.isNotEmpty)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openPhotoViewer(
                      fileId: outFileId,
                      title: 'Foto Check-Out • $date',
                    );
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Lihat Foto Check-Out (Out)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPhotoViewer({
    required String fileId,
    required String title,
  }) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final token = await ApiService.getToken();
    if (!mounted) return;

    final photoUrl =
        '$baseUrl/api/v1/attendance/photos/${Uri.encodeComponent(fileId)}';

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.65,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: InteractiveViewer(
                  child: Image.network(
                    photoUrl,
                    headers: {
                      if (token != null) 'Authorization': 'Bearer $token',
                    },
                    fit: BoxFit.contain,
                    frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded || frame != null) {
                        return child;
                      }
                      return const SizedBox(
                        height: 260,
                        width: double.infinity,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 12),
                              Text(
                                'Memuat foto...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 200,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Gagal memuat foto presensi.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = widget.user['full_name']?.toString() ?? 'Anggota';
    final empCode = widget.user['employee_code']?.toString() ?? '';

    final dateText = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_nowServer);
    final timeText = DateFormat('HH:mm:ss').format(_nowServer);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              empCode,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: _fetchStatus,
          ),
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'password') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChangePasswordScreen(
                      user: widget.user,
                      isForced: false,
                    ),
                  ),
                );
              } else if (val == 'logout') {
                await ApiService.clearToken();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'password',
                child: Text('Ubah Kata Sandi'),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text('Keluar'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Server Clock Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateText,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        timeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'WIB (Server)',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),

            // Single-Action Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _buildActionCardContent(),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Bukti & Riwayat Kerja (30 Hari Terakhir)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),

            if (!_loading) ...[
              Builder(
                builder: (_) {
                  final summary = _computeWorkSummary();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Hari Masuk',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF047857),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${summary['totalDays']} Hari (${summary['completedDays']} Selesai)',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Akumulasi Jam',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF047857),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${summary['totalHours']} jam ${summary['totalMinutes']} mnt',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            if (_history.isEmpty && !_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Belum ada riwayat presensi.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              ..._history.map((item) {
                final inIso = item['check_in_at']?.toString();
                final outIso = item['check_out_at']?.toString();
                final inAddr = item['check_in_address']?.toString();
                final outAddr = item['check_out_address']?.toString();
                final hasPhoto = (item['check_in_tg_file_id'] != null) ||
                    (item['check_out_tg_file_id'] != null);
                final isCompleted = outIso != null;

                return InkWell(
                  onTap: hasPhoto ? () => _showPhotoChoiceSheet(item) : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['attendance_date']?.toString() ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? const Color(0xFFE0F2FE)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isCompleted
                                    ? 'Selesai • ${_computeDuration(inIso, outIso)}'
                                    : 'Belum Check-Out',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Masuk: ${_extractWibTime(inIso)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                        if (inAddr != null && inAddr.isNotEmpty)
                          Text(
                            inAddr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Pulang: ${_extractWibTime(outIso)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                        if (outAddr != null && outAddr.isNotEmpty)
                          Text(
                            outAddr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (hasPhoto) ...[
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 14,
                                color: Color(0xFF0284C7),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Ketuk untuk lihat foto In / Out',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCardContent() {
    if (_status == 'NOT_CHECKED_IN') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Status Hari Ini: Belum Check-In',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _openAttendanceFlow('check-in'),
            icon: const Icon(Icons.login_rounded),
            label: const Text(
              'Check-In Sekarang',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      );
    }

    if (_status == 'CHECKED_IN') {
      final checkInTime =
          _extractWibTime(_todayLog?['check_in_at']?.toString());
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
              const SizedBox(width: 8),
              Text(
                'Check-In tercatat pukul $checkInTime',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _openAttendanceFlow('check-out'),
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'Check-Out Sekarang',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      );
    }

    // COMPLETED
    final inIso = _todayLog?['check_in_at']?.toString();
    final outIso = _todayLog?['check_out_at']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.task_alt, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Text(
              'Presensi Hari Ini Selesai',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Jam Masuk: ${_extractWibTime(inIso)}'),
        Text('Jam Keluar: ${_extractWibTime(outIso)}'),
        const SizedBox(height: 6),
        Text(
          'Durasi Kerja: ${_computeDuration(inIso, outIso)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0284C7),
          ),
        ),
      ],
    );
  }
}
