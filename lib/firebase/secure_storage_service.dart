import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] for all local secret storage.
///
/// Use this instead of SharedPreferences or dart:html localStorage for any
/// sensitive data: session tokens, refresh tokens, custom API keys, etc.
///
/// On Android this uses EncryptedSharedPreferences (AES-256 via AndroidKeyStore).
/// On iOS this uses the Keychain.
/// On Web this falls back to an in-memory store (do NOT persist long-lived
/// secrets in the browser -- rely on Firebase Auth's built-in session handling).
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Key constants ──
  static const _kSessionToken = 'session_token';
  static const _kRefreshToken = 'refresh_token';

  /// Store an arbitrary key/value pair securely.
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureStorageService: write error for key=$key: $e');
    }
  }

  /// Read a value by key. Returns null if absent.
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('SecureStorageService: read error for key=$key: $e');
      return null;
    }
  }

  /// Delete a single key.
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecureStorageService: delete error for key=$key: $e');
    }
  }

  /// Wipe all stored secrets (e.g. on sign-out).
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('SecureStorageService: deleteAll error: $e');
    }
  }

  // ── Convenience accessors for common tokens ──

  Future<void> saveSessionToken(String token) => write(_kSessionToken, token);
  Future<String?> getSessionToken() => read(_kSessionToken);

  Future<void> saveRefreshToken(String token) => write(_kRefreshToken, token);
  Future<String?> getRefreshToken() => read(_kRefreshToken);

  /// Call on sign-out to clear all cached credentials.
  Future<void> clearSession() => deleteAll();
}
