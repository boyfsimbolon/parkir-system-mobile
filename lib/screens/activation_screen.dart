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
                MobileScanner(controller: _controller, onDetect: _onDetect),
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
