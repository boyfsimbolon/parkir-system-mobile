import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../api.dart';
import '../main.dart';
import '../utils.dart';

/// Rincian checkout: foto check-in + durasi + biaya + bayar.
/// Dipakai untuk scan normal (manual=false) dan QR hilang (manual=true).
class CheckoutDetailScreen extends StatefulWidget {
  final Map<String, dynamic> preview;
  final bool manual;
  const CheckoutDetailScreen({super.key, required this.preview, required this.manual});

  @override
  State<CheckoutDetailScreen> createState() => _CheckoutDetailScreenState();
}

class _CheckoutDetailScreenState extends State<CheckoutDetailScreen> {
  String _method = 'CASH';
  bool _paying = false;

  @override
  Widget build(BuildContext context) {
    final trx = widget.preview['transaction'] as Map<String, dynamic>;
    final fee = widget.preview['fee'] as Map<String, dynamic>;
    final qrisUrl = widget.preview['qris_image_url'] as String?;
    final amount = (fee['amount'] as num?) ?? 0;

    return Scaffold(
      appBar: GFAppBar(
        title: Text(widget.manual ? 'Checkout Manual (QR Hilang)' : 'Konfirmasi Keluar'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.manual)
              const GFAlert(
                type: GFAlertType.rounded,
                backgroundColor: Color(0xFFFFEDED),
                title: 'Verifikasi wajib',
                subtitle: 'Pastikan kendaraan & pengendara SAMA dengan foto di bawah. Jika tidak cocok, JANGAN checkout.',
              ),
            const SizedBox(height: 8),
            GFCard(
              padding: EdgeInsets.zero,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      trx['photo_url'] as String,
                      height: 240,
                      fit: BoxFit.cover,
                      errorBuilder: (_, err, stack) => const SizedBox(
                        height: 120, child: Center(child: Text('Foto tidak termuat'))),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GFBadge(text: trx['vehicle_type'] as String, color: const Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            GFBadge(text: fee['mode'] as String, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Masuk: ${formatDateTime(DateTime.parse(trx['check_in_time'] as String))}'),
                        Text('Durasi: ${formatDuration((fee['minutes'] as num?)?.toInt() ?? 0)} '
                            '(${(fee['hours'] as num?) ?? 0} jam)'),
                        const SizedBox(height: 4),
                        Text('Biaya: ${rupiah(amount)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const GFTypography(text: 'Metode pembayaran', type: GFTypographyType.typo6, showDivider: false),
            const SizedBox(height: 8),
            Row(
              children: ['CASH', 'QRIS'].map((m) {
                final active = _method == m;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GFButton(
                      onPressed: () => setState(() => _method = m),
                      text: m,
                      icon: Icon(m == 'CASH' ? Icons.payments : Icons.qr_code_2, color: Colors.white),
                      color: active ? const Color(0xFF2563EB) : Colors.grey,
                      fullWidthButton: true,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_method == 'QRIS') ...[
              const SizedBox(height: 8),
              if (qrisUrl != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(qrisUrl, height: 220, fit: BoxFit.contain,
                        errorBuilder: (_, err, stack) =>
                            const Text('QRIS toko belum dipasang admin')),
                  ),
                )
              else
                const Text('QRIS toko belum dipasang admin.', textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            GFButton(
              onPressed: _paying ? null : () => _pay(amount),
              text: _paying ? 'MEMPROSES…' : 'BAYAR ${rupiah(amount)} & CHECKOUT',
              icon: const Icon(Icons.check_circle, color: Colors.white),
              color: Colors.green,
              fullWidthButton: true,
              size: GFSize.LARGE,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay(num amount) async {
    setState(() => _paying = true);
    final session = SessionScope.of(context);
    try {
      final api = session.api;
      final trx = widget.preview['transaction'] as Map<String, dynamic>;
      if (widget.manual) {
        await api.lostQrCheckout((trx['id'] as num).toInt(), _method);
      } else {
        await api.checkout(trx['barcode_data'] as String, _method);
      }
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Checkout Berhasil'),
          content: Text('Diterima ${rupiah(amount)} via $_method.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
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
      if (mounted) setState(() => _paying = false);
    }
  }
}
