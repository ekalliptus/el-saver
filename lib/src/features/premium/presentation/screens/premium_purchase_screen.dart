import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:el_saver/src/core/common_widgets/toast.dart';
import 'package:el_saver/src/container_injector.dart' show sl;
import 'package:el_saver/src/core/services/premium_service.dart';
import 'package:el_saver/src/core/utils/app_colors.dart';
import 'package:el_saver/src/core/utils/app_enums.dart';
import 'package:el_saver/src/core/utils/app_strings.dart';
import '../../../../config/routes_manager.dart';
import '../../../../core/common_widgets/fancy_loader.dart';
import '../../../../core/common_widgets/skeleton_loader.dart';

String formatRupiah(int amount) =>
    'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

/// Purchase page: pick a package, create an order, show payment info, and
/// auto-activate the license once the server marks the order paid. The user
/// never types a license key.
class PremiumPurchaseScreen extends StatefulWidget {
  /// Reopen a pending order (from the purchase-history screen).
  final OrderInfo? resumeOrder;
  const PremiumPurchaseScreen({super.key, this.resumeOrder});

  @override
  State<PremiumPurchaseScreen> createState() => _PremiumPurchaseScreenState();
}

class _PremiumPurchaseScreenState extends State<PremiumPurchaseScreen> {
  // The app-lifetime singleton: a throwaway instance would mark premium on
  // itself after payment and the rest of the app would never find out.
  final PremiumService _premium = sl<PremiumService>();
  List<PremiumPackage>? _packages;
  String? _loadError;
  OrderInfo? _order;
  bool _creating = false;
  bool _settled = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadPackages();
    final resumed = widget.resumeOrder;
    if (resumed != null) {
      _order = resumed;
      _startPolling();
    }
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
          AppStrings.loadPackagesFailed);
    }
  }

  /// Prefer the server's own validation message (it names the real problem,
  /// e.g. "device_id tidak valid") over a generic retry toast.
  String _describeOrderError(Object error) {
    if (error is DioException) {
      final detail = error.response?.data;
      if (detail is Map && detail['detail'] is String) {
        return detail['detail'] as String;
      }
    }
    final text = error.toString();
    if (text.contains('Exception: ')) {
      return text.split('Exception: ').last;
    }
    return AppStrings.createOrderFailed;
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      buildToast(msg: _describeOrderError(e), type: ToastType.error);
    }
  }

  bool _cancelling = false;

  /// Real cancellation: frees the pending slot on the server so the
  /// device is never blocked from buying again (the old button only
  /// closed the screen and left the order pending forever).
  Future<void> _cancelOrder() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    _pollTimer?.cancel();
    final order = _order;
    try {
      if (order != null) await _premium.cancelOrder(order.orderId);
    } catch (_) {
      // Offline/unknown order: popping anyway is fine - stale pendings
      // are auto-cancelled server-side after 24h.
    }
    if (mounted) Navigator.of(context).pop(false);
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
        if (status == 'paid' && mounted && !_settled) {
          _settled = true;
          timer.cancel();
          buildToast(
            msg: AppStrings.paymentConfirmed,
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
      if (status == 'paid' && mounted && !_settled) {
        _settled = true;
        _pollTimer?.cancel();
        buildToast(
          msg: AppStrings.paymentConfirmed,
          type: ToastType.success,
        );
        Navigator.of(context).pop(true);
      } else if (!_settled) {
        buildToast(
          msg: AppStrings.paymentNotConfirmedYet,
          type: ToastType.info,
        );
      }
    } catch (_) {
      buildToast(msg: AppStrings.checkStatusFailed, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.buyPremium),
        actions: [
          IconButton(
            tooltip: AppStrings.purchaseHistory,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(Routes.premiumHistory),
          ),
        ],
      ),
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
              child: Text(AppStrings.tryAgain),
            ),
          ],
        ),
      );
    }
    final packages = _packages;
    if (packages == null) {
      // Skeleton cards mirror the package list layout while loading.
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final _ in List.filled(3, 0))
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Shimmer(
                child:
                    SkeletonBox(width: double.infinity, height: 88, radius: 12),
              ),
            ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: AppColors.primaryColor.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: AppColors.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.premiumInfoCard,
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
                    ? AppStrings.activeForeverOnDevice
                    : AppStrings.activeDaysOnDevice(pkg.days!),
              ),
              trailing: FilledButton(
                onPressed: _creating ? null : () => _buy(pkg),
                child: _creating
                    ? const FancyLoader(size: 14, color: Colors.white)
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        color: AppColors.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.orderTitle(order.packageName),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (order.qris.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: order.qris,
                      size: 230,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.scanToPay,
                    style: const TextStyle(fontSize: 12),
                  ),
                ] else ...[
                  Text(order.paymentInfo),
                ],
                const SizedBox(height: 12),
                Builder(builder: (_) {
                  // gross includes the unique whole-rupiah suffix and is
                  // what must be paid; show it formatted, never raw.
                  final payable =
                      int.tryParse(order.grossAmount) ?? order.price;
                  return Text(
                    AppStrings.totalLabel(formatRupiah(payable)),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18),
                  );
                }),
                if (order.grossAmount.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: order.grossAmount));
                      buildToast(
                          msg: AppStrings.amountCopied,
                          type: ToastType.success,
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(AppStrings.copyExactAmount),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.exactAmountNote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
                const SizedBox(height: 4),
                Text(AppStrings.orderNumber(order.orderId),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FancyLoader(size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppStrings.waitingForPayment,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _checkNow,
          icon: const Icon(Icons.refresh),
          label: Text(AppStrings.iAlreadyPaidCheckNow),
        ),
        TextButton(
          onPressed: _cancelling ? null : _cancelOrder,
          child: _cancelling
              ? const FancyLoader(size: 12)
              : Text(AppStrings.cancelOrder),
        ),
      ],
    );
  }
}
