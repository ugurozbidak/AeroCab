import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:aerocab/core/alert_service.dart';
import 'package:aerocab/core/booking_models.dart';
import 'package:aerocab/core/database_service.dart';
import 'package:aerocab/features/subscription/screens/subscription_paywall_screen.dart';
import 'package:aerocab/presentation/screens/map_picker_screen.dart';
import 'package:aerocab/presentation/widgets/rating_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

enum _RideState { idle, requested, driverAssigned, headingToPickup, onRoute }

class PassengerBookingScreen extends ConsumerStatefulWidget {
  const PassengerBookingScreen({super.key});

  @override
  ConsumerState<PassengerBookingScreen> createState() =>
      _PassengerBookingScreenState();
}

class _PassengerBookingScreenState
    extends ConsumerState<PassengerBookingScreen> {
  // ── Yolculuk seçenekleri ────────────────────────────────────────────────
  RideType _rideType = RideType.homeToTerminal;
  PassengerCount _passengerCount = PassengerCount.one;

  // ── Kullanıcının seçtiği konum (terminal olmayan uç) ────────────────────
  LatLng? _userLatLng;
  String _userAddress = 'Konum alınıyor...';

  // ── Terminalden Eve + 2 kişi için 2. varış noktası ──────────────────────
  LatLng? _dest2LatLng;
  String _dest2Address = '';

  // ── Fiyatlandırma ────────────────────────────────────────────────────────
  PricingPoint? _detectedZone;

  // ── Kayıtlı adresler ─────────────────────────────────────────────────────
  List<SavedAddress> _savedAddresses = [];

  // ── Saat seçimi ──────────────────────────────────────────────────────────
  DateTime? _scheduledTime;
  bool _slotIsToday = true;

  List<DateTime> _generateSlots(bool today) {
    final now = DateTime.now();
    final DateTime start;
    if (today) {
      final earliest = now.add(const Duration(minutes: 90));
      final extra15 = (earliest.minute % 15 == 0)
          ? 0
          : 15 - (earliest.minute % 15);
      final rounded = earliest.add(Duration(minutes: extra15));
      start = DateTime(
          rounded.year, rounded.month, rounded.day, rounded.hour, rounded.minute);
    } else {
      final tomorrow = now.add(const Duration(days: 1));
      start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0);
    }
    final end = DateTime(start.year, start.month, start.day, 23, 45);
    final slots = <DateTime>[];
    var cur = start;
    while (!cur.isAfter(end)) {
      slots.add(cur);
      cur = cur.add(const Duration(minutes: 15));
    }
    return slots;
  }

  // ── Yolculuk durumu ──────────────────────────────────────────────────────
  _RideState _rideState = _RideState.idle;
  String? _reservationId;
  StreamSubscription<DocumentSnapshot>? _reservationSub;
  String? _driverId;
  String? _driverName;
  String? _driverPhone;
  String? _driverPhotoUrl;
  double? _driverAvgRating;
  int? _driverRatingCount;

  // ── Computed ─────────────────────────────────────────────────────────────
  double? get _currentPrice =>
      _detectedZone != null ? getPrice(_detectedZone!, _passengerCount) : null;

  // getPrice artık double döndürüyor, null gelmez — yukarıdaki null check yeterli

  bool get _canRequest {
    if (_userLatLng == null) return false;
    if (_scheduledTime == null) return false;
    if (_rideType == RideType.terminalToHome &&
        _passengerCount == PassengerCount.two &&
        _dest2LatLng == null) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadSavedAddresses();
    _checkActiveReservation();
  }

  @override
  void dispose() {
    _reservationSub?.cancel();
    super.dispose();
  }

  // ── Aktif yolculuğu geri yükle ───────────────────────────────────────────
  Future<void> _checkActiveReservation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await ref
        .read(databaseServiceProvider)
        .getActiveReservationForPassenger(user.uid);
    if (doc == null || !mounted) return;
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String;
    final rideState = switch (status) {
      'accepted' || 'heading_to_pickup' => _RideState.driverAssigned,
      'on_route' => _RideState.onRoute,
      _ => _RideState.requested,
    };
    setState(() {
      _reservationId = doc.id;
      _rideState = rideState;
    });
    final driverId = data['driver_id'] as String?;
    if (driverId != null) _fetchDriverInfo(driverId);
    _listenToReservation(doc.id);
  }

  // ── Mevcut konumu al ──────────────────────────────────────────────────────
  Future<void> _initLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _userAddress = 'Konum izni gerekli');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Konum izni reddedildi. Lütfen Ayarlar\'dan konum iznini açın veya haritadan manuel konum seçin.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      final address = await _reverseGeocode(latLng);
      if (mounted) {
        setState(() {
          _userLatLng = latLng;
          _userAddress = address ?? 'Mevcut Konum';
          _detectedZone = detectNearestZone(latLng);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _userAddress = 'Mevcut Konum');
    }
  }

  Future<String?> _reverseGeocode(LatLng pos) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${pos.latitude}&lon=${pos.longitude}&format=json',
      );
      final res = await http.get(url, headers: {
        'Accept-Language': 'tr',
        'User-Agent': 'AeroCabApp/1.0',
      });
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final display = data['display_name'] as String?;
        return display;
      }
    } catch (_) {}
    return null;
  }

  // ── Kayıtlı adresler ──────────────────────────────────────────────────────
  Future<void> _loadSavedAddresses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final addresses =
        await ref.read(databaseServiceProvider).getSavedAddresses(user.uid);
    if (mounted) setState(() => _savedAddresses = addresses);
  }

  void _selectSavedAddress(SavedAddress addr) {
    setState(() {
      _userLatLng = addr.location;
      _userAddress = addr.address;
      _detectedZone = detectNearestZone(addr.location);
    });
  }

  Future<void> _addOrEditSavedAddress({String? presetName}) async {
    final mapResult = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialPosition: _userLatLng,
          title: 'Adres Seç',
        ),
      ),
    );
    if (mapResult == null || !mounted) return;

    final nameController = TextEditingController(text: presetName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adres İsmi'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ev, İş, Spor Salonu...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.isEmpty || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await ref.read(databaseServiceProvider).saveAddress(
      user.uid,
      name,
      mapResult.address,
      GeoPoint(mapResult.location.latitude, mapResult.location.longitude),
    );

    await _loadSavedAddresses();
    if (mounted) {
      setState(() {
        _userLatLng = mapResult.location;
        _userAddress = mapResult.address;
        _detectedZone = detectNearestZone(mapResult.location);
      });
    }
  }

  Future<void> _confirmDeleteAddress(SavedAddress addr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${addr.name}" silinsin mi?'),
        content: const Text('Bu kayıtlı adres kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await ref
          .read(databaseServiceProvider)
          .deleteAddress(user.uid, addr.id);
      _loadSavedAddresses();
    }
  }

  // ── Harita seçici ─────────────────────────────────────────────────────────
  Future<void> _openMapPicker({bool isSecondDest = false}) async {
    final title = isSecondDest
        ? '2. Yolcu Varış Noktasını Seç'
        : (_rideType == RideType.homeToTerminal
            ? 'Alınış Noktasını Seç'
            : 'Varış Noktasını Seç');

    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialPosition: isSecondDest ? _dest2LatLng : _userLatLng,
          title: title,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (isSecondDest) {
          _dest2LatLng = result.location;
          _dest2Address = result.address;
        } else {
          _userLatLng = result.location;
          _userAddress = result.address;
          _detectedZone = detectNearestZone(result.location);
        }
      });
    }
  }

  // ── Yolculuk talep et ─────────────────────────────────────────────────────
  Future<void> _requestRide() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_canRequest) return;

    final db = ref.read(databaseServiceProvider);

    try {
      bool hasSub;
      try {
        hasSub = await db.hasActiveSubscription(user.uid);
      } catch (_) {
        hasSub = false;
      }
      if (!mounted) return;
      if (!hasSub) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SubscriptionPaywallScreen(isDriver: false),
          ),
        );
        return;
      }

      final hasActive = await db.hasActiveReservation(user.uid);
      if (!mounted) return;

      if (hasActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zaten aktif bir yolculuğunuz var.')),
        );
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
      return;
    }

    final userGeo = GeoPoint(_userLatLng!.latitude, _userLatLng!.longitude);
    final terminalGeo =
        GeoPoint(kTerminalLatLng.latitude, kTerminalLatLng.longitude);

    final pickup =
        _rideType == RideType.homeToTerminal ? userGeo : terminalGeo;
    final destination =
        _rideType == RideType.homeToTerminal ? terminalGeo : userGeo;

    GeoPoint? destination2;
    if (_rideType == RideType.terminalToHome &&
        _passengerCount == PassengerCount.two &&
        _dest2LatLng != null) {
      destination2 =
          GeoPoint(_dest2LatLng!.latitude, _dest2LatLng!.longitude);
    }

    try {
      final docRef = await db.createReservation(
        user.uid,
        pickup,
        destination,
        rideType: _rideType,
        passengerCount: _passengerCount,
        scheduledTime: _scheduledTime,
        destination2: destination2,
        price: _currentPrice,
        pricingZone: _detectedZone?.name,
        pickupAddress: _rideType == RideType.homeToTerminal
            ? _userAddress
            : kTerminalAddress,
        destinationAddress: _rideType == RideType.homeToTerminal
            ? kTerminalAddress
            : _userAddress,
        destination2Address: _dest2Address.isNotEmpty ? _dest2Address : null,
      );

      if (!mounted) return;
      setState(() {
        _reservationId = docRef.id;
        _rideState = _RideState.requested;
      });
      _listenToReservation(docRef.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yolculuk oluşturulamadı: $e')),
        );
      }
    }
  }

  Future<void> _fetchDriverInfo(String driverId) async {
    if (mounted) setState(() => _driverId = driverId);
    try {
      final db = ref.read(databaseServiceProvider);
      final data = await db.getUserData(driverId);
      final ratingStats = await db.getUserRatingStats(driverId);
      if (data != null && mounted) {
        setState(() {
          _driverName = (data['fullName'] as String?)?.split(' ').first;
          _driverPhone = data['phone'] as String?;
          _driverPhotoUrl = data['photoUrl'] as String?;
          _driverAvgRating = ratingStats != null
              ? (ratingStats['avg'] as double)
              : null;
          _driverRatingCount = ratingStats != null
              ? (ratingStats['count'] as int)
              : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _callDriver() async {
    if (_driverPhone == null || _driverPhone!.isEmpty) return;
    final phone = _driverPhone!.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
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
          final data = snap.data() as Map<String, dynamic>;
          final status = data['status'] as String;
          switch (status) {
            case 'accepted':
              AlertService.showAlert(
                title: 'Sürücü Bulundu!',
                body: 'Sürücünüz yolculuk talebinizi kabul etti.',
              );
              final driverIdAccepted = data['driver_id'] as String?;
              if (driverIdAccepted != null) _fetchDriverInfo(driverIdAccepted);
              if (mounted) setState(() => _rideState = _RideState.driverAssigned);
            case 'heading_to_pickup':
              AlertService.showAlert(
                title: 'Sürücünüz Yola Çıktı!',
                body: 'Sürücünüz alınış noktanıza doğru geliyor.',
              );
              if (mounted) {
                setState(() => _rideState = _RideState.headingToPickup);
                _showReadyDialog();
              }
            case 'on_route':
              AlertService.showAlert(
                title: 'İyi Yolculuklar!',
                body: 'Sürücünüz sizi teslim aldı, yolculuğunuz başladı.',
              );
              if (mounted) setState(() => _rideState = _RideState.onRoute);
            case 'completed':
              // Yolcu sürücüyü değerlendiriyor
              final currentUser = FirebaseAuth.instance.currentUser;
              if (mounted && currentUser != null && _driverId != null) {
                await RatingDialog.show(
                  context,
                  reservationId: _reservationId!,
                  raterUid: currentUser.uid,
                  ratedUid: _driverId!,
                  ratedUserName: _driverName ?? 'Sürücü',
                  ratedByPassenger: true,
                  dbService: ref.read(databaseServiceProvider),
                );
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yolculuğunuz tamamlandı!')),
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

  void _showReadyDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.directions_car_rounded, color: cs.primary, size: 36),
        title: const Text('Sürücünüz Yola Çıktı!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Sürücünüz alınış noktanıza doğru geliyor.\nHazır olun!',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Hazırım!',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRide() async {
    if (_reservationId != null) {
      await ref
          .read(databaseServiceProvider)
          .cancelReservation(_reservationId!);
    }
    _resetRide();
  }

  void _resetRide() {
    _reservationSub?.cancel();
    if (mounted) {
      setState(() {
        _rideState = _RideState.idle;
        _reservationId = null;
        _driverId = null;
        _driverName = null;
        _driverPhone = null;
        _driverPhotoUrl = null;
        _driverAvgRating = null;
        _driverRatingCount = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Yolculuk Bul'),
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
              // ── Aktif yolculuk banner ───────────────────────────────────
              if (_rideState != _RideState.idle) ...[
                if (_rideState != _RideState.requested && _driverName != null)
                  _DriverInfoCard(
                    name: _driverName!,
                    phone: _driverPhone,
                    photoUrl: _driverPhotoUrl,
                    avgRating: _driverAvgRating,
                    ratingCount: _driverRatingCount,
                    onCall: _driverPhone != null && _driverPhone!.isNotEmpty
                        ? _callDriver
                        : null,
                  ),
                if (_rideState != _RideState.requested && _driverName != null)
                  const SizedBox(height: 12),
                _ActiveRideBanner(
                  rideState: _rideState,
                  rideType: _rideType,
                  onCancel:
                      _rideState == _RideState.requested ? _cancelRide : null,
                ),
                const SizedBox(height: 20),
              ],

              if (_rideState == _RideState.idle) ...[
                // ── Yolculuk türü seçici ──────────────────────────────────
                _RideTypeSelector(
                  selected: _rideType,
                  onChanged: (type) => setState(() {
                    _rideType = type;
                    _dest2LatLng = null;
                    _dest2Address = '';
                  }),
                ),
                const SizedBox(height: 20),

                // ── Yolcu sayısı ──────────────────────────────────────────
                Text(
                  'Yolcu Sayısı',
                  style: tt.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 10),
                _PassengerCountSelector(
                  selected: _passengerCount,
                  onChanged: (selection) => setState(() {
                    _passengerCount = selection;
                    if (selection != PassengerCount.two) {
                      _dest2LatLng = null;
                      _dest2Address = '';
                    }
                  }),
                ),

                const SizedBox(height: 20),

                // ── Saat seçimi ───────────────────────────────────────────
                Text(
                  'Yolculuk Saati',
                  style: tt.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 10),
                _TimeSlotSelector(
                  isToday: _slotIsToday,
                  selectedTime: _scheduledTime,
                  generateSlots: _generateSlots,
                  onDayChanged: (isToday) => setState(() {
                    _slotIsToday = isToday;
                    _scheduledTime = null;
                  }),
                  onTimeSelected: (t) => setState(() => _scheduledTime = t),
                ),

                // ── Uyarı: Evden Terminale + 2 kişi ──────────────────────
                if (_rideType == RideType.homeToTerminal &&
                    _passengerCount == PassengerCount.two) ...[
                  const SizedBox(height: 14),
                  _WarningBanner(
                    text:
                        'Rezervasyon saatinize uygun 2. yolcu bulunumazsa tek yolcu üzerinden fiyatlandırma yapılacaktır.',
                  ),
                ],

                const SizedBox(height: 20),

                // ── Nereye gidiyorsunuz ───────────────────────────────────
                Text(
                  'Nereye gidiyorsunuz?',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                // ── Konum kartı ───────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: cs.outline.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      // Nereden satırı
                      _LocationRow(
                        icon: Icons.my_location_rounded,
                        iconColor: cs.primary,
                        label: 'Nereden',
                        value: _rideType == RideType.homeToTerminal
                            ? _userAddress
                            : kTerminalAddress,
                        isLocked: _rideType == RideType.terminalToHome,
                        isPlaceholder: _rideType == RideType.homeToTerminal &&
                            _userLatLng == null,
                        onTap: _rideType == RideType.homeToTerminal
                            ? () => _openMapPicker()
                            : null,
                      ),

                      Divider(
                        height: 1,
                        indent: 52,
                        color: cs.outline.withValues(alpha: 0.15),
                      ),

                      // Nereye satırı
                      _LocationRow(
                        icon: Icons.location_on_rounded,
                        iconColor: Colors.red,
                        label: 'Nereye',
                        value: _rideType == RideType.homeToTerminal
                            ? kTerminalAddress
                            : (_userLatLng != null
                                ? _userAddress
                                : 'Varış noktası seçin'),
                        isLocked: _rideType == RideType.homeToTerminal,
                        isPlaceholder: _rideType == RideType.terminalToHome &&
                            _userLatLng == null,
                        onTap: _rideType == RideType.terminalToHome
                            ? () => _openMapPicker()
                            : null,
                      ),

                      // 2. varış noktası (Terminalden Eve + 2 kişi)
                      if (_rideType == RideType.terminalToHome &&
                          _passengerCount == PassengerCount.two) ...[
                        Divider(
                          height: 1,
                          indent: 52,
                          color: cs.outline.withValues(alpha: 0.15),
                        ),
                        _LocationRow(
                          icon: Icons.location_on_rounded,
                          iconColor: Colors.orange,
                          label: '2. Yolcu Varış Noktası',
                          value: _dest2LatLng != null
                              ? _dest2Address
                              : '2. varış noktası seçin',
                          isPlaceholder: _dest2LatLng == null,
                          onTap: () => _openMapPicker(isSecondDest: true),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Kayıtlı Yerler ────────────────────────────────────────
                Text(
                  'Kayıtlı Yerler',
                  style: tt.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 10),
                _SavedAddressChips(
                  savedAddresses: _savedAddresses,
                  onSelect: _selectSavedAddress,
                  onAddPreset: (name) => _addOrEditSavedAddress(presetName: name),
                  onAddCustom: () => _addOrEditSavedAddress(),
                  onDelete: _confirmDeleteAddress,
                ),

                const SizedBox(height: 24),

                // ── Fiyat kartı ───────────────────────────────────────────
                if (_userLatLng != null) ...[
                  _PriceCard(
                    zone: _detectedZone,
                    price: _currentPrice,
                    passengerCount: _passengerCount,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Yolculuk talep et butonu ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _canRequest ? _requestRide : null,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Yolculuk Talep Et',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

// ── Yolculuk Türü Seçici ────────────────────────────────────────────────────
class _RideTypeSelector extends StatelessWidget {
  const _RideTypeSelector({required this.selected, required this.onChanged});
  final RideType selected;
  final ValueChanged<RideType> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          _TypeTab(
            label: 'Evden Terminale',
            icon: Icons.flight_takeoff_rounded,
            isSelected: selected == RideType.homeToTerminal,
            onTap: () => onChanged(RideType.homeToTerminal),
          ),
          _TypeTab(
            label: 'Terminalden Eve',
            icon: Icons.flight_land_rounded,
            isSelected: selected == RideType.terminalToHome,
            onTap: () => onChanged(RideType.terminalToHome),
          ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? cs.onPrimary
                    : cs.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? cs.onPrimary
                      : cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Yolcu Sayısı Seçici ─────────────────────────────────────────────────────
class _PassengerCountSelector extends StatelessWidget {
  const _PassengerCountSelector({
    required this.selected,
    required this.onChanged,
  });
  final PassengerCount selected;
  final ValueChanged<PassengerCount> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CountChip(
          label: '1 Kişi',
          icon: Icons.person_rounded,
          value: PassengerCount.one,
          selected: selected,
          onTap: () => onChanged(PassengerCount.one),
        ),
        const SizedBox(width: 10),
        _CountChip(
          label: '2 Kişi',
          icon: Icons.people_rounded,
          value: PassengerCount.two,
          selected: selected,
          onTap: () => onChanged(PassengerCount.two),
        ),
        const SizedBox(width: 10),
        _CountChip(
          label: 'Aile',
          icon: Icons.family_restroom_rounded,
          value: PassengerCount.family,
          selected: selected,
          onTap: () => onChanged(PassengerCount.family),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final PassengerCount value;
  final PassengerCount selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primaryContainer
                : cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? cs.primary.withValues(alpha: 0.5)
                  : cs.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Uyarı Banner ────────────────────────────────────────────────────────────
class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Konum Satırı ─────────────────────────────────────────────────────────────
class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.isLocked = false,
    this.isPlaceholder = false,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isLocked;
  final bool isPlaceholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: isLocked ? iconColor.withValues(alpha: 0.4) : iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isPlaceholder
                          ? cs.onSurface.withValues(alpha: 0.35)
                          : isLocked
                              ? cs.onSurface.withValues(alpha: 0.5)
                              : cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isLocked)
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.25),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Fiyat Kartı ──────────────────────────────────────────────────────────────
class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.zone,
    required this.price,
    required this.passengerCount,
  });
  final PricingPoint? zone;
  final double? price;
  final PassengerCount passengerCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final countLabel = switch (passengerCount) {
      PassengerCount.one    => '1 Kişi',
      PassengerCount.two    => '2 Kişi',
      PassengerCount.family => 'Aile',
    };

    if (zone == null || price == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, color: cs.primary, size: 22),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${zone!.name} • $countLabel',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
              Text(
                '₺${price!.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Aktif Yolculuk Banner ─────────────────────────────────────────────────────
class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({
    required this.rideState,
    required this.rideType,
    this.onCancel,
  });
  final _RideState rideState;
  final RideType rideType;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (String title, String subtitle, Color color) = switch (rideState) {
      _RideState.requested => (
          'Sürücü aranıyor...',
          'Sürücü bulunurken lütfen bekleyin',
          cs.primary,
        ),
      _RideState.driverAssigned => (
          'Sürücünüz kabul etti',
          'Sürücünüz yolculuğu kabul etti',
          Colors.orange,
        ),
      _RideState.headingToPickup => (
          'Sürücünüz geliyor!',
          'Alınış noktanızda hazır olun',
          Colors.orange,
        ),
      _RideState.onRoute => (
          'İyi yolculuklar!',
          'Varış noktanıza doğru yolculuğunuz başladı',
          Colors.green,
        ),
      _ => ('', '', cs.primary),
    };

    final showAnimation = rideState == _RideState.headingToPickup ||
        rideState == _RideState.onRoute;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          if (showAnimation) ...[
            const SizedBox(height: 14),
            _CarAnimation(
              toPickup: rideState == _RideState.headingToPickup,
              rideType: rideType,
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('İptal Et'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Araba animasyonu ──────────────────────────────────────────────────────────
class _CarAnimation extends StatefulWidget {
  const _CarAnimation({required this.toPickup, required this.rideType});
  // toPickup=true → sürücü alınış noktasına geliyor
  // toPickup=false → yolculuk başladı, varışa gidiliyor
  final bool toPickup;
  final RideType rideType;

  @override
  State<_CarAnimation> createState() => _CarAnimationState();
}

class _CarAnimationState extends State<_CarAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Yolculuk yönüne göre ikonları belirle
    // homeToTerminal: ev → terminal
    // terminalToHome: terminal → ev
    final isHomeToTerminal = widget.rideType == RideType.homeToTerminal;

    final IconData leftIcon;
    final IconData rightIcon;

    if (widget.toPickup) {
      // Sürücü alınış noktasına geliyor
      // Araba sağdan sola gelir → pickup noktası sağda
      leftIcon = Icons.directions_car_rounded; // sürücünün konumu (solda başlar)
      rightIcon = isHomeToTerminal
          ? Icons.home_rounded       // homeToTerminal → pickup = ev
          : Icons.flight_rounded;    // terminalToHome → pickup = terminal
    } else {
      // Yolculuk başladı, varışa gidiliyor
      leftIcon = isHomeToTerminal
          ? Icons.home_rounded       // homeToTerminal → başlangıç = ev
          : Icons.flight_rounded;    // terminalToHome → başlangıç = terminal
      rightIcon = isHomeToTerminal
          ? Icons.flight_rounded     // homeToTerminal → varış = terminal
          : Icons.home_rounded;      // terminalToHome → varış = ev
    }

    return SizedBox(
      height: 48,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          // toPickup: araba sağa doğru ilerler (sola bakan araba ikonu)
          // onRoute: araba sağa doğru ilerler
          final t = _anim.value;
          return Row(
            children: [
              Icon(leftIcon, color: cs.primary, size: 26),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Yol çizgisi
                    Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: cs.outline.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Araba
                    Align(
                      alignment: Alignment(t * 2 - 1, 0),
                      child: Transform.scale(
                        scaleX: widget.toPickup ? -1 : 1,
                        child: Icon(
                          Icons.directions_car_filled_rounded,
                          color: cs.primary,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(rightIcon,
                  color: cs.onSurface.withValues(alpha: 0.5), size: 26),
            ],
          );
        },
      ),
    );
  }
}

// ── Saat Seçici ───────────────────────────────────────────────────────────────
class _TimeSlotSelector extends StatelessWidget {
  const _TimeSlotSelector({
    required this.isToday,
    required this.selectedTime,
    required this.generateSlots,
    required this.onDayChanged,
    required this.onTimeSelected,
  });

  final bool isToday;
  final DateTime? selectedTime;
  final List<DateTime> Function(bool isToday) generateSlots;
  final ValueChanged<bool> onDayChanged;
  final ValueChanged<DateTime> onTimeSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final slots = generateSlots(isToday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bugün / Yarın seçici
        Row(
          children: [
            _DayChip(
              label: 'Bugün',
              selected: isToday,
              onTap: () => onDayChanged(true),
            ),
            const SizedBox(width: 8),
            _DayChip(
              label: 'Yarın',
              selected: !isToday,
              onTap: () => onDayChanged(false),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Saat slotları
        if (slots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Bugün için uygun saat kalmadı. Lütfen yarını seçin.',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: slots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final slot = slots[i];
                final selected = selectedTime != null &&
                    selectedTime!.hour == slot.hour &&
                    selectedTime!.minute == slot.minute &&
                    selectedTime!.day == slot.day;
                final label =
                    '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
                return GestureDetector(
                  onTap: () => onTimeSelected(slot),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.primary
                          : cs.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? cs.primary
                            : cs.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : cs.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        if (selectedTime != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade600, size: 16),
              const SizedBox(width: 6),
              Text(
                '${isToday ? 'Bugün' : 'Yarın'} saat ${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')} seçildi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ── Kayıtlı Adresler Chip Satırı ─────────────────────────────────────────────
class _SavedAddressChips extends StatelessWidget {
  const _SavedAddressChips({
    required this.savedAddresses,
    required this.onSelect,
    required this.onAddPreset,
    required this.onAddCustom,
    required this.onDelete,
  });

  final List<SavedAddress> savedAddresses;
  final ValueChanged<SavedAddress> onSelect;
  final ValueChanged<String> onAddPreset;
  final VoidCallback onAddCustom;
  final ValueChanged<SavedAddress> onDelete;

  static const _presetSlots = [
    ('Ev', Icons.home_rounded),
    ('İş', Icons.work_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    // Ev ve İş slotları
    for (final (name, icon) in _presetSlots) {
      final saved = savedAddresses.where((a) => a.name == name).firstOrNull;
      if (saved != null) {
        chips.add(_PlaceChip(
          icon: icon,
          label: name,
          onTap: () => onSelect(saved),
          onLongPress: () => onDelete(saved),
        ));
      } else {
        chips.add(_PlaceChip(
          icon: icon,
          label: name,
          isEmpty: true,
          onTap: () => onAddPreset(name),
        ));
      }
    }

    // Özel kayıtlı adresler
    for (final addr in savedAddresses.where(
      (a) => !_presetSlots.map((s) => s.$1).contains(a.name),
    )) {
      chips.add(_PlaceChip(
        icon: Icons.bookmark_rounded,
        label: addr.name,
        onTap: () => onSelect(addr),
        onLongPress: () => onDelete(addr),
      ));
    }

    // Ekle butonu
    chips.add(_PlaceChip(
      icon: Icons.add_rounded,
      label: 'Ekle',
      onTap: onAddCustom,
    ));

    return Wrap(spacing: 10, runSpacing: 8, children: chips);
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isEmpty = false,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isEmpty;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isEmpty
              ? cs.surfaceContainerHighest.withValues(alpha: 0.25)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEmpty
                ? cs.outline.withValues(alpha: 0.1)
                : cs.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isEmpty
                  ? cs.onSurface.withValues(alpha: 0.3)
                  : cs.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isEmpty
                    ? cs.onSurface.withValues(alpha: 0.35)
                    : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sürücü Bilgi Kartı ─────────────────────────────────────────────────────────
class _DriverInfoCard extends StatelessWidget {
  const _DriverInfoCard({
    required this.name,
    this.phone,
    this.photoUrl,
    this.avgRating,
    this.ratingCount,
    this.onCall,
  });
  final String name;
  final String? phone;
  final String? photoUrl;
  final double? avgRating;
  final int? ratingCount;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: cs.primaryContainer,
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? Text(
                    initials,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sürücünüz',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (avgRating != null && ratingCount != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '${avgRating!.toStringAsFixed(1)} · $ratingCount değerlendirme',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
                if (phone != null && phone!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    phone!,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton.filled(
            onPressed: onCall,
            icon: const Icon(Icons.phone_rounded),
            style: IconButton.styleFrom(
              backgroundColor: onCall != null ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
