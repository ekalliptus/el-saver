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
  static const _licenseStorageKey = 'premium_license';
  static const _deviceIdKey = 'premium_device_id';

  static const _redeemUrl = '${ApiConfig.cookieSyncUrl}/premium/redeem';
  static const _verifyUrl = '${ApiConfig.cookieSyncUrl}/premium/verify';
  static const _packagesUrl = '${ApiConfig.cookieSyncUrl}/premium/packages';
  static const _orderUrl = '${ApiConfig.cookieSyncUrl}/premium/order';

  bool _isPremium = false;
  String? _deviceId;
  String? _licenseKey;

  bool get isPremium => _isPremium;

  Future<void> initialize() async {
    try {
      _licenseKey = await _storage.read(key: _licenseStorageKey);
      _isPremium = _licenseKey != null;
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

  /// Fetches the available purchase packages from the server.
  Future<List<PremiumPackage>> fetchPackages() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final response = await dio.get(
      _packagesUrl,
      options: Options(headers: {'X-Api-Key': ApiConfig.backendApiKey}),
    );
    final list = (response.data['packages'] as List? ?? [])
        .whereType<Map>()
        .map((e) => PremiumPackage.fromJson(e.cast<String, dynamic>()))
        .toList();
    list.sort((a, b) => a.price.compareTo(b.price));
    return list;
  }

  /// Creates a purchase order and reserves a license for this device.
  Future<OrderInfo> createOrder(String packageId) async {
    if (_deviceId == null) {
      throw Exception('Perangkat tidak teridentifikasi.');
    }
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final response = await dio.post(
      _orderUrl,
      options: Options(headers: {'X-Api-Key': ApiConfig.backendApiKey}),
      data: {'device_id': _deviceId, 'package_id': packageId},
    );
    return OrderInfo.fromJson((response.data as Map).cast<String, dynamic>());
  }

  /// Polls an order; when paid, auto-activates the license on this device.
  /// Returns the order status ('pending' | 'paid'), or throws.
  Future<String> pollOrder(String orderId) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final response = await dio.get(
      '$_orderUrl/$orderId',
      options: Options(headers: {'X-Api-Key': ApiConfig.backendApiKey}),
    );
    final data = (response.data as Map).cast<String, dynamic>();
    if (data['status'] == 'paid' && data['license_key'] is String) {
      final key = data['license_key'] as String;
      await _storage.write(key: _licenseStorageKey, value: key);
      _licenseKey = key;
      _isPremium = true;
      return 'paid';
    }
    return data['status']?.toString() ?? 'pending';
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
        final normalized = licenseKey.trim().toUpperCase();
        await _storage.write(key: _licenseStorageKey, value: normalized);
        _licenseKey = normalized;
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
        await _storage.delete(key: _licenseStorageKey);
        _licenseKey = null;
        _isPremium = false;
      }
    } catch (_) {
      // Offline: keep the cached entitlement.
    }
  }
}

/// A purchasable premium package advertised by the server.
class PremiumPackage {
  final String id;
  final String name;
  final int price;
  final int? days;

  const PremiumPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.days,
  });

  factory PremiumPackage.fromJson(Map<String, dynamic> json) =>
      PremiumPackage(
        id: json['id'] as String,
        name: json['name'] as String,
        price: json['price'] as int,
        days: json['days'] as int?,
      );
}

/// A pending purchase order with payment instructions.
class OrderInfo {
  final String orderId;
  final String packageId;
  final String packageName;
  final int price;
  final String paymentInfo;

  const OrderInfo({
    required this.orderId,
    required this.packageId,
    required this.packageName,
    required this.price,
    required this.paymentInfo,
  });

  factory OrderInfo.fromJson(Map<String, dynamic> json) => OrderInfo(
        orderId: json['order_id'] as String,
        packageId: json['package_id'] as String,
        packageName: json['package_name'] as String? ?? json['package_id'],
        price: json['price'] as int,
        paymentInfo: json['payment_info'] as String? ?? '',
      );
}
