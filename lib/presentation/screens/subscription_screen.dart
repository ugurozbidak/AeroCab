import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aerocab/core/purchases_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  CustomerInfo? _customerInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await Purchases.getCustomerInfo();
      if (mounted) setState(() { _customerInfo = info; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  EntitlementInfo? get _entitlement =>
      _customerInfo?.entitlements.active[PurchasesService.entitlementId];

  String get _planName {
    final id = _entitlement?.productIdentifier ?? '';
    if (id.contains('annual') || id.contains('yearly')) return 'Yıllık';
    return 'Aylık';
  }

  String get _periodType {
    switch (_entitlement?.periodType) {
      case PeriodType.trial:
        return 'Ücretsiz Deneme';
      case PeriodType.intro:
        return 'Tanıtım Dönemi';
      default:
        return _planName;
    }
  }

  String? get _expirationDate {
    final date = _entitlement?.expirationDate;
    if (date == null) return null;
    final local = DateTime.parse(date).toLocal();
    return DateFormat('d MMMM y – HH:mm', 'tr').format(local);
  }

  bool get _willRenew => _entitlement?.willRenew ?? false;

  Future<void> _manageSubscription() async {
    final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ayarlar → Apple ID → Abonelikler yolunu izleyerek aboneliğinizi yönetebilirsiniz.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entitlement = _entitlement;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aboneliğim'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: entitlement == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.subscriptions_outlined,
                            size: 64,
                            color: cs.onSurface.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aktif aboneliğiniz bulunmuyor.',
                            style: TextStyle(
                              fontSize: 16,
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: cs.primary.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.workspace_premium_rounded,
                                      color: Color(0xFFFFD700), size: 24),
                                  const SizedBox(width: 10),
                                  Text(
                                    'AeroCab Premium',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _SubRow(
                                label: 'Durum',
                                value: 'Aktif',
                                valueColor: Colors.green,
                              ),
                              const SizedBox(height: 8),
                              _SubRow(
                                label: 'Plan',
                                value: _periodType,
                              ),
                              if (_expirationDate != null) ...[
                                const SizedBox(height: 8),
                                _SubRow(
                                  label: _willRenew
                                      ? 'Sonraki Ödeme'
                                      : 'Bitiş Tarihi',
                                  value: _expirationDate!,
                                ),
                              ],
                              const SizedBox(height: 8),
                              _SubRow(
                                label: 'Yenileme',
                                value: _willRenew ? 'Açık' : 'Kapalı',
                                valueColor: _willRenew ? Colors.green : Colors.orange,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _manageSubscription,
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: const Text('Aboneliği Yönet'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.error,
                              side: BorderSide(
                                  color: cs.error.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aboneliğinizi iptal etmek için App Store\'daki yönetim sayfasına yönlendirileceksiniz.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 14, color: cs.onSurface.withValues(alpha: 0.55)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? cs.onSurface,
          ),
        ),
      ],
    );
  }
}
