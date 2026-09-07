import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  bool get unauthorized => status == 401;
  /// 403 PARKING_DISABLED: parkiran dinonaktifkan — jangan logout,
  /// refresh sesi agar aplikasi pindah ke layar pemberitahuan.
  bool get parkingDisabled => status == 403;
  @override
  String toString() => message;
}

class ApiClient {
  final String? Function() tokenProvider;
  final String? Function() refreshProvider;
  final Future<void> Function(String access, String refresh)? onRefreshed;
  ApiClient({required this.tokenProvider, String? Function()? refreshProvider, this.onRefreshed})
      : refreshProvider = refreshProvider ?? (() => null);

  Map<String, String> get _headers {
    final t = tokenProvider();
    return {
      'Content-Type': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  Never _throw(http.Response r) {
    String msg = 'Terjadi kesalahan (${r.statusCode})';
    try {
      final b = jsonDecode(r.body);
      if (b is Map && b['error'] is String) msg = b['error'] as String;
    } catch (_) {}
    throw ApiException(r.statusCode, msg);
  }

  Future<Map<String, dynamic>> _get(String path, {bool retried = false}) async {
    final r = await http
        .get(Uri.parse('${AppConfig.apiBaseUrl}$path'), headers: _headers)
        .timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));
    if (r.statusCode == 401 && !retried && await _tryRefresh()) {
      return _get(path, retried: true); // coba sekali lagi dengan token baru
    }
    if (r.statusCode != 200) _throw(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {bool retried = false}) async {
    final r = await http
        .post(Uri.parse('${AppConfig.apiBaseUrl}$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));
    if (r.statusCode == 401 && !retried && await _tryRefresh()) {
      return _post(path, body, retried: true); // coba sekali lagi
    }
    if (r.statusCode != 200 && r.statusCode != 201) _throw(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Silent refresh: tukar refresh token jadi access baru, simpan, lanjut.
  /// Return false bila refresh gagal (pemanggil akan logout via 401).
  Future<bool> _tryRefresh() async {
    final rt = refreshProvider();
    if (rt == null || rt.isEmpty || onRefreshed == null) return false;
    try {
      final r = await http
          .post(Uri.parse('${AppConfig.apiBaseUrl}/api/mobile/refresh'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': rt}))
          .timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));
      if (r.statusCode != 200) return false;
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      await onRefreshed!(b['access_token'] as String, b['refresh_token'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- tanpa token ----
  Future<Map<String, dynamic>> activate(String token,
      {String? deviceUuid, String? deviceName}) async {
    final payload = <String, dynamic>{'token': token};
    if (deviceUuid != null && deviceUuid.isNotEmpty) {
      payload['device_uuid'] = deviceUuid;
    }
    if (deviceName != null && deviceName.isNotEmpty) {
      payload['device_name'] = deviceName;
    }
    final r = await http
        .post(Uri.parse('${AppConfig.apiBaseUrl}/api/mobile/activate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload))
        .timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));
    if (r.statusCode != 200) _throw(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- butuh token getter ----
  Future<Map<String, dynamic>> me() => _get('/api/mobile/me');

  Future<Map<String, dynamic>> parked({int limit = 50}) =>
      _get('/api/mobile/parked?limit=$limit');

  Future<Map<String, dynamic>> checkoutPreview(String code) =>
      _get('/api/mobile/checkout?code=${Uri.encodeComponent(code)}');

  Future<Map<String, dynamic>> checkout(String barcode, String method) =>
      _post('/api/mobile/checkout', {'barcode_data': barcode, 'payment_method': method});

  Future<Map<String, dynamic>> lostQrCheckout(int id, String method) {
    return _post('/api/mobile/lost-qr', {
      'transaction_id': id,
      'payment_method': method,
    });
  }

  Future<Map<String, dynamic>> checkin({
    required String barcode,
    required String platNomor,
    required String vehicleType,
    required String photoUrl,
  }) =>
      _post('/api/mobile/checkin', {
        'barcode_data': barcode,
        'plat_nomor': platNomor,
        'vehicle_type': vehicleType,
        'photo_url': photoUrl,
      });

  /// Upload foto check-in. Mengembalikan public URL.
  Future<String> uploadCheckinPhoto(File file, String barcode) async {
    final t = tokenProvider();
    final req = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiBaseUrl}/api/upload'));
    if (t != null && t.isNotEmpty) req.headers['Authorization'] = 'Bearer $t';
    req.fields['kind'] = 'checkin';
    req.fields['barcode'] = barcode;
    req.files.add(await http.MultipartFile.fromPath('file', file.path,
        contentType: http.MediaType('image', 'jpeg')));
    final streamed = await req.send().timeout(Duration(seconds: AppConfig.apiTimeoutSeconds * 3));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      String msg = 'Upload gagal (${streamed.statusCode})';
      try {
        final b = jsonDecode(body);
        if (b is Map && b['error'] is String) msg = b['error'] as String;
      } catch (_) {}
      throw ApiException(streamed.statusCode, msg);
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['url'] as String;
  }
}
