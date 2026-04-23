import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../models/vault_model.dart';

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository();
});

class VaultRepository {
  static const _storage = FlutterSecureStorage();
  static const _vaultKey = 'encrypted_local_vault_v1';

  Future<VaultData> load() async {
    try {
      final raw = await _storage.read(key: _vaultKey);
      if (raw == null || raw.isEmpty) return VaultData.empty();
      return VaultData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // If secure storage fails, return empty vault
      print('Error loading vault: $e');
      return VaultData.empty();
    }
  }

  Future<void> save(VaultData vault) async {
    await _storage.write(key: _vaultKey, value: jsonEncode(vault.toJson()));
  }
}
