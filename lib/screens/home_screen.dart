import 'package:flutter/material.dart';
import 'checkin_screen.dart';
import 'checkout_scan_screen.dart';
import 'info_screen.dart';

/// Navigasi utama: hanya Scan Masuk, Scan Keluar, Info.
/// (Menu "QR Hilang" diakses dari link di layar Scan Keluar.)
///
/// Hanya SATU kamera yang boleh hidup dalam satu waktu (Android menolak
/// dua klien kamera bersamaan). Karena itu pindah tab diserialkan:
/// matikan semua kamera → jeda 450ms agar driver melepas kamera →
/// nyalakan kamera tab tujuan. Tanpa jeda ini, pindah langsung
/// Scan Masuk ↔ Scan Keluar membuat kamera baru gagal start (layar hitam).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int _activeCam = 0; // tab yang boleh menyalakan kamera (-1 = tidak ada)
  bool _switching = false;
  int? _pending;

  Future<void> _go(int i) async {
    if (i == _index && _activeCam == i) return;
    if (_switching) {
      _pending = i; // antrekan tap kilat, jalankan setelah giliran ini
      return;
    }
    _switching = true;
    setState(() {
      _index = i;
      _activeCam = -1; // matikan semua kamera dulu
    });
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _activeCam = i);
    _switching = false;
    if (_pending != null) {
      final next = _pending!;
      _pending = null;
      _go(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          CheckinScreen(active: _activeCam == 0),
          CheckoutScanScreen(active: _activeCam == 1),
          const InfoScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2563EB),
        onTap: _go,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.photo_camera), label: 'Scan Masuk'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scan Keluar'),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: 'Info'),
        ],
      ),
    );
  }
}
