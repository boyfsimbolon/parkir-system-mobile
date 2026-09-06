import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../main.dart';
import '../utils.dart';

/// Info parkir + tarif + akun. Logout ada di sini.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final parking = session.parking;
    final getter = session.getter;

    return Scaffold(
      appBar: GFAppBar(title: const Text('Info'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GFCard(
            content: Row(
              children: [
                Image.asset('assets/logo.png', width: 56, height: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GFTypography(
                        text: (parking?['nama_parkir'] ?? 'Parkir') as String,
                        type: GFTypographyType.typo5,
                        showDivider: false,
                      ),
                      Text((parking?['alamat'] ?? '') as String,
                          style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text('Petugas: ${(getter?['full_name'] ?? '-') as String}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const GFTypography(text: 'Tarif Aktif', type: GFTypographyType.typo6, showDivider: false),
          const SizedBox(height: 8),
          ...session.tariffs.map((t) {
            final m = t as Map<String, dynamic>;
            final isFlat = m['mode'] == 'FLAT';
            final price = isFlat ? (m['flat_price'] as num?) ?? 0 : (m['price_per_hour'] as num?) ?? 0;
            return GFCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 8),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GFBadge(text: m['vehicle_type'] as String, color: const Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(isFlat ? 'Flat' : 'Per jam'),
                    ],
                  ),
                  Text(rupiah(price), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          GFButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Logout?'),
                  content: const Text('Perlu scan QR aktivasi lagi untuk masuk.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
                  ],
                ),
              );
              if (ok == true) await session.logout();
            },
            text: 'LOGOUT',
            icon: const Icon(Icons.logout, color: Colors.white),
            color: Colors.red,
            fullWidthButton: true,
          ),
        ],
      ),
    );
  }
}
