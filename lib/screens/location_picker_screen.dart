import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickResult {
  final String label;
  final LatLng latLng;

  const LocationPickResult({required this.label, required this.latLng});
}

class LocationPickerScreen extends StatefulWidget {
  final String? initialLabel;

  const LocationPickerScreen({super.key, this.initialLabel});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const LatLng _defaultCenter = LatLng(6.9271, 79.8612);

  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  LatLng _pickedLatLng = _defaultCenter;
  String _pickedLabel = 'Move the map or search a place';

  bool _isSearching = false;
  bool _isResolvingAddress = false;
  bool _isGettingCurrentLocation = false;
  bool _hasLocationPermission = false;
  bool _mapReady = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if ((widget.initialLabel ?? '').trim().isNotEmpty) {
      _searchController.text = widget.initialLabel!.trim();
      _pickedLabel = widget.initialLabel!.trim();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location services on your phone.'),
        ),
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission was denied.')),
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission is permanently denied. Enable it in app settings.',
          ),
        ),
      );
      return false;
    }

    if (mounted) {
      setState(() {
        _hasLocationPermission = true;
      });
    }

    return true;
  }

  String _formatPlacemarkLabel(
    List<Placemark> placemarks,
    double latitude,
    double longitude,
  ) {
    if (placemarks.isEmpty) {
      return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    }

    final place = placemarks.first;

    final parts = <String>[
      if ((place.name ?? '').trim().isNotEmpty) place.name!.trim(),
      if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
      if ((place.administrativeArea ?? '').trim().isNotEmpty)
        place.administrativeArea!.trim(),
      if ((place.country ?? '').trim().isNotEmpty) place.country!.trim(),
    ];

    if (parts.isEmpty) {
      return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    }

    return parts.take(3).join(', ');
  }

  void _scheduleResolveAddress(LatLng latLng) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _resolveAddressForLatLng(latLng);
    });
  }

  Future<void> _resolveAddressForLatLng(LatLng latLng) async {
    if (!mounted) return;

    setState(() {
      _isResolvingAddress = true;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      final label = _formatPlacemarkLabel(
        placemarks,
        latLng.latitude,
        latLng.longitude,
      );

      if (!mounted) return;

      setState(() {
        _pickedLabel = label;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _pickedLabel =
            '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingAddress = false;
        });
      }
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await locationFromAddress(query);

      if (results.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No location found for that search.')),
        );
        return;
      }

      final result = results.first;
      final latLng = LatLng(result.latitude, result.longitude);

      setState(() {
        _pickedLatLng = latLng;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 16),
        ),
      );

      await _resolveAddressForLatLng(latLng);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_isGettingCurrentLocation) return;

    final granted = await _ensureLocationPermission();
    if (!granted) return;

    setState(() {
      _isGettingCurrentLocation = true;
    });

    try {
      Position? position = await Geolocator.getLastKnownPosition();

      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _pickedLatLng = latLng;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 17),
        ),
      );

      await _resolveAddressForLatLng(latLng);
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Current location timed out. Search manually or try again.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get current location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGettingCurrentLocation = false;
        });
      }
    }
  }

  void _confirmSelection() {
    Navigator.pop(
      context,
      LocationPickResult(label: _pickedLabel, latLng: _pickedLatLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Location'), centerTitle: true),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLatLng,
              zoom: 14,
            ),
            mapType: MapType.normal,
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            indoorViewEnabled: false,
            buildingsEnabled: false,
            trafficEnabled: false,
            compassEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
              setState(() {
                _mapReady = true;
              });
              _scheduleResolveAddress(_pickedLatLng);
            },
            onCameraMove: (position) {
              _pickedLatLng = position.target;
            },
            onCameraIdle: () {
              if (_mapReady) {
                _scheduleResolveAddress(_pickedLatLng);
              }
            },
          ),

          const Center(
            child: IgnorePointer(
              child: Icon(Icons.location_pin, size: 46, color: Colors.red),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchLocation(),
                      decoration: InputDecoration(
                        hintText: 'Search a place',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                onPressed: _searchLocation,
                                icon: const Icon(Icons.arrow_forward_rounded),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton.small(
                      heroTag: 'current_location_button',
                      onPressed: _isGettingCurrentLocation
                          ? null
                          : _goToCurrentLocation,
                      child: _isGettingCurrentLocation
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ),
                  const Spacer(),
                  Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isResolvingAddress
                                ? 'Finding address...'
                                : 'Selected location',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _pickedLabel,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _confirmSelection,
                              child: const Text('Confirm location'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
