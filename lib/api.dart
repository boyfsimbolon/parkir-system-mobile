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
  @override
  String toString() => message;
}

class ApiClient {
  final String? Function() tokenProvider;
  ApiClient({required this.tokenProvider});

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

  Future<Map<String, dynamic>> _get(String path) async {
    final r = await http
        .get(Uri.parse('${AppConfig.apiBaseUrl}$path'), headers: _headers)
        .timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));
    if (r.statusCode != 200) _throw(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final r = await http
        .post(Uri.parse('${AppConfig.apiBaseUrl}$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));
    if (r.statusCode != 200 && r.statusCode != 201) _throw(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- tanpa token ----
  Future<Map<String, dynamic>> activate(String token) async {
    final r = await http
        .post(Uri.parse('${AppConfig.apiBaseUrl}/api/mobile/activate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}))
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

  Future<Map<String, dynamic>> lostQrCheckout(int id, String method) =>
      _post('/api/mobile/lost-qr', {'transaction_id': id, 'payment_method': method});

  Future<Map<String, dynamic>> checkin({
    required String barcode,
    required String vehicleType,
    required String photoUrl,
  }) =>
      _post('/api/mobile/checkin', {
        'barcode_data': barcode,
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
