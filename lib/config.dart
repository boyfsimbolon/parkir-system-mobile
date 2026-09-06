import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konfigurasi dari file .env (lihat .env.example).
class AppConfig {
  static String get apiBaseUrl =>
      (dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000')
          .replaceAll(RegExp(r'/$'), '');

  static String get qrPrefix => dotenv.env['QR_CODE_PREFIX'] ?? 'PRK';

  static int get maxPhotoKb =>
      int.tryParse(dotenv.env['MAX_PHOTO_KB'] ?? '500') ?? 500;

  static int get apiTimeoutSeconds =>
      int.tryParse(dotenv.env['API_TIMEOUT_SECONDS'] ?? '15') ?? 15;
}
