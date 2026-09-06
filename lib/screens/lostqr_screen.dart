import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../api.dart';
import '../main.dart';
import '../utils.dart';
import 'checkout_detail_screen.dart';

/// QR Hilang: pilih manual dari list PARKED → cocokkan visual → checkout.
class LostQrScreen extends StatefulWidget {
  const LostQrScreen({super.key});

  @override
  State<LostQrScreen> createState() => _LostQrScreenState();
}

class _LostQrScreenState extends State<LostQrScreen>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = SessionScope.of(context);
    try {
      final data = await session.api.parked(limit: 100);
      if (!mounted) return;
      setState(() => _items = (data['parked'] as List?) ?? []);
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await session.logout();
        return;
      }
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Tidak bisa menghubungi server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(Map<String, dynamic> item) async {
    final session = SessionScope.of(context);
    try {
      final data = await session.api
          .checkoutPreview(item['barcode_data'] as String);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutDetailScreen(preview: data, manual: true),
        ),
      );
      _load();
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await session.logout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: GFAppBar(title: const Text('QR Hilang — Cari Manual'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Cari plat nomor…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(
                  () => _query = v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '')),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              const SizedBox(height: 8),
                              GFButton(onPressed: _load, text: 'Coba Lagi'),
                            ],
                          ),
                        )
                      : Builder(
                          builder: (_) {
                            final shown = _items.where((e) {
                              final m = e as Map<String, dynamic>;
                              if (_query.isEmpty) return true;
                              final plat = ((m['plat_nomor'] as String?) ?? '').toUpperCase();
                              final code = ((m['barcode_data'] as String?) ?? '').toUpperCase();
                              return plat.contains(_query) || code.contains(_query);
                            }).toList();
                            if (shown.isEmpty) {
                              return const Center(child: Text('Tidak ada kendaraan parkir.'));
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: shown.length,
                              itemBuilder: (_, i) {
                                final it = shown[i] as Map<String, dynamic>;
                                return GFCard(
                                  padding: EdgeInsets.zero,
                                  content: GFListTile(
                                    avatar: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        it['photo_url'] as String,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, err, stack) => const Icon(Icons.image_not_supported),
                                      ),
                                    ),
                                    titleText: (it['plat_nomor'] as String?) ?? (it['vehicle_type'] as String),
                                    subTitleText:
                                        '${it['vehicle_type']} • Masuk: ${formatDateTime(DateTime.parse(it['check_in_time'] as String))}',
                                    icon: const Icon(Icons.chevron_right),
                                    onTap: () => _pick(it),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
