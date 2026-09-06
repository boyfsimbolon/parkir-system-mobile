import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:nice_image_compress/nice_image_compress.dart';
import '../api.dart';
import '../config.dart';
import '../main.dart';
import '../utils.dart';
import 'ticket_screen.dart';

/// Tab Check-In: kamera langsung tampil.
/// Alur: jepret → bottom sheet ACC (foto + jenis kendaraan) → kompres ≤500KB
/// → generate barcode → upload → simpan → tampil QR fullscreen.
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with AutomaticKeepAliveClientMixin {
  CameraController? _cam;
  String? _camError;
  bool _taking = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _camError = 'Tidak ada kamera di HP ini.');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(back, ResolutionPreset.high,
          enableAudio: false);
      await ctrl.initialize();
      if (!mounted) return;
      setState(() => _cam = ctrl);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _camError = 'Kamera tidak bisa dibuka (${e.code}). Beri izin kamera lalu buka ulang tab ini.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _camError = 'Kamera tidak bisa dibuka.');
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _taking) return;
    final session = SessionScope.of(context);
    setState(() => _taking = true);
    try {
      final shot = await cam.takePicture();
      if (!mounted) return;
      await _showAccSheet(File(shot.path));
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await session.logout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  /// Bottom sheet ACC: pratinjau foto + pilih jenis + tombol simpan.
  Future<void> _showAccSheet(File photo) async {
    String vehicle = 'MOTOR';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => _AccSheet(
            photo: photo,
            vehicle: vehicle,
            onVehicle: (v) => setSheet(() => vehicle = v),
            onConfirm: () async {
              Navigator.of(ctx).pop();
              await _submit(photo, vehicle);
            },
          ),
        );
      },
    );
  }

  Future<void> _submit(File photo, String vehicle) async {
    final session = SessionScope.of(context);
    _progress('Mengompres foto…');
    // 1. Kompres max 500KB
    final compressed = await ImageCompressorService.compressToTarget(
      photo,
      options: ImageCompressorOptions(
        targetSizeInKB: AppConfig.maxPhotoKb,
        maxWidth: 1600,
        maxHeight: 1200,
        format: CompressFormat.jpeg,
        minQuality: 40,
      ),
    );
    // 2. Generate barcode di Flutter
    final barcode = genBarcode(AppConfig.qrPrefix, session.parkingId);
    // 3. Upload foto
    _progress('Mengupload foto…');
    final photoUrl =
        await session.api.uploadCheckinPhoto(compressed.file, barcode);
    // 4. Simpan transaksi
    _progress('Menyimpan check-in…');
    await session.api.checkin(
      barcode: barcode,
      vehicleType: vehicle,
      photoUrl: photoUrl,
    );
    if (!mounted) return;
    Navigator.of(context).pop(); // tutup progress
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TicketScreen(barcode: barcode, vehicle: vehicle)),
    );
    try {
      await photo.delete();
    } catch (_) {}
  }

  void _progress(String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cam = _cam;
    return Scaffold(
      appBar: GFAppBar(
        title: const Text('Check In Kendaraan'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _camError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.no_photography, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(_camError!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          GFButton(
                            onPressed: () {
                              setState(() {
                                _camError = null;
                                _cam = null;
                              });
                              _initCamera();
                            },
                            text: 'Coba Lagi',
                            icon: const Icon(Icons.refresh, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  )
                : cam == null || !cam.value.isInitialized
                    ? const Center(child: CircularProgressIndicator())
                    : ClipRect(child: CameraPreview(cam)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _taking ? null : _capture,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _taking ? Colors.grey : const Color(0xFF2563EB),
                    ),
                    child: _taking
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Icon(Icons.photo_camera, color: Colors.white, size: 30),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text('Foto kendaraan + pengendara, lalu tekan tombol biru',
                style: TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}

/// Isi bottom sheet ACC check-in.
class _AccSheet extends StatelessWidget {
  final File photo;
  final String vehicle;
  final ValueChanged<String> onVehicle;
  final Future<void> Function() onConfirm;

  const _AccSheet({
    required this.photo,
    required this.vehicle,
    required this.onVehicle,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    String? hint;
    for (final t in session.tariffs) {
      if (t is Map && t['vehicle_type'] == vehicle) {
        hint = t['mode'] == 'FLAT'
            ? 'Flat ${rupiah((t['flat_price'] as num?) ?? 0)}'
            : '${rupiah((t['price_per_hour'] as num?) ?? 0)}/jam';
      }
    }
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            GFTypography(text: 'ACC Check-In', type: GFTypographyType.typo5, showDivider: false),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(photo, height: 220, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            Row(
              children: ['MOTOR', 'MOBIL'].map((v) {
                final active = vehicle == v;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GFButton(
                      onPressed: () => onVehicle(v),
                      text: v,
                      icon: Icon(v == 'MOTOR' ? Icons.two_wheeler : Icons.directions_car, color: Colors.white),
                      color: active ? const Color(0xFF2563EB) : Colors.grey,
                      fullWidthButton: true,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text('Tarif: $hint', style: const TextStyle(color: Colors.black54)),
            ],
            const SizedBox(height: 12),
            GFButton(
              onPressed: onConfirm,
              text: 'SIMPAN CHECK-IN',
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
}
