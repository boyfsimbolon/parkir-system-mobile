import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api.dart';

const _kToken = 'getter_access_token';

/// Menyimpan token permanen + data sesi. 401 dari API mana pun => sesi hangus.
class SessionManager extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  late final ApiClient api = ApiClient(tokenProvider: () => _token);

  String? _token;
  Map<String, dynamic>? getter;
  Map<String, dynamic>? parking;
  List<dynamic> tariffs = [];
  bool loaded = false;

  String? get token => _token;
  bool get loggedIn => _token != null && _token!.isNotEmpty;
  int get parkingId {
    final p = parking?['id'];
    if (p is int) return p;
    return 0;
  }

  Future<void> load() async {
    _token = await _storage.read(key: _kToken);
    if (!loggedIn) {
      loaded = true;
      notifyListeners();
      return;
    }
    try {
      final me = await api.me();
      getter = me['user'] as Map<String, dynamic>?;
      parking = me['parking'] as Map<String, dynamic>?;
      tariffs = (me['tariffs'] as List?) ?? [];
    } on ApiException catch (e) {
      if (e.unauthorized) await logout();
    } catch (_) {
      // Offline / server mati: tetap anggap login, data di-refresh nanti.
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> saveActivation(Map<String, dynamic> res) async {
    _token = res['access_token'] as String;
    await _storage.write(key: _kToken, value: _token);
    getter = res['getter'] as Map<String, dynamic>?;
    try {
      final me = await api.me();
      parking = me['parking'] as Map<String, dynamic>?;
      tariffs = (me['tariffs'] as List?) ?? [];
    } catch (_) {}
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final me = await api.me();
      getter = me['user'] as Map<String, dynamic>?;
      parking = me['parking'] as Map<String, dynamic>?;
      tariffs = (me['tariffs'] as List?) ?? [];
      notifyListeners();
    } on ApiException catch (e) {
      if (e.unauthorized) await logout();
      rethrow;
    }
  }

  /// Dipanggil saat API 401: akun dinonaktifkan/dihapus atau token dicabut.
  Future<void> logout() async {
    _token = null;
    getter = null;
    parking = null;
    tariffs = [];
    await _storage.delete(key: _kToken);
    notifyListeners();
  }
}
