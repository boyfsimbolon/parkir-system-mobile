import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const _kInstallId = 'device_install_id';

/// Identitas HP untuk tabel scanner_devices:
/// install-id stabil (tetap sama walau logout) + nama model HP.
class DeviceId {
  static Future<String> installId(FlutterSecureStorage storage) async {
    var id = await storage.read(key: _kInstallId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await storage.write(key: _kInstallId, value: id);
    }
    return id;
  }

  static Future<String> deviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model} • Android ${a.version.release}'.trim();
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        return '${i.name} • ${i.systemName} ${i.systemVersion}';
      }
    } catch (_) {}
    return Platform.operatingSystem;
  }
}
