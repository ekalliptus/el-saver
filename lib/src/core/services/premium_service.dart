import 'dart:io';

import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const _deviceIdChannel = MethodChannel('device_id');

  static const _redeemUrl = '${ApiConfig.cookieSyncUrl}/premium/redeem';
  static const _verifyUrl = '${ApiConfig.cookieSyncUrl}/premium/verify';
  static const _packagesUrl = '${ApiConfig.cookieSyncUrl}/premium/packages';
  static const _orderUrl = '${ApiConfig.cookieSyncUrl}/premium/order';
  static const _historyUrl = '${ApiConfig.cookieSyncUrl}/premium/orders/history';

  bool _isPremium = false;
  String? _deviceId;
  String? _legacyDeviceId;
  String? _licenseKey;

  bool get isPremium => _isPremium;

  Future<void> initialize() async {
    try {
      _licenseKey = await _storage.read(key: _licenseStorageKey);
      _isPremium = _licenseKey != null;
      _deviceId = await _resolveDeviceId();
    } catch (e) {
      debugPrint('PremiumService init failed: $e');
    }
  }

  /// Stable per-device identifier for server-side license binding.
  /// Settings.Secure.ANDROID_ID via the native `device_id` channel — unique
  /// per device + signing key and survives OS updates. Build.ID is blended
  /// into a synthetic fallback (hashed fingerprint) so this NEVER returns
  /// null on Android; the server's legacy_device_id migration covers
  /// transitions when the id changes.
  Future<String?> _resolveDeviceId() async {
    if (!Platform.isAndroid) return null;
    String? current;
    try {
      current = await _deviceIdChannel.invokeMethod<String>('androidId');
    } catch (_) {
      // Fall through to the synthetic fallback below.
    }
    if (current == null || current.isEmpty) {
      try {
        final android = await DeviceInfoPlugin().androidInfo;
        current = _fnv1a(android.fingerprint) + _fnv1a('${android.fingerprint}|els');
      } catch (_) {
        return null;
      }
    }
    if (current.isEmpty) return null;
    final normalized = current.toLowerCase();
    final cached = await _storage.read(key: _deviceIdKey);
    if (cached != null && cached != normalized) {
      _legacyDeviceId = cached;
    }
    await _storage.write(key: _deviceIdKey, value: normalized);
    return normalized;
  }

  static String _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (final code in input.codeUnits) {
      hash = (hash ^ code) & 0xFFFFFFFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
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
    // Lazy retry: a failed startup resolve must not permanently brick
    // purchasing for the session.
    _deviceId ??= await _resolveDeviceId();
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

  /// All orders ever created by this device (pending + paid), newest first —
  /// backs the purchase-history screen.
  Future<List<OrderHistoryItem>> fetchOrderHistory() async {
    final deviceId = _deviceId ?? await _resolveDeviceId();
    if (deviceId == null) return const [];
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final response = await dio.post(
      _historyUrl,
      options: Options(headers: {'X-Api-Key': ApiConfig.backendApiKey}),
      data: {'device_id': deviceId},
    );
    final list = (response.data['orders'] as List? ?? [])
        .whereType<Map>()
        .map((e) => OrderHistoryItem.fromJson(e.cast<String, dynamic>()))
        .toList();
    return list;
  }

  /// Re-fetches one order as a resumable [OrderInfo] (QR regenerated
  /// server-side), for continuing a pending payment.
  Future<OrderInfo> resumeOrder(String orderId) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final response = await dio.get(
      '$_orderUrl/$orderId',
      options: Options(headers: {'X-Api-Key': ApiConfig.backendApiKey}),
    );
    return OrderInfo.fromJson((response.data as Map).cast<String, dynamic>());
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
        data: {
        'key': licenseKey.trim().toUpperCase(),
        'device_id': _deviceId,
        if (_legacyDeviceId != null) 'legacy_device_id': _legacyDeviceId,
      },
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
      data: {
        'device_id': _deviceId,
        if (_legacyDeviceId != null) 'legacy_device_id': _legacyDeviceId,
      },
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

/// One row of this device's purchase history.
class OrderHistoryItem {
  final String orderId;
  final String packageId;
  final String packageName;
  final int price;
  final String grossAmount;
  final String status; // 'pending' | 'paid'
  final DateTime? createdAt;
  final DateTime? paidAt;

  const OrderHistoryItem({
    required this.orderId,
    required this.packageId,
    required this.packageName,
    required this.price,
    required this.grossAmount,
    required this.status,
    this.createdAt,
    this.paidAt,
  });

  bool get isPending => status == 'pending';

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) =>
      OrderHistoryItem(
        orderId: json['order_id'] as String,
        packageId: json['package_id'] as String,
        packageName:
            json['package_name'] as String? ?? json['package_id'] as String,
        price: (json['price'] as num).toInt(),
        grossAmount: json['gross_amount']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
      );
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

/// A pending purchase order with its dynamic QRIS payload.
class OrderInfo {
  final String orderId;
  final String packageId;
  final String packageName;
  final int price;
  final String grossAmount;
  final String qris;
  final String paymentInfo;

  const OrderInfo({
    required this.orderId,
    required this.packageId,
    required this.packageName,
    required this.price,
    required this.grossAmount,
    required this.qris,
    required this.paymentInfo,
  });

  factory OrderInfo.fromJson(Map<String, dynamic> json) => OrderInfo(
        orderId: json['order_id'] as String,
        packageId: json['package_id'] as String,
        packageName: json['package_name'] as String? ?? json['package_id'],
        price: json['price'] as int,
        grossAmount: json['gross_amount'] as String? ?? '',
        qris: json['qris'] as String? ?? '',
        paymentInfo: json['payment_info'] as String? ?? '',
      );
}
