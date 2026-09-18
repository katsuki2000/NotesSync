import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Generates, persists, and retrieves the AES-256 key used to encrypt the
/// local Hive boxes (notes + theme preferences).
///
/// The key itself never lives inside a Hive box: it's stored in the
/// platform's secure storage (Keychain on iOS/macOS, Keystore-backed
/// EncryptedSharedPreferences on Android), separate from the encrypted data
/// it protects.
class SecureKeyService {
  SecureKeyService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'notessync_hive_encryption_key';
  static const _keyLengthBytes = 32; // 256-bit key for HiveAesCipher.

  final FlutterSecureStorage _storage;

  /// Returns the persisted encryption key, generating and storing a new one
  /// on first run. Safe to call every app start: subsequent calls return the
  /// same key so previously-encrypted boxes stay readable.
  Future<List<int>> getEncryptionKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) {
      return base64Url.decode(existing);
    }

    final newKey = _generateKey();
    await _storage.write(key: _keyName, value: base64UrlEncode(newKey));
    return newKey;
  }

  List<int> _generateKey() {
    final random = Random.secure();
    return List<int>.generate(_keyLengthBytes, (_) => random.nextInt(256));
  }
}
