import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:aerocab/core/alert_service.dart';
import 'package:aerocab/core/database_service.dart';
import 'package:aerocab/features/subscription/screens/subscription_paywall_screen.dart';
import 'package:aerocab/presentation/widgets/rating_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

enum _DriverRideState { idle, assigned, headingToPickup, onRoute }

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState
    extends ConsumerState<DriverDashboardScreen> {
  bool _isOnline = false;
  _DriverRideState _rideState = _DriverRideState.idle;

  StreamSubscription<Position>? _locationSub;
  StreamSubscription<QuerySnapshot>? _ridesSub;
  StreamSubscription<DocumentSnapshot>? _reservationSub;

  List<QueryDocumentSnapshot> _availableRides = [];
  String? _reservationId;
  String? _alertRideId; // Şu an alert ekranında gösterilen ride ID'si
  DocumentSnapshot? _reservationData;
  LatLng? _myLocation;
  String? _passengerId;
  String? _passengerName;
  String? _passengerPhone;

  @override
  void initState() {
    super.initState();
    _checkActiveReservation();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNotificationArgs());
  }

  void _checkNotificationArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['reservationId'] != null) {
      _openRideAlertFromNotification(args['reservationId'] as String);
    }
  }

  Future<void> _openRideAlertFromNotification(String reservationId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] != 'created') return;

      final pickup = data['pickup_location'] as GeoPoint;
      final pickupAddr = data['pickup_address'] as String? ??
          '${pickup.latitude.toStringAsFixed(4)}, ${pickup.longitude.toStringAsFixed(4)}';
      final destAddr = data['destination_address'] as String? ?? '';
      final price = data['price'] as num?;
      final passengerId = data['passenger_id'] as String?;
      final scheduledTs = data['scheduled_time'] as Timestamp?;
      final distance = _myLocation != null
          ? Geolocator.distanceBetween(_myLocation!.latitude, _myLocation!.longitude,
                  pickup.latitude, pickup.longitude) /
              1000
          : null;

      if (!mounted) return;
      _alertRideId = reservationId;
      final accepted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _RideAlertScreen(
            pickupAddr: pickupAddr,
            destAddr: destAddr,
            price: price,
            distance: distance,
            passengerId: passengerId,
            scheduledTime: scheduledTs?.toDate(),
            dbService: ref.read(databaseServiceProvider),
          ),
        ),
      );
      _alertRideId = null;
      if (accepted == true && mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final success = await ref
            .read(databaseServiceProvider)
            .acceptReservation(reservationId, user.uid);
        if (!mounted) return;
        if (success) {
          _ridesSub?.cancel();
          setState(() {
            _reservationId = reservationId;
            _rideState = _DriverRideState.assigned;
            _availableRides = [];
          });
          if (passengerId != null) await _fetchPassengerInfo(passengerId);
          _listenToReservation(reservationId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu yolculuk zaten alındı.')),
          );
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _ridesSub?.cancel();
    _reservationSub?.cancel();
    if (_isOnline) _goOffline();
    super.dispose();
  }

  Future<void> _checkActiveReservation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await ref
        .read(databaseServiceProvider)
        .getActiveReservationForDriver(user.uid);
    if (doc == null || !mounted) return;
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String;
    final passengerId = data['passenger_id'] as String?;
    setState(() {
      _isOnline = true;
      _reservationId = doc.id;
      _reservationData = doc;
      _rideState = switch (status) {
        'on_route' => _DriverRideState.onRoute,
        'heading_to_pickup' => _DriverRideState.headingToPickup,
        _ => _DriverRideState.assigned,
      };
    });
    if (passengerId != null) await _fetchPassengerInfo(passengerId);
    _listenToReservation(doc.id);
  }

  Future<void> _fetchPassengerInfo(String passengerId) async {
    if (mounted) setState(() => _passengerId = passengerId);
    try {
      final data =
          await ref.read(databaseServiceProvider).getUserData(passengerId);
      if (data != null && mounted) {
        setState(() {
          _passengerName = (data['fullName'] as String?)?.split(' ').first;
          _passengerPhone = data['phone'] as String?;
        });
      }
    } catch (_) {
      // Firestore rules may restrict cross-user reads — show defaults
    }
  }

  Future<void> _toggleOnline() async {
    if (_isOnline) {
      await _goOffline();
    } else {
      await _goOnline();
    }
  }

  Future<void> _goOnline() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final hasSub = await ref
        .read(databaseServiceProvider)
        .hasActiveSubscription(user.uid);
    if (!mounted) return;

    if (!hasSub) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SubscriptionPaywallScreen(isDriver: true),
        ),
      );
      return;
    }

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      setState(() => _isOnline = true);
      _startLocationSharing();
      _listenToRides();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konum hatası: $e')),
        );
      }
    }
  }

  Future<void> _goOffline() async {
    _locationSub?.cancel();
    _ridesSub?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await ref.read(databaseServiceProvider).removeDriverLocation(user.uid);
    }
    if (mounted) {
      setState(() {
        _isOnline = false;
        _availableRides = [];
      });
    }
  }

  void _startLocationSharing() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      _myLocation = LatLng(pos.latitude, pos.longitude);
      ref.read(databaseServiceProvider).updateDriverLocation(
        user.uid,
        GeoPoint(pos.latitude, pos.longitude),
      );
    });
  }

  bool _prevRidesEmpty = true;

  void _listenToRides() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _ridesSub = ref
        .read(databaseServiceProvider)
        .getCreatedReservationsStream(user.uid)
        .listen((snap) {
          if (!mounted || _rideState != _DriverRideState.idle) return;
          final rides = snap.docs;

          // Alert ekranında gösterilen ride iptal/alındıysa ekranı kapat
          if (_alertRideId != null) {
            final stillExists = rides.any((r) => r.id == _alertRideId);
            if (!stillExists) {
              _alertRideId = null;
              Navigator.of(context).pop(false);
            }
          }

          final wasEmpty = _prevRidesEmpty;
          _prevRidesEmpty = rides.isEmpty;
          setState(() => _availableRides = rides);

          // New ride alert: transition from empty to non-empty
          if (wasEmpty && rides.isNotEmpty && _alertRideId == null) {
            _showNewRideAlert(rides.first);
          }
        });
  }

  void _showNewRideAlert(QueryDocumentSnapshot ride) {
    AlertService.showAlert(
      title: 'Yeni Yolculuk Talebi',
      body: 'Yakınınızda bir yolculuk talebi var!',
    );
    if (!mounted) return;

    final data = ride.data() as Map<String, dynamic>;
    final pickup = data['pickup_location'] as GeoPoint;
    final pickupAddr = data['pickup_address'] as String? ??
        '${pickup.latitude.toStringAsFixed(4)}, ${pickup.longitude.toStringAsFixed(4)}';
    final destAddr = data['destination_address'] as String? ?? '';
    final price = data['price'] as num?;
    final passengerId = data['passenger_id'] as String?;
    final scheduledTs = data['scheduled_time'] as Timestamp?;
    final scheduledTime = scheduledTs?.toDate();
    final distance = _myLocation != null
        ? Geolocator.distanceBetween(_myLocation!.latitude, _myLocation!.longitude,
                pickup.latitude, pickup.longitude) /
            1000
        : null;

    _alertRideId = ride.id;

    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _RideAlertScreen(
          pickupAddr: pickupAddr,
          destAddr: destAddr,
          price: price,
          distance: distance,
          passengerId: passengerId,
          scheduledTime: scheduledTime,
          dbService: ref.read(databaseServiceProvider),
        ),
      ),
    ).then((accepted) {
      _alertRideId = null;
      if (accepted == true && mounted) _acceptRide(ride);
    });
  }

  Future<void> _acceptRide(QueryDocumentSnapshot ride) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final success = await ref
        .read(databaseServiceProvider)
        .acceptReservation(ride.id, user.uid);

    if (!mounted) return;

    if (success) {
      _ridesSub?.cancel();
      final data = ride.data() as Map<String, dynamic>;
      final passengerId = data['passenger_id'] as String?;
      setState(() {
        _reservationId = ride.id;
        _rideState = _DriverRideState.assigned;
        _availableRides = [];
        _reservationData = ride;
      });
      if (passengerId != null) await _fetchPassengerInfo(passengerId);
      _listenToReservation(ride.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu yolculuk zaten alındı.')),
      );
    }
  }

  void _listenToReservation(String id) {
    _reservationSub?.cancel();
    _reservationSub = ref
        .read(databaseServiceProvider)
        .getReservationStream(id)
        .listen((snap) async {
          if (!mounted || !snap.exists) {
            _resetRide();
            return;
          }
          _reservationData = snap;
          final data = snap.data() as Map<String, dynamic>;
          final status = data['status'] as String;
          switch (status) {
            case 'heading_to_pickup':
              if (mounted) setState(() => _rideState = _DriverRideState.headingToPickup);
            case 'on_route':
              if (mounted) setState(() => _rideState = _DriverRideState.onRoute);
            case 'completed':
              // Sürücü yolcuyu değerlendiriyor
              final currentUser = FirebaseAuth.instance.currentUser;
              if (mounted && currentUser != null && _passengerId != null) {
                await RatingDialog.show(
                  context,
                  reservationId: id,
                  raterUid: currentUser.uid,
                  ratedUid: _passengerId!,
                  ratedUserName: _passengerName ?? 'Yolcu',
                  ratedByPassenger: false,
                  dbService: ref.read(databaseServiceProvider),
                );
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yolculuk tamamlandı.')),
                );
                _resetRide();
              }
            case 'cancelled':
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yolculuk iptal edildi.')),
                );
                _resetRide();
              }
          }
        });
  }

  void _resetRide() {
    _reservationSub?.cancel();
    if (mounted) {
      setState(() {
        _rideState = _DriverRideState.idle;
        _reservationId = null;
        _reservationData = null;
        _passengerId = null;
        _passengerName = null;
        _passengerPhone = null;
      });
      if (_isOnline) _listenToRides();
    }
  }

  Future<void> _startNavigation() async {
    if (_reservationData == null) return;
    final data = _reservationData!.data() as Map<String, dynamic>;
    // Navigate to destination when on_route, otherwise to pickup
    final GeoPoint target = _rideState == _DriverRideState.onRoute
        ? data['destination_location'] as GeoPoint
        : data['pickup_location'] as GeoPoint;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _callPassenger() async {
    if (_passengerPhone == null || _passengerPhone!.isEmpty) return;
    final phone = _passengerPhone!.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Full screen active ride view
    if (_rideState != _DriverRideState.idle) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: Text(switch (_rideState) {
            _DriverRideState.assigned => 'Yolcu Bekliyor',
            _DriverRideState.headingToPickup => 'Yolcuya Gidiliyor',
            _ => 'Yolculuk Devam Ediyor',
          }),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Passenger info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.person_rounded,
                                color: cs.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _passengerName ?? 'Yolcu',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_passengerPhone != null &&
                              _passengerPhone!.isNotEmpty)
                            IconButton.filled(
                              onPressed: _callPassenger,
                              icon: const Icon(Icons.phone_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      if (_reservationData != null) ...[
                        const SizedBox(height: 14),
                        Divider(
                            height: 1,
                            color: cs.outline.withValues(alpha: 0.15)),
                        const SizedBox(height: 14),
                        _buildRouteInfo(cs),
                      ],
                    ],
                  ),
                ),

                const Spacer(),

                // Status label
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _rideState == _DriverRideState.onRoute
                          ? Colors.green.withValues(alpha: 0.1)
                          : cs.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      switch (_rideState) {
                        _DriverRideState.assigned => 'Alınış noktasına gidin',
                        _DriverRideState.headingToPickup => 'Yolcuyu almaya gidin',
                        _ => 'Varış noktasına gidiliyor',
                      },
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _rideState == _DriverRideState.onRoute
                            ? Colors.green.shade700
                            : cs.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Navigation button (always visible; goes to pickup or destination)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _startNavigation,
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: Text(_rideState == _DriverRideState.onRoute
                        ? 'Varışa Navigate Et'
                        : 'Navigasyonu Başlat'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Main action button (3 steps)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final db = ref.read(databaseServiceProvider);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        if (_rideState == _DriverRideState.assigned) {
                          await db.updateReservationStatus(
                              _reservationId!, 'heading_to_pickup');
                          if (mounted) {
                            setState(() =>
                                _rideState = _DriverRideState.headingToPickup);
                          }
                        } else if (_rideState ==
                            _DriverRideState.headingToPickup) {
                          await db.updateReservationStatus(
                              _reservationId!, 'on_route');
                          if (mounted) {
                            setState(
                                () => _rideState = _DriverRideState.onRoute);
                          }
                        } else {
                          await db.updateReservationStatus(
                              _reservationId!, 'completed');
                        }
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Güncelleme başarısız: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      switch (_rideState) {
                        _DriverRideState.assigned => 'Yola Çıktım',
                        _DriverRideState.headingToPickup => 'Yolcuyu Aldım',
                        _ => 'Yolculuğu Tamamla',
                      },
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    }

    // Normal dashboard view
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Ana Panel'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OnlineToggleCard(
                isOnline: _isOnline,
                onToggle: _rideState == _DriverRideState.idle
                    ? _toggleOnline
                    : null,
              ),

              if (_isOnline &&
                  _rideState == _DriverRideState.idle &&
                  _availableRides.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Mevcut Yolculuklar',
                  style:
                      tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._availableRides.map((ride) {
                  final data = ride.data() as Map<String, dynamic>;
                  final pickup = data['pickup_location'] as GeoPoint;
                  final pickupAddr = data['pickup_address'] as String?;
                  final price = data['price'] as num?;
                  final distance = _myLocation != null
                      ? Geolocator.distanceBetween(
                              _myLocation!.latitude,
                              _myLocation!.longitude,
                              pickup.latitude,
                              pickup.longitude) /
                          1000
                      : null;

                  return _RideRequestCard(
                    distance: distance,
                    pickupAddress: pickupAddr,
                    price: price?.toDouble(),
                    onAccept: () => _acceptRide(ride),
                  );
                }),
              ],

              if (_isOnline &&
                  _rideState == _DriverRideState.idle &&
                  _availableRides.isEmpty) ...[
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 56,
                        color: cs.onSurface.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Yolculuk aranıyor...',
                        style: tt.bodyLarge?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (!_isOnline && _rideState == _DriverRideState.idle) ...[
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 56,
                        color: cs.onSurface.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Çevrimdışısınız',
                        style: tt.bodyLarge?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Yolculuk talebi almak için çevrimiçi olun',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.3),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfo(ColorScheme cs) {
    final data = _reservationData!.data() as Map<String, dynamic>;
    final pickupAddr = data['pickup_address'] as String?;
    final destAddr = data['destination_address'] as String?;
    final scheduledTs = data['scheduled_time'] as Timestamp?;
    final scheduledTime = scheduledTs?.toDate();

    return Column(
      children: [
        if (scheduledTime != null) ...[
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.amber.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Text(
                  _formatScheduledTime(scheduledTime),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (pickupAddr != null)
          _InfoRow(
            icon: Icons.my_location_rounded,
            label: 'Nereden',
            value: pickupAddr,
          ),
        if (destAddr != null) ...[
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.location_on_rounded,
            label: 'Nereye',
            value: destAddr,
          ),
        ],
      ],
    );
  }

  String _formatScheduledTime(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final dayLabel = isToday ? 'Bugün' : 'Yarın';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$dayLabel $h:$m';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.45)),
              ),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnlineToggleCard extends StatelessWidget {
  const _OnlineToggleCard({required this.isOnline, required this.onToggle});
  final bool isOnline;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isOnline ? Colors.green : cs.onSurface.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.green.withValues(alpha: 0.1)
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? Colors.green.withValues(alpha: 0.3)
              : cs.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                Text(
                  isOnline
                      ? 'Yolculuk talepleri alıyorsunuz'
                      : 'Çevrimiçi olmak için dokunun',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnline,
            onChanged: onToggle != null ? (_) => onToggle!() : null,
            activeThumbColor: Colors.green,
            activeTrackColor: Colors.green.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class _RideRequestCard extends StatelessWidget {
  const _RideRequestCard({
    required this.distance,
    required this.onAccept,
    this.pickupAddress,
    this.price,
  });
  final double? distance;
  final VoidCallback onAccept;
  final String? pickupAddress;
  final double? price;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yolculuk Talebi',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (distance != null)
                  Text(
                    '${distance!.toStringAsFixed(1)} km uzaklıkta',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                if (pickupAddress != null)
                  Text(
                    pickupAddress!,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (price != null)
                  Text(
                    '₺${price!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onAccept,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Kabul Et'),
          ),
        ],
      ),
    );
  }
}

// ── Tam ekran yolculuk talebi ekranı ─────────────────────────────────────────
class _RideAlertScreen extends StatefulWidget {
  const _RideAlertScreen({
    required this.pickupAddr,
    required this.destAddr,
    required this.dbService,
    this.price,
    this.distance,
    this.passengerId,
    this.scheduledTime,
  });

  final String pickupAddr;
  final String destAddr;
  final num? price;
  final double? distance;
  final String? passengerId;
  final DateTime? scheduledTime;
  final DatabaseService dbService;

  @override
  State<_RideAlertScreen> createState() => _RideAlertScreenState();
}

class _RideAlertScreenState extends State<_RideAlertScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _ringCtrl;
  Timer? _hapticTimer;
  Timer? _countdownTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    HapticFeedback.heavyImpact();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      HapticFeedback.heavyImpact();
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) Navigator.pop(context, false);
    });

    _playAlert();
  }

  Future<void> _playAlert() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/ride_alert.mp3'));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _hapticTimer?.cancel();
    _countdownTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatScheduledTime(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final dayLabel = isToday ? 'Bugün' : 'Yarın';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$dayLabel $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF12122A);
    const cardBg = Color(0xFF1E1E3A);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Üst bar: Geç + Geri sayım
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    label: const Text('Geç',
                        style: TextStyle(color: Colors.white38, fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _secondsLeft <= 10
                          ? Colors.red.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_secondsLeft sn',
                      style: TextStyle(
                        color: _secondsLeft <= 10 ? Colors.red.shade300 : Colors.white60,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Pulsing icon
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dışa yayılan halka
                    AnimatedBuilder(
                      animation: _ringCtrl,
                      builder: (_, __) => Transform.scale(
                        scale: 1.0 + _ringCtrl.value * 0.6,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.deepPurple.withValues(
                                  alpha: (1.0 - _ringCtrl.value).clamp(0, 1)),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // İç daire
                    Transform.scale(
                      scale: 1.0 + 0.08 * _pulseCtrl.value,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade700,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.directions_car_rounded,
                            color: Colors.white, size: 42),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),
            const Text(
              'YENİ TALEP',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Yolculuk Talebi Geldi!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 28),

            // Bilgi kartları
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (widget.distance != null)
                      _AlertInfoRow(
                        icon: Icons.social_distance_rounded,
                        label: 'Uzaklık',
                        value: '${widget.distance!.toStringAsFixed(1)} km',
                      ),
                    if (widget.distance != null) const SizedBox(height: 14),
                    _AlertInfoRow(
                      icon: Icons.my_location_rounded,
                      label: 'Nereden',
                      value: widget.pickupAddr,
                    ),
                    if (widget.destAddr.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _AlertInfoRow(
                        icon: Icons.location_on_rounded,
                        label: 'Nereye',
                        value: widget.destAddr,
                      ),
                    ],
                    if (widget.scheduledTime != null) ...[
                      const SizedBox(height: 14),
                      _AlertInfoRow(
                        icon: Icons.schedule_rounded,
                        label: 'Yolculuk Saati',
                        value: _formatScheduledTime(widget.scheduledTime!),
                        highlight: true,
                      ),
                    ],
                    if (widget.price != null) ...[
                      const SizedBox(height: 14),
                      _AlertInfoRow(
                        icon: Icons.payments_outlined,
                        label: 'Ücret',
                        value: '₺${widget.price!.toStringAsFixed(0)}',
                        highlight: true,
                      ),
                    ],
                    if (widget.passengerId != null) ...[
                      const SizedBox(height: 14),
                      FutureBuilder<Map<String, dynamic>?>(
                        future: widget.dbService
                            .getUserRatingStats(widget.passengerId!),
                        builder: (ctx, snap) {
                          if (!snap.hasData || snap.data == null) {
                            return const SizedBox.shrink();
                          }
                          return RatingBadge(
                            avg: snap.data!['avg'] as double,
                            count: snap.data!['count'] as int,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Hold-to-accept butonu
            _HoldToAcceptButton(
              onAccepted: () => Navigator.pop(context, true),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

// ── Alert bilgi satırı ────────────────────────────────────────────────────────
class _AlertInfoRow extends StatelessWidget {
  const _AlertInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: highlight ? Colors.amber : Colors.white60, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
              Text(
                value,
                style: TextStyle(
                  color: highlight ? Colors.amber : Colors.white,
                  fontSize: highlight ? 20 : 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Basılı tut butonu ─────────────────────────────────────────────────────────
class _HoldToAcceptButton extends StatefulWidget {
  const _HoldToAcceptButton({required this.onAccepted});
  final VoidCallback onAccepted;

  @override
  State<_HoldToAcceptButton> createState() => _HoldToAcceptButtonState();
}

class _HoldToAcceptButtonState extends State<_HoldToAcceptButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_completed) {
          _completed = true;
          HapticFeedback.heavyImpact();
          widget.onAccepted();
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        _completed = false;
        _ctrl.forward();
        HapticFeedback.mediumImpact();
      },
      onLongPressEnd: (_) {
        if (!_completed) _ctrl.reverse();
      },
      onLongPressCancel: () {
        if (!_completed) _ctrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final progress = _ctrl.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      color: Colors.green.shade400,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: progress > 0
                          ? Colors.green.shade600
                          : Colors.green.shade800,
                      boxShadow: progress > 0
                          ? [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 42),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                progress > 0 ? 'Bırakma...' : 'Kabul etmek için basılı tut',
                style: TextStyle(
                  color:
                      progress > 0 ? Colors.green.shade400 : Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
