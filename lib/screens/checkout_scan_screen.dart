import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../api.dart';
import '../main.dart';
import '../utils.dart';
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
  /// Auto-retry: kegagalan transient (kamera belum lepas dari tab lain)
  /// dicoba ulang otomatis 2x jeda 1,2 dtk sebelum menyerah ke tombol manual.
  int _errRetry = 0;
  bool _retryScheduled = false;

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
      _errRetry = 0;
      _retryScheduled = false;
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
      if (e.parkingDisabled) {
        try {
          await session.refresh();
        } catch (_) {}
        return;
      }
      if (e.unauthorized) {
        await session.logout();
        return;
      }
      // QR sudah pernah di-checkout: tampilkan JAM checkout-nya.
      if (e.alreadyCheckedOut && e.outTransaction != null) {
        if (mounted) await showAlreadyCheckedOutDialog(context, e.outTransaction!);
        return; // finally menyalakan ulang scanner
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
                    // Coba pulihkan otomatis dulu (kasus transient), jangan
                    // langsung menyerah ke pesan "dipakai aplikasi lain".
                    if (_errRetry < 2 && !_retryScheduled) {
                      _retryScheduled = true;
                      _errRetry++;
                      Future.delayed(const Duration(milliseconds: 1200), () {
                        _retryScheduled = false;
                        if (!mounted || !widget.active) return;
                        setState(() => _camError = null);
                        _controller.start();
                      });
                    }
                    final denied = err.errorCode == MobileScannerErrorCode.permissionDenied;
                    final recovering = !denied && _errRetry < 2;
                    final msg = denied
                        ? 'Izin kamera ditolak. Aktifkan di Pengaturan HP → Parkir Getter → Kamera.'
                        : recovering
                            ? 'Kamera sedang disiapkan…'
                            : 'Kamera tidak bisa dibuka. Pastikan tidak dipakai aplikasi lain.';
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
                                child: CircularProgressIndicator(),
                              )
                            else
                              const Icon(Icons.no_photography, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(msg, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            GFButton(
                              onPressed: () {
                                _errRetry = 0;
                                _retryScheduled = false;
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
