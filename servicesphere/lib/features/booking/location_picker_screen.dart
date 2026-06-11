import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();

  // Default Location: New Delhi placeholder until GPS settles
  LatLng _selectedLocation = const LatLng(28.6139, 77.2090);
  bool _isLoadingLocation = true;
  bool _isSatelliteView = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    setState(() => _isLoadingLocation = true);
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    // 🔥 FIX 1: Forced HIGH ACCURACY GPS lock
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    setState(() {
      _selectedLocation = LatLng(position.latitude, position.longitude);
      _isLoadingLocation = false;
    });

    // 🔥 FIX 2: Zoomed all the way in to 18.0 (Building/Street level)
    _mapController.move(_selectedLocation, 18.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String mapUrlTemplate = _isSatelliteView
        ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
        : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Choose Exact Location",
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.w800,
              fontSize: 18),
        ),
        backgroundColor: isDark
            ? const Color(0xFF121212).withOpacity(0.85)
            : Colors.white.withOpacity(0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : const Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // --- THE MAP LAYER ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 18.0, // Start very close
              onPositionChanged: (position, hasGesture) {
                if (position.center != null) {
                  _selectedLocation = position.center!;
                }
              },
              // 🔥 FIX 3: Tap-to-Snap! Tapping anywhere moves the center pin exactly there
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                });
                _mapController.move(point, 18.0);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: mapUrlTemplate,
                userAgentPackageName: 'com.example.servicesphere',
              ),
            ],
          ),

          // --- NATIVE FLOATING MAP PIN ---
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.handshake_rounded,
                        color: Colors.white, size: 24),
                  ),
                  Container(
                    width: 4,
                    height: 16,
                    color: theme.colorScheme.primary,
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- MAP TYPE TOGGLE (SATELLITE / STREET) ---
          Positioned(
            top: 110,
            right: 20,
            child: FloatingActionButton(
              heroTag: "layer_fab",
              mini: true,
              elevation: 4,
              backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              foregroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onPressed: () =>
                  setState(() => _isSatelliteView = !_isSatelliteView),
              child: Icon(
                  _isSatelliteView ? Icons.map_rounded : Icons.layers_rounded,
                  size: 20),
            ),
          ),

          // --- MY LOCATION FLOATING FAB ---
          Positioned(
            bottom: 116,
            right: 20,
            child: FloatingActionButton(
              heroTag: "gps_fab",
              elevation: 4,
              backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              foregroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onPressed: _determinePosition,
              child: const Icon(Icons.my_location_rounded, size: 22),
            ),
          ),

          // --- BOTTOM ACTION CARD ---
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, _selectedLocation),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        "Confirm Location",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoadingLocation)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
