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
/// [active] mengikuti tab bawah: controller kamera hanya hidup saat tab ini
/// tampil, karena texture kamera mati (layar hitam) kalau tab offstage.
class CheckinScreen extends StatefulWidget {
  final bool active;
  const CheckinScreen({super.key, this.active = true});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  CameraController? _cam;
  String? _camError;
  bool _taking = false;
  bool _starting = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _startCamera();
  }

  @override
  void didUpdateWidget(CheckinScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _startCamera();
    } else if (!widget.active && old.active) {
      _stopCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && widget.active) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    if (_starting || _cam != null) return;
    _starting = true;
    setState(() => _camError = null);
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (!mounted) return;
        setState(() => _camError = 'Tidak ada kamera di HP ini.');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(back, ResolutionPreset.medium,
          enableAudio: false);
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() => _cam = ctrl);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _camError = 'Kamera tidak bisa dibuka (${e.code}). Beri izin kamera lalu buka ulang tab ini.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _camError = 'Kamera tidak bisa dibuka.');
    } finally {
      _starting = false;
    }
  }

  Future<void> _stopCamera() async {
    final cam = _cam;
    _cam = null;
    try {
      await cam?.dispose();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      if (e.parkingDisabled) {
        try {
          await session.refresh();
        } catch (_) {}
        return;
      }
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

  /// Bottom sheet ACC: pratinjau foto + plat + pilih jenis + tombol simpan.
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
            onConfirm: (plat) async {
              Navigator.of(ctx).pop();
              await _submit(photo, vehicle, plat);
            },
          ),
        );
      },
    );
  }

  Future<void> _submit(File photo, String vehicle, String plat) async {
    final session = SessionScope.of(context);
    // Satu dialog progres untuk semua tahap (kompres → upload → simpan).
    final step = ValueNotifier('Mengompres foto…');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: step,
                builder: (_, text, child) => Text(text),
              ),
            ),
          ],
        ),
      ),
    );
    try {
      // 1. Kompres max 500KB (resolusi dibatasi agar cepat di HP kentang)
      final compressed = await ImageCompressorService.compressToTarget(
        photo,
        options: ImageCompressorOptions(
          targetSizeInKB: AppConfig.maxPhotoKb,
          maxWidth: AppConfig.maxPhotoWidth,
          maxHeight: AppConfig.maxPhotoHeight,
          format: CompressFormat.jpeg,
          minQuality: 40,
          maxTotalTrials: 12,
        ),
      );
      // 2. Generate barcode di Flutter
      final barcode = genBarcode(AppConfig.qrPrefix, session.parkingId);
      // 3. Upload foto
      step.value = 'Mengupload foto…';
      final photoUrl =
          await session.api.uploadCheckinPhoto(compressed.file, barcode);
      // 4. Simpan transaksi
      step.value = 'Menyimpan check-in…';
      await session.api.checkin(
        barcode: barcode,
        platNomor: plat,
        vehicleType: vehicle,
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // tutup progres
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TicketScreen(barcode: barcode, plat: plat, vehicle: vehicle)),
      );
      try {
        await photo.delete();
      } catch (_) {}
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // tutup progres
      if (e.parkingDisabled) {
        try {
          await session.refresh();
        } catch (_) {}
        return;
      }
      if (e.unauthorized) {
        await session.logout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // tutup progres
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal check-in: $e')));
    } finally {
      step.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cam = _cam;
    return Scaffold(
      appBar: GFAppBar(
        title: const Text('Scan Masuk'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: !widget.active
                ? const ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                : _camError != null
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
                              _startCamera();
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

/// Isi bottom sheet ACC check-in (dengan input plat nomor wajib).
class _AccSheet extends StatefulWidget {
  final File photo;
  final String vehicle;
  final ValueChanged<String> onVehicle;
  final Future<void> Function(String plat) onConfirm;

  const _AccSheet({
    required this.photo,
    required this.vehicle,
    required this.onVehicle,
    required this.onConfirm,
  });

  @override
  State<_AccSheet> createState() => _AccSheetState();
}

class _AccSheetState extends State<_AccSheet> {
  final _platCtrl = TextEditingController();
  String? _platError;

  @override
  void dispose() {
    _platCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    String? hint;
    for (final t in session.tariffs) {
      if (t is Map && t['vehicle_type'] == widget.vehicle) {
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
            GFTypography(text: 'ACC Scan Masuk', type: GFTypographyType.typo5, showDivider: false),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(widget.photo, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _platCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Plat nomor (wajib)',
                hintText: 'cth: B1234ABC',
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _platError,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: ['MOTOR', 'MOBIL'].map((v) {
                final active = widget.vehicle == v;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GFButton(
                      onPressed: () => widget.onVehicle(v),
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
              onPressed: () {
                final plat = _platCtrl.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                if (plat.isEmpty) {
                  setState(() => _platError = 'Plat nomor wajib diisi');
                  return;
                }
                widget.onConfirm(plat);
              },
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
