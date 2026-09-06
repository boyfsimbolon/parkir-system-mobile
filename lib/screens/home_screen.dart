import 'package:flutter/material.dart';
import 'checkin_screen.dart';
import 'checkout_scan_screen.dart';
import 'lostqr_screen.dart';
import 'info_screen.dart';

/// Navigasi utama: Check-In langsung jadi tab pertama.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _tabs = [
    CheckinScreen(),
    CheckoutScanScreen(),
    LostQrScreen(),
    InfoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2563EB),
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.photo_camera), label: 'Check In'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scan Keluar'),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: 'QR Hilang'),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: 'Info'),
        ],
      ),
    );
  }
}
