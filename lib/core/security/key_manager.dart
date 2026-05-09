import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager();
});

class KeyManager {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  static const _masterKeyAlias = 'second_brain_master_key_v1';

  /// Retrieves the existing master key or generates a new one.
  Future<String> getOrCreateMasterKey() async {
    final existingKey = await _storage.read(key: _masterKeyAlias);
    if (existingKey != null && existingKey.isNotEmpty) {
      return existingKey;
    }

    // Generate a secure 256-bit (32 byte) random key
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final newKey = base64Encode(keyBytes);

    await _storage.write(key: _masterKeyAlias, value: newKey);
    return newKey;
  }

  /// Deletes the master key (useful for wiping the device)
  Future<void> wipeKey() async {
    await _storage.delete(key: _masterKeyAlias);
  }
}
