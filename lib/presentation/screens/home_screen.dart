import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/core/database_service.dart';
import 'package:myapp/core/location_service.dart';
import 'package:myapp/main.dart';
import 'package:myapp/presentation/screens/profile_screen.dart';
import 'package:provider/provider.dart' as old_provider;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

enum RideState {
  idle,
  selectingDestination,
  confirming,
  requested,
  driverAssigned,
  onRoute,
  rideCompleted,
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<QuerySnapshot>? _driversStreamSubscription;
  StreamSubscription<QuerySnapshot>? _createdReservationsSubscription;
  StreamSubscription<DocumentSnapshot>? _currentReservationSubscription;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  RideState _rideState = RideState.idle;
  bool _isDriverMode = false;

  LatLng? _userLocation;
  LatLng? _destinationLocation;
  DocumentSnapshot? _currentReservationData;
  String? _currentReservationId;
  String? _assignedDriverId;

  List<QueryDocumentSnapshot> _availableRides = [];
  List<dynamic> _placePredictions = [];
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _sessionToken = const Uuid().v4();

  final String _googleApiKey = 'AIzaSyCJcoCqw2DM9_AOItOVApX71lsPwLzXmbQ';

  @override
  void initState() {
    super.initState();
    _initializeLocationAndListeners();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _getPlacePredictions(_searchController.text);
      }
    });
  }

  Future<void> _getPlacePredictions(String input) async {
    final requestUrl =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_googleApiKey&sessiontoken=$_sessionToken';
    final response = await http.get(Uri.parse(requestUrl));

    if (response.statusCode == 200) {
      if (!mounted) return;
      setState(() {
        _placePredictions = json.decode(response.body)['predictions'];
      });
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
    final requestUrl =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleApiKey&sessiontoken=$_sessionToken';
    final response = await http.get(Uri.parse(requestUrl));

    if (response.statusCode == 200) {
      final result =
          json.decode(response.body)['result'] as Map<String, dynamic>;
      final location = result['geometry']['location'];
      final lat = location['lat'];
      final lng = location['lng'];

      if (!mounted) return;
      setState(() {
        _destinationLocation = LatLng(lat, lng);
        _rideState = RideState.confirming;
        _addDestinationMarker(_destinationLocation!);
        _animateCameraToPosition(_destinationLocation!);
        _placePredictions = [];
        _searchController.clear();
        _sessionToken = const Uuid().v4();
      });
    }
  }

  void _initializeLocationAndListeners() async {
    await _goToCurrentUserLocation();
    _listenToDrivers();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRole = await ref
          .read(databaseServiceProvider)
          .getUserRole(user.uid);
      if (userRole == UserRole.driver) {
        _listenToCreatedReservations();
      }
    }
  }

  Future<void> _goToCurrentUserLocation() async {
    try {
      final position = await ref
          .read(locationServiceProvider)
          .getCurrentLocation();
      _userLocation = LatLng(position.latitude, position.longitude);
      _animateCameraToPosition(_userLocation!);
      _addUserMarker(_userLocation!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to get location: $e")));
    }
  }

  void _listenToDrivers() {
    final dbService = ref.read(databaseServiceProvider);
    _driversStreamSubscription = dbService.getDriversStream().listen((
      snapshot,
    ) {
      _updateDriverMarkers(snapshot.docs);
    });
  }

  void _listenToCreatedReservations() {
    final dbService = ref.read(databaseServiceProvider);
    _createdReservationsSubscription = dbService
        .getCreatedReservationsStream()
        .listen((snapshot) {
          if (_rideState == RideState.idle && _isDriverMode) {
            if (!mounted) return;
            setState(() {
              _availableRides = snapshot.docs;
            });
          }
        });
  }

  void _listenToCurrentReservation() {
    if (_currentReservationId == null) return;

    _currentReservationSubscription?.cancel();
    final dbService = ref.read(databaseServiceProvider);
    _currentReservationSubscription = dbService
        .getReservationStream(_currentReservationId!)
        .listen((snapshot) async {
          if (!mounted) return;
          if (!snapshot.exists) {
            _resetRideState();
            return;
          }

          _currentReservationData = snapshot;
          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'] as String;

          switch (status) {
            case 'accepted':
              setState(() {
                _assignedDriverId = data['driver_id'];
                _rideState = RideState.driverAssigned;
                _polylines.clear();
                _markers.removeWhere(
                  (m) => m.markerId.value == 'destination_marker',
                );
              });
              break;
            case 'on_route':
              final pickup = data['pickup_location'] as GeoPoint;
              final destination = data['destination_location'] as GeoPoint;
              await _createRoute(
                LatLng(pickup.latitude, pickup.longitude),
                LatLng(destination.latitude, destination.longitude),
              );
              if (!mounted) return;
              setState(() {
                _rideState = RideState.onRoute;
              });
              break;
            case 'completed':
            case 'cancelled':
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Ride has been $status.")));
              _resetRideState();
              break;
          }
        });
  }

  void _updateDriverMarkers(List<QueryDocumentSnapshot> docs) {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    final driverMarkers = docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final geoPoint = data['position'] as GeoPoint;
          final driverId = doc.id;

          if (driverId == user?.uid) return null;

          if ((_rideState == RideState.driverAssigned ||
                  _rideState == RideState.onRoute) &&
              driverId != _assignedDriverId) {
            return null;
          }

          return Marker(
            markerId: MarkerId(driverId),
            position: LatLng(geoPoint.latitude, geoPoint.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: const InfoWindow(title: 'Driver'),
          );
        })
        .whereType<Marker>()
        .toSet();

    setState(() {
      _markers.removeWhere(
        (marker) =>
            marker.markerId.value != 'user_location' &&
            marker.markerId.value != 'destination_marker',
      );
      _markers.addAll(driverMarkers);
    });
  }

  void _addUserMarker(LatLng position) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'user_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: position,
          icon: BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(title: 'My Location'),
        ),
      );
    });
  }

  void _addDestinationMarker(LatLng position) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'destination_marker');
      _markers.add(
        Marker(
          markerId: const MarkerId('destination_marker'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    });
  }

  Future<void> _createRoute(LatLng start, LatLng end) async {
    _polylines.clear();
    PolylinePoints polylinePoints = PolylinePoints(apiKey: _googleApiKey);

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(start.latitude, start.longitude),
        destination: PointLatLng(end.latitude, end.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        points: result.points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList(),
        color: Colors.blue,
        width: 5,
      );
      if (!mounted) return;
      setState(() {
        _polylines.add(polyline);
      });
    }
  }

  void _animateCameraToPosition(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 14.5),
      ),
    );
  }

  void _toggleDriverMode(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final role = await ref.read(databaseServiceProvider).getUserRole(user.uid);
    if (!mounted) return;

    if (role == UserRole.passenger) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Only drivers can enable driver mode.")),
      );
      return;
    }

    setState(() {
      _isDriverMode = value;
    });

    if (_isDriverMode) {
      _startSharingLocation();
      _listenToCreatedReservations();
    } else {
      _stopSharingLocation();
      _createdReservationsSubscription?.cancel();
      if (!mounted) return;
      setState(() {
        _availableRides = [];
      });
    }
  }

  void _startSharingLocation() {
    final dbService = ref.read(databaseServiceProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) {
          if (!mounted) return;
          _userLocation = LatLng(position.latitude, position.longitude);
          dbService.updateDriverLocation(
            user.uid,
            GeoPoint(position.latitude, position.longitude),
          );
          _addUserMarker(_userLocation!);
        });
  }

  void _stopSharingLocation() {
    _positionStreamSubscription?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      ref.read(databaseServiceProvider).removeDriverLocation(user.uid);
    }
  }

  void _resetRideState() {
    if (!mounted) return;
    setState(() {
      _rideState = RideState.idle;
      _polylines.clear();
      _markers.removeWhere((m) => m.markerId.value == 'destination_marker');
      _currentReservationId = null;
      _assignedDriverId = null;
      _currentReservationData = null;
      _placePredictions = [];
      _searchController.clear();
    });
    _currentReservationSubscription?.cancel();
    if (_isDriverMode) _listenToCreatedReservations();
  }

  Future<void> _launchNavigation() async {
    if (_currentReservationData == null) return;
    final data = _currentReservationData!.data() as Map<String, dynamic>;
    final pickupLocation = data['pickup_location'] as GeoPoint;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${pickupLocation.latitude},${pickupLocation.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch navigation.')),
      );
    }
  }

  Widget _buildBottomWidget() {
    if (_isDriverMode) {
      if (_rideState == RideState.idle && _availableRides.isNotEmpty) {
        return _buildAvailableRidesPanel();
      }
      if (_rideState == RideState.driverAssigned) {
        return _buildDriverActionPanel("Pick up Passenger", () {
          ref
              .read(databaseServiceProvider)
              .updateReservationStatus(_currentReservationId!, 'on_route');
        }, onNavigate: _launchNavigation);
      }
      if (_rideState == RideState.onRoute) {
        return _buildDriverActionPanel("Complete Ride", () {
          ref
              .read(databaseServiceProvider)
              .updateReservationStatus(_currentReservationId!, 'completed');
        });
      }
      return const SizedBox.shrink();
    }

    switch (_rideState) {
      case RideState.idle:
        return _buildPassengerActionPanel(
          "Where to?",
          () => setState(() => _rideState = RideState.selectingDestination),
        );
      case RideState.selectingDestination:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchCard(),
            if (_placePredictions.isNotEmpty) _buildPredictionsList(),
          ],
        );
      case RideState.confirming:
        return _buildConfirmationPanel();
      case RideState.requested:
        return _buildLoadingPanel(
          "Finding a driver...",
          onCancel: () async {
            if (_currentReservationId != null) {
              await ref
                  .read(databaseServiceProvider)
                  .cancelReservation(_currentReservationId!);
            }
            _resetRideState();
          },
        );
      case RideState.driverAssigned:
        return _buildLoadingPanel("Driver is on the way!");
      case RideState.onRoute:
        return _buildLoadingPanel("Enjoy your ride!");
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSearchCard() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Enter destination",
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                if (!mounted) return;
                setState(() {
                  _placePredictions = [];
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionsList() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _placePredictions.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_placePredictions[index]['description']),
            onTap: () => _getPlaceDetails(_placePredictions[index]['place_id']),
          );
        },
      ),
    );
  }

  Widget _buildAvailableRidesPanel() {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.1,
      maxChildSize: 0.5,
      builder: (context, scrollController) {
        return Card(
          margin: EdgeInsets.zero,
          child: ListView.builder(
            controller: scrollController,
            itemCount: _availableRides.length,
            itemBuilder: (context, index) {
              final ride = _availableRides[index];
              final data = ride.data() as Map<String, dynamic>;
              final pickup = data['pickup_location'] as GeoPoint;
              final distance = _userLocation != null
                  ? Geolocator.distanceBetween(
                          _userLocation!.latitude,
                          _userLocation!.longitude,
                          pickup.latitude,
                          pickup.longitude,
                        ) /
                        1000
                  : 0.0;

              return ListTile(
                title: const Text('New Ride Request'),
                subtitle: Text(
                  'Pickup is ${distance.toStringAsFixed(1)} km away',
                ),
                trailing: ElevatedButton(
                  child: const Text('Accept'),
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      final success = await ref
                          .read(databaseServiceProvider)
                          .acceptReservation(ride.id, user.uid);
                      if (!mounted) return;
                      if (success) {
                        setState(() {
                          _currentReservationId = ride.id;
                          _availableRides = [];
                        });
                        _createdReservationsSubscription?.cancel();
                        _listenToCurrentReservation();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Ride was already taken."),
                          ),
                        );
                      }
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDriverActionPanel(
    String text,
    VoidCallback onPressed, {
    VoidCallback? onNavigate,
  }) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: onPressed, child: Text(text)),
            ),
            if (onNavigate != null)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation),
                  label: const Text("Start Navigation"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerActionPanel(String text, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(onPressed: onPressed, child: Text(text)),
      ),
    );
  }

  Widget _buildConfirmationPanel() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Confirm your ride",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("Ready to request?"),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child: const Text("Request Ride"),
                onPressed: () async {
                  final db = ref.read(databaseServiceProvider);
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null &&
                      _userLocation != null &&
                      _destinationLocation != null) {
                    final hasActive = await db.hasActiveReservation(user.uid);
                    if (!mounted) return;

                    if (hasActive) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "You already have an active ride request.",
                          ),
                        ),
                      );
                      return;
                    }
                    final docRef = await db.createReservation(
                      user.uid,
                      GeoPoint(
                        _userLocation!.latitude,
                        _userLocation!.longitude,
                      ),
                      GeoPoint(
                        _destinationLocation!.latitude,
                        _destinationLocation!.longitude,
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _currentReservationId = docRef.id;
                      _rideState = RideState.requested;
                    });
                    _listenToCurrentReservation();
                  }
                },
              ),
            ),
            TextButton(
              onPressed: () => _resetRideState(),
              child: const Text("Cancel", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPanel(String text, {VoidCallback? onCancel}) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(fontSize: 16)),
            if (onCancel != null)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onCancel,
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _positionStreamSubscription?.cancel();
    _driversStreamSubscription?.cancel();
    _createdReservationsSubscription?.cancel();
    _currentReservationSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    if (_isDriverMode) {
      _stopSharingLocation();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = old_provider.Provider.of<ThemeProvider>(context);

    return PopScope(
      canPop: _rideState == RideState.idle,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cannot exit while in a ride.")),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AeroCab'),
          actions: [
            IconButton(
              icon: Icon(
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              onPressed: () => themeProvider.toggleTheme(),
              tooltip: 'Toggle Theme',
            ),
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () {
                if (_rideState == RideState.idle) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Please complete your ride before viewing your profile.",
                      ),
                    ),
                  );
                }
              },
              tooltip: 'Profile',
            ),
          ],
        ),
        body: Stack(
          children: [
            GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(
                target: _userLocation ?? const LatLng(37.7749, -122.4194),
                zoom: 12,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: true,
              onTap: (latLng) {
                if (_rideState == RideState.selectingDestination) {
                  if (!mounted) return;
                  setState(() {
                    _destinationLocation = latLng;
                    _rideState = RideState.confirming;
                    _addDestinationMarker(latLng);
                  });
                }
              },
            ),
            if (_rideState == RideState.selectingDestination)
              const Center(
                child: Icon(Icons.location_pin, color: Colors.red, size: 50),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SwitchListTile(
                title: const Text('Driver Mode'),
                value: _isDriverMode,
                onChanged: _rideState == RideState.idle
                    ? _toggleDriverMode
                    : null,
                secondary: Icon(_isDriverMode ? Icons.drive_eta : Icons.person),
                tileColor: Theme.of(context).colorScheme.surface.withAlpha(204),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomWidget(),
            ),
          ],
        ),
      ),
    );
  }
}
