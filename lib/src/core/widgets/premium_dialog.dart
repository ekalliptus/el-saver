import 'package:flutter/material.dart';

import '../services/premium_service.dart';
import '../utils/app_colors.dart';

/// Paywall + redeem dialog. Shows benefits, a license key field, and the
/// redeem action. [onPremiumChanged] fires after a successful redeem.
Future<void> showPremiumDialog(
  BuildContext context, {
  required PremiumService premium,
  required bool isPremium,
  VoidCallback? onPremiumChanged,
}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => _PremiumDialog(
      premium: premium,
      isPremium: isPremium,
      onPremiumChanged: onPremiumChanged,
    ),
  );
}

class _PremiumDialog extends StatefulWidget {
  final PremiumService premium;
  final bool isPremium;
  final VoidCallback? onPremiumChanged;

  const _PremiumDialog({
    required this.premium,
    required this.isPremium,
    this.onPremiumChanged,
  });

  @override
  State<_PremiumDialog> createState() => _PremiumDialogState();
}

class _PremiumDialogState extends State<_PremiumDialog> {
  final _keyController = TextEditingController();
  bool _redeeming = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Masukkan kode lisensi dulu.');
      return;
    }
    setState(() {
      _redeeming = true;
      _error = null;
    });
    final error = await widget.premium.redeem(key);
    if (!mounted) return;
    if (error == null) {
      widget.onPremiumChanged?.call();
      Navigator.pop(context);
    } else {
      setState(() {
        _redeeming = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        widget.isPremium ? Icons.verified_rounded : Icons.workspace_premium,
        size: 44,
        color: AppColors.primaryColor,
      ),
      title: Text(widget.isPremium ? 'Premium Aktif' : 'EL-Saver Premium'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isPremium)
            const Text(
              'Terima kasih! Iklan sudah dinonaktifkan di perangkat ini. '
              'Nikmati pengalaman download tanpa gangguan.',
            )
          else ...[
            const Text(
              'Dapatkan akses tanpa iklan dan dukung pengembangan aplikasi '
              'dengan satu kali pembelian lisensi:',
            ),
            const SizedBox(height: 8),
            const _BenefitRow('Tanpa iklan, fokus download'),
            const _BenefitRow('Aktif selamanya di perangkat ini'),
            const _BenefitRow('Mendukung update fitur berikutnya'),
            const SizedBox(height: 16),
            const Text('Kode lisensi'),
            const SizedBox(height: 6),
            TextField(
              controller: _keyController,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'ELS-XXXX-XXXX-XXXX',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.red, fontSize: 12)),
            ],
          ],
        ],
      ),
      actions: widget.isPremium
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ]
          : [
              TextButton(
                onPressed: _redeeming
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Nanti'),
              ),
              FilledButton.icon(
                onPressed: _redeeming ? null : () => _redeem(),
                icon: _redeeming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.key_rounded, size: 18),
                label: Text(_redeeming ? 'Memeriksa...' : 'Aktifkan'),
              ),
            ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String text;
  const _BenefitRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
