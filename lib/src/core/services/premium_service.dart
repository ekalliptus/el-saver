import 'dart:io';

import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/api_config.dart';

/// Premium entitlement backed by license codes validated on the EL-Saver
/// server. The license binds to the device's Android ID; the flag is cached
/// locally (secure storage) and re-verified against the server on startup.
class PremiumService {
  PremiumService();

  static const _storage = FlutterSecureStorage();
  static const _licenseKey = 'premium_license';
  static const _deviceIdKey = 'premium_device_id';

  static const _redeemUrl = '${ApiConfig.cookieSyncUrl}/premium/redeem';
  static const _verifyUrl = '${ApiConfig.cookieSyncUrl}/premium/verify';

  bool _isPremium = false;
  String? _deviceId;

  bool get isPremium => _isPremium;

  Future<void> initialize() async {
    try {
      _isPremium = await _storage.read(key: _licenseKey) != null;
      _deviceId = await _storage.read(key: _deviceIdKey);
      if (_deviceId == null && Platform.isAndroid) {
        final android = await DeviceInfoPlugin().androidInfo;
        _deviceId = android.id;
        if (_deviceId != null) {
          await _storage.write(key: _deviceIdKey, value: _deviceId);
        }
      }
    } catch (e) {
      debugPrint('PremiumService init failed: $e');
    }
  }

  /// Redeems [licenseKey] for this device. Returns an error message on
  /// failure, or null on success.
  Future<String?> redeem(String licenseKey) async {
    if (_deviceId == null) {
      return 'Perangkat tidak teridentifikasi. Coba lagi.';
    }
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.post(
        _redeemUrl,
        options: Options(headers: {'X-Api-Key': ApiConfig.backendApiKey}),
        data: {'key': licenseKey.trim(), 'device_id': _deviceId},
      );
      if (response.data is Map && response.data['premium'] == true) {
        await _storage.write(
            key: _licenseKey, value: licenseKey.trim().toUpperCase());
        _isPremium = true;
        return null;
      }
      return 'Server menolak kunci. Coba lagi.';
    } on DioException catch (e) {
      final detail = e.response?.data;
      if (detail is Map && detail['detail'] is String) {
        return detail['detail'] as String;
      }
      if (e.response?.statusCode == 404) {
        return 'Kunci tidak dikenal. Periksa lagi atau hubungi developer.';
      }
      if (e.response?.statusCode == 409) {
        return 'Kunci sudah dipakai di perangkat lain.';
      }
      return 'Tidak bisa menghubungi server. Cek koneksi internet.';
    } catch (e) {
      return 'Terjadi kesalahan. Coba lagi.';
    }
  }

  /// Re-checks the entitlement against the server (revocation support).
  Future<void> verify() async {
    if (!_isPremium || _deviceId == null) return;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.post(
        _verifyUrl,
        options: Options(headers: {'X-Api-Key': ApiConfig.backendApiKey}),
        data: {'device_id': _deviceId},
      );
      final premium = response.data is Map && response.data['premium'] == true;
      if (!premium) {
        await _storage.delete(key: _licenseKey);
        _isPremium = false;
      }
    } catch (_) {
      // Offline: keep the cached entitlement.
    }
  }
}
