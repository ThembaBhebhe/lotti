import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lotti/classes/config.dart';

class SyncConfigService {
  final _storage = const FlutterSecureStorage();
  final String sharedSecretKey = 'sharedSecret';
  final String imapConfigKey = 'imapConfig';

  Future<SyncConfig?> getSyncConfig() async {
    String? sharedKey = await _storage.read(key: sharedSecretKey);
    String? imapConfigJson = await _storage.read(key: imapConfigKey);
    ImapConfig? imapConfig;

    if (imapConfigJson != null) {
      imapConfig = ImapConfig.fromJson(json.decode(imapConfigJson));
    }

    if (sharedKey != null && imapConfig != null) {
      return SyncConfig(
        imapConfig: imapConfig,
        sharedSecret: sharedKey,
      );
    }
    return null;
  }

  Future<void> generateSharedKey() async {
    final Key key = Key.fromSecureRandom(32);
    String sharedKey = key.base64;
    await _storage.write(key: sharedSecretKey, value: sharedKey);
  }

  Future<void> setSyncConfig(String configJson) async {
    SyncConfig syncConfig = SyncConfig.fromJson(json.decode(configJson));
    await _storage.write(
      key: sharedSecretKey,
      value: syncConfig.sharedSecret,
    );
    await _storage.write(
      key: imapConfigKey,
      value: json.encode(syncConfig.imapConfig.toJson()),
    );
  }

  Future<void> deleteSharedKey() async {
    await _storage.delete(key: sharedSecretKey);
  }

  Future<void> setImapConfig(ImapConfig imapConfig) async {
    String json = jsonEncode(imapConfig);
    await _storage.write(key: imapConfigKey, value: json);
  }
}
