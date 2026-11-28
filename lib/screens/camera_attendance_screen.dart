import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';

class CameraAttendanceScreen extends StatefulWidget {
  final String action; // 'check-in' or 'check-out'

  const CameraAttendanceScreen({super.key, required this.action});

  @override
  State<CameraAttendanceScreen> createState() => _CameraAttendanceScreenState();
}

class _CameraAttendanceScreenState extends State<CameraAttendanceScreen> {
  CameraController? _cameraController;
  bool _initializing = true;
  bool _capturing = false;
  bool _submitting = false;
  String? _blockingError;

  Position? _position;
  String _address = 'Mengambil alamat...';
  File? _capturedFile;

  @override
  void initState() {
    super.initState();
    _prepareLocationAndCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _prepareLocationAndCamera() async {
    setState(() {
      _initializing = true;
      _blockingError = null;
    });

    try {
      // 1. Validasi layanan lokasi & izin GPS
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _blockingError =
              'Layanan GPS nonaktif. Aktifkan lokasi terlebih dahulu.';
          _initializing = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _blockingError =
              'Izin lokasi ditolak. Aplikasi wajib mengakses GPS untuk presensi.';
          _initializing = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 2. Anti-Fake GPS check (position.isMocked)
      if (pos.isMocked) {
        setState(() {
          _blockingError =
              'Terdeteksi penggunaan Lokasi Palsu (Fake GPS). Proses presensi diblokir.';
          _initializing = false;
        });
        return;
      }

      _position = pos;

      // 3. Reverse geocoding di perangkat mobile
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            p.street,
            p.subLocality,
            p.locality ?? p.subAdministrativeArea,
          ].where((s) => s != null && s.trim().isNotEmpty).toList();
          _address = parts.isNotEmpty
              ? parts.join(', ')
              : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        }
      } catch (_) {
        _address =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      }

      // 4. Inisialisasi kamera depan in-app
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _blockingError = 'Kamera tidak ditemukan pada perangkat.';
          _initializing = false;
        });
        return;
      }

      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCam,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _initializing = false;
      });
    } catch (e) {
      setState(() {
        _blockingError = 'Gagal mengakses kamera/lokasi: $e';
        _initializing = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() => _capturing = true);

    try {
      final rawFile = await controller.takePicture();
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/presensi_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Kompresi ke max 1080x1440, kualitas JPEG 80%
      final compressed = await FlutterImageCompress.compressAndGetFile(
        rawFile.path,
        targetPath,
        minWidth: 1080,
        minHeight: 1440,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      if (compressed == null) {
        throw Exception('Gagal mengompres foto.');
      }

      final file = File(compressed.path);
      final bytes = await file.length();
      // Tolak di frontend jika masih > 1.5 MB (mitigasi limit 4.5 MB Vercel)
      if (bytes > 1536 * 1024) {
        throw Exception(
          'Ukuran foto (${(bytes / 1024).round()} KB) melebihi batas 1.5 MB.',
        );
      }

      if (!mounted) return;
      setState(() => _capturedFile = file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _uploadPhoto() async {
    final file = _capturedFile;
    final pos = _position;
    if (file == null || pos == null) return;

    setState(() => _submitting = true);

    try {
      await ApiService.submitAttendance(
        action: widget.action,
        photoFile: file,
        lat: pos.latitude,
        lng: pos.longitude,
        address: _address,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.action == 'check-in'
                ? 'Check-In berhasil dicatat!'
                : 'Check-Out berhasil dicatat!',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.action == 'check-in'
        ? 'Ambil Foto Check-In'
        : 'Ambil Foto Check-Out';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: _initializing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Memverifikasi GPS & kamera depan...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : _blockingError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _blockingError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _prepareLocationAndCamera,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _capturedFile != null
                                ? Image.file(
                                    _capturedFile!,
                                    fit: BoxFit.cover,
                                  )
                                : Builder(
                                    builder: (_) {
                                      final previewSize =
                                          _cameraController!.value.previewSize;
                                      if (previewSize == null) {
                                        return CameraPreview(_cameraController!);
                                      }
                                      return FittedBox(
                                        fit: BoxFit.cover,
                                        clipBehavior: Clip.hardEdge,
                                        child: SizedBox(
                                          width: previewSize.height,
                                          height: previewSize.width,
                                          child: CameraPreview(
                                              _cameraController!),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFF0F172A),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _address,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          if (_capturedFile == null)
                            FilledButton.icon(
                              onPressed: _capturing ? null : _capturePhoto,
                              icon: _capturing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt_rounded),
                              label: Text(
                                _capturing ? 'Memproses foto...' : 'Ambil Foto',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _submitting
                                        ? null
                                        : () => setState(
                                            () => _capturedFile = null),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Ambil Ulang'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: Colors.white54),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed:
                                        _submitting ? null : _uploadPhoto,
                                    icon: _submitting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.cloud_upload_rounded),
                                    label: Text(
                                      _submitting
                                          ? 'Mengunggah...'
                                          : 'Upload Presensi',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          widget.action == 'check-in'
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFF97316),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
