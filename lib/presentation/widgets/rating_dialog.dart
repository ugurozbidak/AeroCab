import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:aerocab/core/database_service.dart';

/// Shows a 5-star rating dialog with preset tag chips.
/// [ratedByPassenger] = true  → passenger rates driver
/// [ratedByPassenger] = false → driver rates passenger
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    required this.reservationId,
    required this.raterUid,
    required this.ratedUid,
    required this.ratedUserName,
    required this.ratedByPassenger,
    required this.dbService,
  });

  final String reservationId;
  final String raterUid;
  final String ratedUid;
  final String ratedUserName;
  final bool ratedByPassenger;
  final DatabaseService dbService;

  static Future<void> show(
    BuildContext context, {
    required String reservationId,
    required String raterUid,
    required String ratedUid,
    required String ratedUserName,
    required bool ratedByPassenger,
    required DatabaseService dbService,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        reservationId: reservationId,
        raterUid: raterUid,
        ratedUid: ratedUid,
        ratedUserName: ratedUserName,
        ratedByPassenger: ratedByPassenger,
        dbService: dbService,
      ),
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _stars = 0;
  final Set<String> _selectedTags = {};
  bool _saving = false;

  // Yolcu → sürücüyü değerlendiriyor
  static const _passengerRatesTags = [
    'Zamanında Geldi',
    'Güvenli Sürüş',
    'Araç Temizdi',
    'Güler Yüzlüydü',
    'Yardımcı Oldu',
  ];

  // Sürücü → yolcuyu değerlendiriyor
  static const _driverRatesTags = [
    'Zamanında Hazırdı',
    'Kibardı',
    'Temiz Kullandı',
    'İyi İletişim',
    'Sorunsuz Yolculuk',
  ];

  List<String> get _tags =>
      widget.ratedByPassenger ? _passengerRatesTags : _driverRatesTags;

  Future<void> _submit() async {
    if (_stars == 0) return;
    setState(() => _saving = true);
    try {
      await widget.dbService.saveRating(
        reservationId: widget.reservationId,
        raterUid: widget.raterUid,
        ratedUid: widget.ratedUid,
        stars: _stars,
        tags: _selectedTags.toList(),
      );
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.ratedByPassenger
        ? 'Sürücünüzü Değerlendirin'
        : 'Yolcunuzu Değerlendirin';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.ratedUserName,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 22),

            // Yıldızlar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setState(() {
                    _stars = i + 1;
                    _selectedTags.clear();
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(
                      i < _stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 46,
                      color: i < _stars
                          ? Colors.amber
                          : cs.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                );
              }),
            ),

            // Etiketler (yıldız seçildikten sonra görünür)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _stars == 0
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _tags.map((tag) {
                          final selected = _selectedTags.contains(tag);
                          return FilterChip(
                            label: Text(
                              tag,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: selected,
                            onSelected: (val) => setState(() {
                              if (val) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            }),
                            selectedColor: cs.primaryContainer,
                            checkmarkColor: cs.primary,
                            side: BorderSide(
                              color: selected
                                  ? cs.primary.withValues(alpha: 0.4)
                                  : cs.outline.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // Butonlar
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Sonra',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _stars == 0 || _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Gönder',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Küçük yıldız puanı rozeti: ⭐ 4.8 · 12 değerlendirme
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.avg, required this.count});
  final double avg;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
        const SizedBox(width: 3),
        Text(
          '${avg.toStringAsFixed(1)} · $count değerlendirme',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

/// Kendi puanını yükleyip gösteren widget (profil için)
class UserRatingWidget extends StatefulWidget {
  const UserRatingWidget({super.key, required this.uid, required this.dbService});
  final String uid;
  final DatabaseService dbService;

  @override
  State<UserRatingWidget> createState() => _UserRatingWidgetState();
}

class _UserRatingWidgetState extends State<UserRatingWidget> {
  Map<String, dynamic>? _stats;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await widget.dbService.getUserRatingStats(widget.uid);
    if (mounted) setState(() { _stats = stats; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_stats == null) {
      return Text(
        'Henüz değerlendirme yok',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }
    return RatingBadge(
      avg: (_stats!['avg'] as double),
      count: (_stats!['count'] as int),
    );
  }
}

/// Rezervasyon için puanlama butonu (geçmiş ekranında kullanılır).
/// Zaten puanlandıysa görünmez.
class RateRideButton extends StatefulWidget {
  const RateRideButton({
    super.key,
    required this.reservationId,
    required this.ratedUid,
    required this.ratedUserName,
    required this.ratedByPassenger,
    required this.dbService,
  });

  final String reservationId;
  final String ratedUid;
  final String ratedUserName;
  final bool ratedByPassenger;
  final DatabaseService dbService;

  @override
  State<RateRideButton> createState() => _RateRideButtonState();
}

class _RateRideButtonState extends State<RateRideButton> {
  bool _alreadyRated = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _checking = false); return; }
    final rated = await widget.dbService.hasRated(
        widget.reservationId, user.uid);
    if (mounted) setState(() { _alreadyRated = rated; _checking = false; });
  }

  Future<void> _openDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await RatingDialog.show(
      context,
      reservationId: widget.reservationId,
      raterUid: user.uid,
      ratedUid: widget.ratedUid,
      ratedUserName: widget.ratedUserName,
      ratedByPassenger: widget.ratedByPassenger,
      dbService: widget.dbService,
    );
    // After closing, re-check
    _check();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || _alreadyRated) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openDialog,
        icon: const Icon(Icons.star_outline_rounded, size: 16),
        label: const Text('Değerlendir'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.amber.shade700,
          side: BorderSide(color: Colors.amber.shade400),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
