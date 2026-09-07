import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:getwidget/getwidget.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../api.dart';
import '../device.dart';
import '../main.dart';

/// Layar pertama: scan QR aktivasi dari admin (sekali saja, lalu permanen).
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _controller = MobileScannerController();
  bool _busy = false;
  String? _error;
  String? _notice;
  /// Auto-retry scanner (transient) + pesan kamera bila gagal permanen.
  int _scanRetry = 0;
  bool _retryScheduled = false;

  @override
  void initState() {
    super.initState();
    // Tampilkan alasan logout (mis. sesi tidak valid) sekali saja.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = SessionScope.of(context).takeNotice();
      if (n != null && mounted) setState(() => _notice = n);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    final session = SessionScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    await _controller.stop();
    try {
      // Identitas HP agar tercatat di scanner_devices (tidak wajib untuk login).
      String? uuid;
      String? name;
      try {
        uuid = await DeviceId.installId(const FlutterSecureStorage());
        name = await DeviceId.deviceName();
      } catch (_) {}
      final res = await session.api.activate(raw, deviceUuid: uuid, deviceName: name);
      await session.saveActivation(res);
      // AnimatedBuilder di main otomatis pindah ke HomeScreen.
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      await _controller.start();
      setState(() => _busy = false);
    } catch (_) {
      setState(() => _error = 'Tidak bisa menghubungi server. Cek koneksi & API_BASE_URL.');
      await _controller.start();
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(
        title: const Text('Aktivasi Getter'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (ctx, err) {
                    if (_scanRetry < 2 &&
                        !_retryScheduled &&
                        err.errorCode != MobileScannerErrorCode.permissionDenied) {
                      _retryScheduled = true;
                      _scanRetry++;
                      Future.delayed(const Duration(milliseconds: 1200), () {
                        _retryScheduled = false;
                        if (!mounted) return;
                        _controller.start();
                      });
                    }
                    final denied =
                        err.errorCode == MobileScannerErrorCode.permissionDenied;
                    final recovering = !denied && _scanRetry < 2;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (recovering)
                              const SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(color: Colors.white),
                              )
                            else
                              const Icon(Icons.no_photography,
                                  size: 48, color: Colors.white70),
                            const SizedBox(height: 12),
                            Text(
                              denied
                                  ? 'Izin kamera ditolak. Aktifkan di Pengaturan HP → Parkir Getter → Kamera, lalu tekan Coba Lagi.'
                                  : recovering
                                      ? 'Menyalakan kamera…'
                                      : 'Kamera tidak bisa dibuka. Pastikan tidak dipakai aplikasi lain.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            if (!recovering) ...[
                              const SizedBox(height: 12),
                              GFButton(
                                onPressed: () {
                                  _scanRetry = 0;
                                  _retryScheduled = false;
                                  _controller.start();
                                },
                                text: 'Coba Lagi',
                                icon: const Icon(Icons.refresh, color: Colors.white),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_busy)
                  const Center(child: CircularProgressIndicator(color: Colors.white)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo.png', width: 72, height: 72),
                  const SizedBox(height: 12),
                  const Text(
                    'Arahkan kamera ke QR Aktivasi dari admin',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Login hanya sekali. Setelah ini akun tersimpan permanen di HP ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  if (_notice != null) ...[
                    const SizedBox(height: 10),
                    Text(_notice!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
