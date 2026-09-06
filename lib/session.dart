import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api.dart';

const _kToken = 'getter_access_token';
const _kRefresh = 'getter_refresh_token';

/// Menyimpan token permanen + data sesi. 401 dari API mana pun => sesi hangus.
class SessionManager extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  late final ApiClient api = ApiClient(
    tokenProvider: () => _token,
    refreshProvider: () => _refresh,
    onRefreshed: (a, r) async {
      _token = a;
      _refresh = r;
      await _storage.write(key: _kToken, value: a);
      await _storage.write(key: _kRefresh, value: r);
    },
  );

  String? _token;
  String? _refresh;
  Map<String, dynamic>? getter;
  Map<String, dynamic>? parking;
  List<dynamic> tariffs = [];
  bool loaded = false;
  /// Pesan satu-kali untuk layar aktivasi (mis. "Sesi berakhir, scan ulang").
  String? sessionNotice;

  String? get token => _token;
  bool get loggedIn => _token != null && _token!.isNotEmpty;
  int get parkingId {
    final p = parking?['id'];
    if (p is int) return p;
    return 0;
  }

  void _applyMe(Map<String, dynamic> me) {
    // API /me mengembalikan `getter` (lengkap) + `user` (sesi). Pakai getter
    // bila ada agar nama petugas tidak pernah "-".
    final g = me['getter'] as Map<String, dynamic>?;
    getter = g ?? (me['user'] as Map<String, dynamic>?);
    parking = me['parking'] as Map<String, dynamic>?;
    tariffs = (me['tariffs'] as List?) ?? [];
  }

  Future<void> load() async {
    _token = await _storage.read(key: _kToken);
    _refresh = await _storage.read(key: _kRefresh);
    if (!loggedIn) {
      loaded = true;
      notifyListeners();
      return;
    }
    try {
      _applyMe(await api.me());
      if (getter == null || parking == null) {
        // Token valid tapi data tak lengkap (kasus lama) → paksa login ulang.
        await logout(notice: 'Data sesi tidak lengkap. Silakan scan ulang QR aktivasi.');
        return;
      }
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await logout(notice: 'Sesi tidak valid. Silakan scan ulang QR aktivasi.');
        return;
      }
      // Offline / server mati: tetap anggap login, data di-refresh nanti.
    } catch (_) {
      // Offline / server mati: tetap anggap login, data di-refresh nanti.
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> saveActivation(Map<String, dynamic> res) async {
    _token = res['access_token'] as String;
    _refresh = res['refresh_token'] as String?;
    await _storage.write(key: _kToken, value: _token);
    if (_refresh != null) await _storage.write(key: _kRefresh, value: _refresh);
    sessionNotice = null;
    getter = res['getter'] as Map<String, dynamic>?;
    try {
      _applyMe(await api.me());
    } catch (_) {}
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _applyMe(await api.me());
      if (getter == null || parking == null) {
        await logout(notice: 'Data sesi tidak lengkap. Silakan scan ulang QR aktivasi.');
        return;
      }
      notifyListeners();
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await logout(notice: 'Sesi tidak valid. Silakan scan ulang QR aktivasi.');
        return;
      }
      rethrow;
    }
  }

  /// Dipanggil saat API 401: akun dinonaktifkan/dihapus atau token dicabut.
  /// Token + semua data tersimpan dihapus, pengguna diminta scan ulang.
  Future<void> logout({String? notice}) async {
    _token = null;
    _refresh = null;
    getter = null;
    parking = null;
    tariffs = [];
    sessionNotice = notice ?? 'Sesi berakhir. Silakan scan ulang QR aktivasi.';
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kRefresh);
    // device_install_id SENGAJA tidak dihapus agar HP tetap dikenali
    // di scanner_devices setelah login ulang.
    notifyListeners();
  }

  /// Diambil & dihapus oleh layar aktivasi untuk ditampilkan sekali saja.
  String? takeNotice() {
    final n = sessionNotice;
    sessionNotice = null;
    return n;
  }
}
