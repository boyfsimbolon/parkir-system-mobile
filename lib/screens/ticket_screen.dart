import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR tiket fullscreen setelah check-in berhasil.
/// Pengendara screenshot/foto QR ini untuk proses keluar.
class TicketScreen extends StatelessWidget {
  final String barcode;
  final String plat;
  final String vehicle;
  const TicketScreen({super.key, required this.barcode, required this.plat, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(title: const Text('Tiket Parkir'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GFCard(
              padding: const EdgeInsets.all(20),
              content: Column(
                children: [
                  GFBadge(text: vehicle, color: const Color(0xFF2563EB)),
                  const SizedBox(height: 8),
                  Text(plat,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  QrImageView(data: barcode, size: 260),
                  const SizedBox(height: 12),
                  SelectableText(barcode,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const GFAlert(
              type: GFAlertType.rounded,
              backgroundColor: Color(0xFFFFF7E6),
              title: 'Penting',
              subtitle: 'Silakan screenshot atau foto QR ini untuk proses keluar parkir.',
            ),
            const SizedBox(height: 12),
            GFButton(
              onPressed: () => Navigator.of(context).pop(),
              text: 'SELESAI — SCAN LAGI',
              icon: const Icon(Icons.photo_camera, color: Colors.white),
              fullWidthButton: true,
              size: GFSize.LARGE,
            ),
          ],
        ),
      ),
    );
  }
}
