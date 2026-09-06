import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../api.dart';
import '../main.dart';
import 'checkout_detail_screen.dart';
import 'lostqr_screen.dart';

/// Tab Scan Keluar: scan QR pengendara → tampil rincian + bayar.
/// [active] mengikuti tab bawah: kamera hanya jalan saat tab ini tampil
/// (IndexedStack membuat tab lain offstage sehingga kamera harus di-stop).
class CheckoutScanScreen extends StatefulWidget {
  final bool active;
  const CheckoutScanScreen({super.key, this.active = true});

  @override
  State<CheckoutScanScreen> createState() => _CheckoutScanScreenState();
}

class _CheckoutScanScreenState extends State<CheckoutScanScreen>
    with AutomaticKeepAliveClientMixin {
  late final MobileScannerController _controller;
  bool _busy = false;
  String? _camError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(autoStart: false);
    if (widget.active) _controller.start();
  }

  @override
  void didUpdateWidget(CheckoutScanScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      setState(() => _camError = null);
      _controller.start();
    } else if (!widget.active && old.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openPreview(String code) async {
    if (_busy) return;
    final session = SessionScope.of(context);
    setState(() => _busy = true);
    await _controller.stop();
    try {
      final data = await session.api.checkoutPreview(code);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutDetailScreen(preview: data, manual: false),
        ),
      );
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await session.logout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak bisa menghubungi server.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      if (widget.active) await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: GFAppBar(title: const Text('Scan Keluar'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  errorBuilder: (ctx, err) {
                    final msg = err.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'Izin kamera ditolak. Aktifkan di Pengaturan HP → Parkir Getter → Kamera.'
                        : 'Kamera tidak bisa dibuka (${err.errorCode}).';
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.no_photography, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(msg, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            GFButton(
                              onPressed: () {
                                setState(() => _camError = null);
                                _controller.start();
                              },
                              text: 'Coba Lagi',
                              icon: const Icon(Icons.refresh, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onDetect: (cap) {
                    if (_camError != null) setState(() => _camError = null);
                    final raw = cap.barcodes.firstOrNull?.rawValue?.trim();
                    if (raw != null && raw.isNotEmpty) _openPreview(raw);
                  },
                ),
                if (_busy) const Center(child: CircularProgressIndicator(color: Colors.white)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Arahkan kamera ke QR pengendara',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LostQrScreen()),
                    ),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('QR pengendara hilang? Cari manual'),
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
