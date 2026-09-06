import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../api.dart';
import '../main.dart';
import 'checkout_detail_screen.dart';

/// Tab Scan Keluar: scan QR pengendara → tampil rincian + bayar.
class CheckoutScanScreen extends StatefulWidget {
  const CheckoutScanScreen({super.key});

  @override
  State<CheckoutScanScreen> createState() => _CheckoutScanScreenState();
}

class _CheckoutScanScreenState extends State<CheckoutScanScreen>
    with AutomaticKeepAliveClientMixin {
  final _controller = MobileScannerController();
  final _manual = TextEditingController();
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
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
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: GFAppBar(title: const Text('Scan Check Out'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (cap) {
                    final raw = cap.barcodes.firstOrNull?.rawValue?.trim();
                    if (raw != null && raw.isNotEmpty) _openPreview(raw);
                  },
                ),
                if (_busy) const Center(child: CircularProgressIndicator(color: Colors.white)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Arahkan ke QR pengendara, atau ketik barcode manual:'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manual,
                          decoration: const InputDecoration(
                            hintText: 'PRK-...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GFButton(onPressed: () {
                        final c = _manual.text.trim();
                        if (c.isNotEmpty) _openPreview(c);
                      }, text: 'Cari'),
                    ],
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
