import 'package:flutter/material.dart';
import '../main.dart';

/// Pemberitahuan parkiran dinonaktifkan.
/// Getter tetap login, tapi SEMUA aktivitas diblokir server (403).
/// Satu-satunya jalan: periksa lagi (kalau sudah diaktifkan) atau keluar.
class SuspendedScreen extends StatefulWidget {
  const SuspendedScreen({super.key});

  @override
  State<SuspendedScreen> createState() => _SuspendedScreenState();
}

class _SuspendedScreenState extends State<SuspendedScreen> {
  bool _checking = false;

  Future<void> _recheck() async {
    final session = SessionScope.of(context);
    setState(() => _checking = true);
    try {
      await session.refresh();
      // Kalau parkiran sudah diaktifkan, main gate otomatis pindah ke Home.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa menghubungi server. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pemberitahuan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Akun Dinonaktifkan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Akun Anda dinonaktifkan. Silakan hubungi penyedia jasa untuk dapat menggunakan layanan ini.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _checking ? null : _recheck,
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_checking ? 'MEMERIKSA…' : 'PERIKSA LAGI'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await session.logout(
                      notice: 'Anda keluar. Scan QR aktivasi untuk masuk lagi.',
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('KELUAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
