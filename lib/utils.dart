import 'dart:math';
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
