import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

String rupiah(num n) => _rupiah.format(n);

String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes mnt';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h jam' : '$h jam $m mnt';
}

String formatDateTime(DateTime dt) {
  // Server kirim ISO UTC; tampilkan waktu lokal HP.
  final local = dt.toLocal();
  return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(local);
}

/// Generate barcode tiket: [PRK]-[timestamp]-[parkingId]-[random6]
String genBarcode(String prefix, int parkingId) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd = Random.secure();
  final suffix = List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$parkingId-$suffix';
}

/// Dialog "Sudah Checkout": tampilkan JAM keluar (dan masuk) saat QR yang
/// di-scan / dibayar ternyata sudah pernah di-checkout getter sebelumnya.
/// [t] adalah `transaction` dari body 409 ALREADY_CHECKED_OUT.
Future<void> showAlreadyCheckedOutDialog(BuildContext context, Map<String, dynamic> t) {
  final plat = (t['plat_nomor'] as String?)?.trim();
  DateTime? inTime;
  DateTime? outTime;
  try {
    inTime = DateTime.parse(t['check_in_time'] as String);
  } catch (_) {}
  try {
    final raw = t['check_out_time'] as String?;
    if (raw != null) outTime = DateTime.parse(raw);
  } catch (_) {}
  final method = (t['payment_method'] as String?) ?? '-';
  final amount = (t['amount'] as num?) ?? 0;
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Sudah Checkout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plat != null && plat.isNotEmpty)
            Text('Plat: $plat',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Masuk: ${inTime == null ? '-' : formatDateTime(inTime)}'),
          Text(
            'Keluar: ${outTime == null ? 'waktu tidak tercatat' : formatDateTime(outTime)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Via $method • ${rupiah(amount)}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
