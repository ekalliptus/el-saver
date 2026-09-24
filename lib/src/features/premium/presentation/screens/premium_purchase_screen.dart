import 'dart:async';

import 'package:flutter/material.dart';

import 'package:el_saver/src/core/common_widgets/toast.dart';
import 'package:el_saver/src/core/services/premium_service.dart';
import 'package:el_saver/src/core/utils/app_colors.dart';
import 'package:el_saver/src/core/utils/app_enums.dart';

String formatRupiah(int amount) =>
    'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

/// Purchase page: pick a package, create an order, show payment info, and
/// auto-activate the license once the server marks the order paid. The user
/// never types a license key.
class PremiumPurchaseScreen extends StatefulWidget {
  const PremiumPurchaseScreen({super.key});

  @override
  State<PremiumPurchaseScreen> createState() => _PremiumPurchaseScreenState();
}

class _PremiumPurchaseScreenState extends State<PremiumPurchaseScreen> {
  final PremiumService _premium = PremiumService();
  List<PremiumPackage>? _packages;
  String? _loadError;
  OrderInfo? _order;
  bool _creating = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    try {
      final packages = await _premium.fetchPackages();
      if (!mounted) return;
      setState(() {
        _packages = packages;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError =
          'Tidak bisa memuat paket. Periksa koneksi internet lalu coba lagi.');
    }
  }

  Future<void> _buy(PremiumPackage pkg) async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final order = await _premium.createOrder(pkg.id);
      if (!mounted) return;
      setState(() {
        _order = order;
        _creating = false;
      });
      _startPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      buildToast(
        msg: 'Gagal membuat order. Coba lagi.',
        type: ToastType.error,
      );
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (timer) async {
      attempts++;
      if (attempts > 100 || !mounted) {
        timer.cancel();
        return;
      }
      try {
        final status = await _premium.pollOrder(_order!.orderId);
        if (status == 'paid' && mounted) {
          timer.cancel();
          buildToast(
            msg: 'Pembayaran terkonfirmasi! Premium aktif 🎉',
            type: ToastType.success,
          );
          Navigator.of(context).pop(true);
        }
      } catch (_) {
        // transient network error: keep polling
      }
    });
  }

  Future<void> _checkNow() async {
    try {
      final status = await _premium.pollOrder(_order!.orderId);
      if (status == 'paid' && mounted) {
        _pollTimer?.cancel();
        buildToast(
          msg: 'Pembayaran terkonfirmasi! Premium aktif 🎉',
          type: ToastType.success,
        );
        Navigator.of(context).pop(true);
      } else {
        buildToast(
          msg: 'Belum terkonfirmasi. Kami terus memeriksa otomatis.',
          type: ToastType.info,
        );
      }
    } catch (_) {
      buildToast(msg: 'Gagal memeriksa status. Coba lagi.', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beli Premium')),
      body: _order != null ? _buildWaiting() : _buildPackages(),
    );
  }

  Widget _buildPackages() {
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56,
                color: AppColors.primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_loadError!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadPackages,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    final packages = _packages;
    if (packages == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: AppColors.primaryColor.withValues(alpha: 0.08),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.workspace_premium, color: AppColors.primaryColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Premium = tanpa iklan, sekali bayar untuk perangkat ini. '
                    'Pilih paket, bayar, dan lisensi terpasang otomatis — '
                    'tanpa memasukkan kode manual.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final pkg in packages)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              leading: Icon(
                pkg.days == null
                    ? Icons.all_inclusive
                    : Icons.calendar_month,
                color: AppColors.primaryColor,
                size: 32,
              ),
              title: Text(pkg.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                pkg.days == null
                    ? 'Aktif selamanya di perangkat ini'
                    : 'Aktif ${pkg.days} hari di perangkat ini',
              ),
              trailing: FilledButton(
                onPressed: _creating ? null : () => _buy(pkg),
                child: _creating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(formatRupiah(pkg.price)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWaiting() {
    final order = _order!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        color: AppColors.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pesanan ${order.packageName}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Nomor pesanan: ${order.orderId}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text('Total: ${formatRupiah(order.price)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Cara bayar:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(order.paymentInfo),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Menunggu konfirmasi pembayaran. Lisensi akan aktif otomatis '
                'begitu pembayaran terverifikasi.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _checkNow,
          icon: const Icon(Icons.refresh),
          label: const Text('Saya Sudah Bayar — Cek Sekarang'),
        ),
        TextButton(
          onPressed: () {
            _pollTimer?.cancel();
            Navigator.of(context).pop();
          },
          child: const Text('Batalkan'),
        ),
      ],
    );
  }
}
