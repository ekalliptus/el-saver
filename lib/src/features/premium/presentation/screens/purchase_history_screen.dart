import 'package:flutter/material.dart';

import '../../../../container_injector.dart';
import '../../../../config/routes_manager.dart';
import '../../../../core/common_widgets/fancy_loader.dart';
import '../../../../core/services/premium_service.dart';
import '../../../../core/utils/app_colors.dart';
import '../../../../core/utils/app_strings.dart';
import 'premium_purchase_screen.dart';

/// Purchase history for this device. Pending orders (user left mid-payment)
/// can be resumed straight into the payment screen.
class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  final PremiumService _premium = sl<PremiumService>();
  List<OrderHistoryItem>? _orders;
  String? _error;
  String? _resumingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _orders = null;
      _error = null;
    });
    try {
      final orders = await _premium.fetchOrderHistory();
      if (!mounted) return;
      setState(() => _orders = orders);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.loadFailed);
    }
  }

  Future<void> _cancel(OrderHistoryItem item) async {
    if (_resumingId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(AppStrings.cancelOrder),
        content: Text(AppStrings.cancelOrderConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(AppStrings.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: Text(AppStrings.yes),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resumingId = item.orderId);
    try {
      await _premium.cancelOrder(item.orderId);
    } catch (_) {}
    if (mounted) {
      setState(() => _resumingId = null);
      _load();
    }
  }

  Future<void> _resume(OrderHistoryItem item) async {
    if (_resumingId != null) return;
    setState(() => _resumingId = item.orderId);
    try {
      final order = await _premium.resumeOrder(item.orderId);
      if (!mounted) return;
      // Replace this screen with the payment screen showing that order.
      Navigator.of(context)
        ..pop()
        ..pushReplacementNamed(Routes.premiumPurchase, arguments: order);
    } catch (_) {
      if (!mounted) return;
      setState(() => _resumingId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.tryAgain),
        backgroundColor: AppColors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.purchaseHistory)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(AppStrings.tryAgain)),
          ],
        ),
      );
    }
    final orders = _orders;
    if (orders == null) {
      return const Center(child: FancyLoader(size: 32));
    }
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56,
                color: AppColors.primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(AppStrings.emptyPurchaseHistory,
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in orders)
            _HistoryCard(
              item: item,
              onResume: () => _resume(item),
              onCancel: () => _cancel(item),
              resuming: _resumingId == item.orderId,
            ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final OrderHistoryItem item;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final bool resuming;

  const _HistoryCard({
    required this.item,
    required this.onResume,
    required this.onCancel,
    required this.resuming,
  });

  String _formatDate(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$local.year $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final amount =
        int.tryParse(item.grossAmount) ?? item.price;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.packageName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                _StatusChip(item: item),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${AppStrings.totalLabel(formatRupiah(amount))}   ·   ${_formatDate(item.paidAt ?? item.createdAt)}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.orderNumber(item.orderId),
              style: const TextStyle(fontSize: 11),
            ),
            if (item.isPending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: resuming ? null : onResume,
                      icon: resuming
                          ? const FancyLoader(size: 12, color: Colors.white)
                          : const Icon(Icons.qr_code_rounded, size: 18),
                      label: Text(AppStrings.resumePayment),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onCancel,
                    child: Text(AppStrings.cancelOrder,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderHistoryItem item;
  const _StatusChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (item.status) {
      'pending' => (AppStrings.statusPending, Colors.orange),
      'paid' => (AppStrings.statusPaid, AppColors.green),
      _ => (AppStrings.statusCancelled, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
