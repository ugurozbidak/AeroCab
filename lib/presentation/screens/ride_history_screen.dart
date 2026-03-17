import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:myapp/core/database_service.dart';
import 'package:myapp/presentation/widgets/rating_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class RideHistoryScreen extends ConsumerWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final dbService = ref.read(databaseServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Yolculuk Geçmişi')),
      body: user == null
          ? const Center(child: Text("Geçmişinizi görmek için giriş yapın."))
          : FutureBuilder<List<QueryDocumentSnapshot>>(
              future: dbService.getRideHistory(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Bir hata oluştu: ${snapshot.error}"),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text("Geçmiş yolculuğunuz bulunmuyor."));
                }

                final rides = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final ride =
                        rides[index].data() as Map<String, dynamic>;
                    final status = ride['status'] as String;
                    final createdAt =
                        (ride['created_at'] as Timestamp).toDate();
                    final formattedDate =
                        DateFormat.yMMMd('tr').add_jm().format(createdAt);

                    final pickupGeo = ride['pickup_location'] as GeoPoint;
                    final destGeo =
                        ride['destination_location'] as GeoPoint;
                    final pickupStr = ride['pickup_address'] as String? ??
                        '${pickupGeo.latitude.toStringAsFixed(4)}, ${pickupGeo.longitude.toStringAsFixed(4)}';
                    final destStr =
                        ride['destination_address'] as String? ??
                            '${destGeo.latitude.toStringAsFixed(4)}, ${destGeo.longitude.toStringAsFixed(4)}';
                    final price = ride['price'] as num?;
                    final cs = Theme.of(context).colorScheme;

                    final (Color chipColor, Color chipBg, IconData icon) =
                        switch (status) {
                      'completed' => (
                          Colors.green.shade700,
                          Colors.green.shade50,
                          Icons.check_circle_outline_rounded
                        ),
                      'cancelled' => (
                          Colors.red.shade700,
                          Colors.red.shade50,
                          Icons.cancel_outlined
                        ),
                      _ => (
                          Colors.grey.shade600,
                          Colors.grey.shade100,
                          Icons.schedule_rounded
                        ),
                    };

                    // Değerlendirme & Unutulan Eşya: tamamlanmış ve 24 saat içindeki yolculuklarda
                    final isCompleted = status == 'completed';
                    final isWithin24h =
                        DateTime.now().difference(createdAt).inHours < 24;

                    // Karşı tarafın ID'si
                    final isPassenger =
                        ride['passenger_id'] == user.uid;
                    final otherPartyId = isPassenger
                        ? ride['driver_id'] as String?
                        : ride['passenger_id'] as String?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.outline.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chipBg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon,
                                          size: 13, color: chipColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        _translateStatus(status),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: chipColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _LocationRow(
                              icon: Icons.my_location_rounded,
                              color: cs.primary,
                              label: pickupStr,
                            ),
                            const SizedBox(height: 6),
                            _LocationRow(
                              icon: Icons.location_on_rounded,
                              color: Colors.red,
                              label: destStr,
                            ),
                            if (price != null) ...[
                              const SizedBox(height: 6),
                              _LocationRow(
                                icon: Icons.payments_outlined,
                                color: Colors.green.shade700,
                                label: '₺${price.toStringAsFixed(0)}',
                              ),
                            ],
                            if (isCompleted && isWithin24h && otherPartyId != null) ...[
                              const SizedBox(height: 12),
                              Divider(
                                  height: 1,
                                  color: cs.outline.withValues(alpha: 0.15)),
                              const SizedBox(height: 12),
                              RateRideButton(
                                reservationId: rides[index].id,
                                ratedUid: otherPartyId,
                                ratedUserName:
                                    isPassenger ? 'Sürücü' : 'Yolcu',
                                ratedByPassenger: isPassenger,
                                dbService: dbService,
                              ),
                              const SizedBox(height: 8),
                              _LostItemButton(
                                otherPartyId: otherPartyId,
                                dbService: dbService,
                                isPassenger: isPassenger,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// ── Unutulan Eşya Butonu ─────────────────────────────────────────────────────
class _LostItemButton extends StatefulWidget {
  const _LostItemButton({
    required this.otherPartyId,
    required this.dbService,
    required this.isPassenger,
  });
  final String otherPartyId;
  final DatabaseService dbService;
  final bool isPassenger;

  @override
  State<_LostItemButton> createState() => _LostItemButtonState();
}

class _LostItemButtonState extends State<_LostItemButton> {
  bool _loading = false;

  Future<void> _call() async {
    setState(() => _loading = true);
    try {
      final data =
          await widget.dbService.getUserData(widget.otherPartyId);
      final phone = data?['phone'] as String?;
      if (phone != null && phone.isNotEmpty) {
        final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
        final uri = Uri.parse('tel:$cleaned');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.isPassenger
                  ? 'Sürücünün telefon numarası bulunamadı.'
                  : 'Yolcunun telefon numarası bulunamadı.'),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bir hata oluştu.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isPassenger ? 'Sürücüyü Ara' : 'Yolcuyu Ara';
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _call,
        icon: _loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.phone_in_talk_rounded, size: 16),
        label: Text('Unutulan Eşya — $label'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange.shade700,
          side: BorderSide(color: Colors.orange.shade300),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

String _translateStatus(String status) {
  switch (status) {
    case 'completed':
      return 'TAMAMLANDI';
    case 'cancelled':
      return 'İPTAL EDİLDİ';
    case 'on_route':
      return 'YOLDAKİ';
    case 'accepted':
      return 'KABUL EDİLDİ';
    default:
      return status.toUpperCase();
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}
