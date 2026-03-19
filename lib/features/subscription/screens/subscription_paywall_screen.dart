import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:aerocab/core/purchases_service.dart';

class SubscriptionPaywallScreen extends StatefulWidget {
  const SubscriptionPaywallScreen({super.key, this.isDriver = false});
  final bool isDriver;

  @override
  State<SubscriptionPaywallScreen> createState() =>
      _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState
    extends State<SubscriptionPaywallScreen> {
  bool _isAnnual = false;
  bool _isLoading = false;
  bool _isLoadingOffering = true;
  Package? _monthlyPackage;
  Package? _annualPackage;

  @override
  void initState() {
    super.initState();
    _loadOffering();
  }

  Future<void> _loadOffering() async {
    final offering = await PurchasesService.getOffering(widget.isDriver);
    if (mounted) {
      setState(() {
        _monthlyPackage = offering?.monthly;
        _annualPackage = offering?.annual;
        _isLoadingOffering = false;
      });
    }
  }

  String get _monthlyPriceStr =>
      _monthlyPackage?.storeProduct.priceString ?? '-';
  String get _annualPriceStr =>
      _annualPackage?.storeProduct.priceString ?? '-';
  String get _annualMonthlyStr {
    final price = _annualPackage?.storeProduct.price;
    if (price == null) return '-';
    return '${(price / 12).toStringAsFixed(0)} ₺';
  }

  Future<void> _subscribe() async {
    final package = _isAnnual ? _annualPackage : _monthlyPackage;
    if (package == null) return;
    setState(() => _isLoading = true);
    try {
      final success = await PurchasesService.purchase(package);
      if (success && mounted) Navigator.pop(context, true);
    } on PurchasesError catch (e) {
      if (mounted && e.code != PurchasesErrorCode.purchaseCancelledError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Satın alma başarısız: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    final success = await PurchasesService.restorePurchases();
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Geri yüklenecek aktif abonelik bulunamadı.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close_rounded,
                    color: cs.onSurface.withValues(alpha: 0.4)),
                onPressed: () => Navigator.pop(context, false),
              ),
            ),

            if (_isLoadingOffering)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Column(
                    children: [
                      // İkon + başlık
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cs.primary, cs.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium_rounded,
                            size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'AeroCab Premium',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isDriver
                            ? 'Çevrimiçi ol ve yolculuk talepleri al'
                            : 'Hızlı ve güvenli yolculuk talep et',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      // 7 gün ücretsiz banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.celebration_rounded,
                                color: Colors.green.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '7 gün ücretsiz dene, beğenmezsen iptal et',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Aylık / Yıllık toggle
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            _PlanTab(
                              label: 'Aylık',
                              selected: !_isAnnual,
                              onTap: () => setState(() => _isAnnual = false),
                            ),
                            _PlanTab(
                              label: 'Yıllık',
                              badge: '2 ay ücretsiz',
                              selected: _isAnnual,
                              onTap: () => setState(() => _isAnnual = true),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Fiyat kartı
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _PriceCard(
                          key: ValueKey(_isAnnual),
                          isAnnual: _isAnnual,
                          monthlyPriceStr: _monthlyPriceStr,
                          annualPriceStr: _annualPriceStr,
                          annualMonthlyStr: _annualMonthlyStr,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Özellikler
                      _FeatureRow(
                        icon: Icons.lock_clock_outlined,
                        text: '7 gün ücretsiz deneme süresi',
                        highlight: true,
                      ),
                      const SizedBox(height: 12),
                      if (widget.isDriver) ...[
                        _FeatureRow(
                            icon: Icons.wifi_rounded,
                            text: 'Çevrimiçi ol, yolculuk talebi al'),
                        const SizedBox(height: 12),
                        _FeatureRow(
                            icon: Icons.bar_chart_rounded,
                            text: 'Kazanç takibi ve raporlar'),
                        const SizedBox(height: 12),
                        _FeatureRow(
                            icon: Icons.star_rounded,
                            text: 'Yolcu puanlama sistemi'),
                      ] else ...[
                        _FeatureRow(
                            icon: Icons.local_taxi_rounded,
                            text: 'Yolculuk talep et'),
                        const SizedBox(height: 12),
                        _FeatureRow(
                            icon: Icons.map_rounded,
                            text: 'Gerçek zamanlı sürücü takibi'),
                        const SizedBox(height: 12),
                        _FeatureRow(
                            icon: Icons.star_rounded,
                            text: 'Sürücü puanlama sistemi'),
                      ],
                      const SizedBox(height: 12),
                      _FeatureRow(
                          icon: Icons.cancel_outlined,
                          text: 'İstediğin zaman iptal et'),
                    ],
                  ),
                ),
              ),

            // Alt butonlar
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_isLoading ||
                              (_isAnnual
                                  ? _annualPackage == null
                                  : _monthlyPackage == null))
                          ? null
                          : _subscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              '7 Gün Ücretsiz Başla',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isAnnual
                        ? 'Deneme bittikten sonra $_annualPriceStr olarak faturalandırılırsınız.'
                        : 'Deneme bittikten sonra $_monthlyPriceStr / ay olarak faturalandırılırsınız.',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isLoading ? null : _restore,
                    child: Text(
                      'Satın alımları geri yükle',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Plan seçici tab ───────────────────────────────────────────────────────────
class _PlanTab extends StatelessWidget {
  const _PlanTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color:
                          selected ? Colors.white : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fiyat kartı ───────────────────────────────────────────────────────────────
class _PriceCard extends StatelessWidget {
  const _PriceCard({
    super.key,
    required this.isAnnual,
    required this.monthlyPriceStr,
    required this.annualPriceStr,
    required this.annualMonthlyStr,
  });

  final bool isAnnual;
  final String monthlyPriceStr;
  final String annualPriceStr;
  final String annualMonthlyStr;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: isAnnual
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      annualMonthlyStr,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        '/ ay',
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Yıllık $annualPriceStr olarak faturalandırılır',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  monthlyPriceStr,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Text(
                    '/ ay',
                    style: TextStyle(
                      fontSize: 15,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Özellik satırı ────────────────────────────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: highlight
                ? Colors.green.shade50
                : cs.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: highlight ? Colors.green.shade600 : cs.primary,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            color: highlight
                ? Colors.green.shade700
                : cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
