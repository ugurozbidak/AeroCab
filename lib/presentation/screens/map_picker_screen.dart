import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapPickerResult {
  const MapPickerResult({required this.location, required this.address});
  final LatLng location;
  final String address;
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({
    super.key,
    this.initialPosition,
    this.title = 'Konum Seç',
  });

  final LatLng? initialPosition;
  final String title;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _defaultPos = LatLng(41.0082, 28.9784);

  GoogleMapController? _mapController;
  LatLng _centerLatLng = _defaultPos;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _predictions = [];
  Timer? _debounce;
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    _centerLatLng = widget.initialPosition ?? _defaultPos;
    _searchController.addListener(_onSearchChanged);
    if (widget.initialPosition != null) {
      _reverseGeocode(widget.initialPosition!);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final text = _searchController.text.trim();
      if (text.isNotEmpty) {
        _getPredictions(text);
      } else {
        setState(() => _predictions = []);
      }
    });
  }

  Future<void> _getPredictions(String input) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(input)}'
      '&format=json&countrycodes=tr&limit=5&addressdetails=0',
    );
    try {
      final res = await http.get(url, headers: {
        'Accept-Language': 'tr',
        'User-Agent': 'AeroCabApp/1.0',
      });
      if (res.statusCode == 200 && mounted) {
        final results = json.decode(res.body) as List? ?? [];
        setState(() => _predictions = results.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Future<void> _selectResult(Map<String, dynamic> result) async {
    setState(() {
      _predictions = [];
      _isGeocoding = true;
    });
    final address = result['display_name'] as String;
    _searchController.text = address;
    FocusScope.of(context).unfocus();

    try {
      final lat = double.parse(result['lat'] as String);
      final lon = double.parse(result['lon'] as String);
      final latLng = LatLng(lat, lon);
      _centerLatLng = latLng;
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
    } catch (_) {}

    if (mounted) setState(() => _isGeocoding = false);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _isGeocoding = true);
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=${pos.latitude}&lon=${pos.longitude}&format=json',
    );
    try {
      final res = await http.get(url, headers: {
        'Accept-Language': 'tr',
        'User-Agent': 'AeroCabApp/1.0',
      });
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final display = data['display_name'] as String?;
        if (display != null) _searchController.text = display;
      }
    } catch (_) {}
    if (mounted) setState(() => _isGeocoding = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              if (widget.initialPosition != null) {
                c.animateCamera(
                  CameraUpdate.newLatLngZoom(widget.initialPosition!, 15),
                );
              }
            },
            initialCameraPosition: CameraPosition(target: _centerLatLng, zoom: 14),
            onCameraMove: (pos) => _centerLatLng = pos.target,
            onCameraIdle: () => _reverseGeocode(_centerLatLng),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Fixed center pin
          const IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_pin, color: Colors.red, size: 44),
                  SizedBox(height: 44),
                ],
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: widget.title,
                              hintStyle: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.4),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(Icons.search_rounded, color: cs.primary, size: 20),
                              suffixIcon: _isGeocoding
                                  ? Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cs.primary,
                                        ),
                                      ),
                                    )
                                  : _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _predictions = []);
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_predictions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _predictions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: cs.outline.withValues(alpha: 0.1),
                      ),
                      itemBuilder: (context, i) => ListTile(
                        dense: true,
                        leading: Icon(Icons.location_on_outlined, color: cs.primary, size: 18),
                        title: Text(
                          _predictions[i]['display_name'] as String,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectResult(_predictions[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Confirm button
          Positioned(
            bottom: 32,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isGeocoding
                    ? null
                    : () => Navigator.pop(
                          context,
                          MapPickerResult(
                            location: _centerLatLng,
                            address: _searchController.text.isNotEmpty
                                ? _searchController.text
                                : '${_centerLatLng.latitude.toStringAsFixed(5)}, ${_centerLatLng.longitude.toStringAsFixed(5)}',
                          ),
                        ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Konumu Onayla',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
          ],
        ),
        child: Icon(icon, color: cs.onSurface, size: 20),
      ),
    );
  }
}
