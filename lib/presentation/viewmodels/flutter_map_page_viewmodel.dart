import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'flutter_map_page_state.dart';

/// ViewModel for Flutter Map Page using Riverpod StateNotifier
class FlutterMapPageViewModel extends StateNotifier<FlutterMapPageState> {
  FlutterMapPageViewModel() : super(const FlutterMapPageState());

  // MapController - stored separately
  MapController? _mapController;

  /// Set map controller
  void setMapController(MapController controller) {
    _mapController = controller;
  }

  /// Clear error message
  void clearError() {
    state = state.clearError();
  }

  /// Zoom to current location (manual action)
  void zoomToCurrentLocation() {
    if (state.currentLocation == null) {
      state = state.copyWith(errorMessage: 'Current location not available yet');
      return;
    }

    if (_mapController != null) {
      try {
        _mapController!.move(state.currentLocation!, 15);
        debugPrint('🎯 Zoomed to current location: ${state.currentLocation}');
      } catch (e) {
        debugPrint('Error zooming to location: $e');
      }
    }
  }

  /// Get current location with permissions
  Future<void> getCurrentLocation() async {
    state = state.copyWith(
      isLoadingLocation: true,
      statusMessage: 'Getting your location...',
      errorMessage: '',
    );

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          errorMessage: 'Location services are disabled. Please enable them in settings.',
          isLoadingLocation: false,
          statusMessage: '',
        );
        return;
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            errorMessage: 'Location permissions are denied',
            isLoadingLocation: false,
            statusMessage: '',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          errorMessage: 'Location permissions are permanently denied. Please enable in settings.',
          isLoadingLocation: false,
          statusMessage: '',
        );
        return;
      }

      // Get current position with timeout and fallback
      Position position;
      try {
        debugPrint('Attempting to get location with high accuracy...');
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ).timeout(
          Duration(seconds: 15),
          onTimeout: () {
            throw Exception('High accuracy timed out');
          },
        );
      } catch (highAccuracyError) {
        debugPrint('High accuracy failed: $highAccuracyError. Trying medium accuracy...');
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ).timeout(
            Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Medium accuracy timed out');
            },
          );
        } catch (mediumAccuracyError) {
          debugPrint('Medium accuracy failed: $mediumAccuracyError. Trying last known location...');
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown == null) {
            throw Exception('Unable to get location. Please make sure GPS is enabled and you are outdoors or near a window.');
          }
          position = lastKnown;
        }
      }

      final newLocation = LatLng(position.latitude, position.longitude);

      state = state.copyWith(
        currentLocation: newLocation,
        statusMessage: 'Location found!',
        isLoadingLocation: false,
      );

      // DON'T automatically move map - let user see fire stations
      // User can manually zoom to their location using the my_location button
      debugPrint('✅ Current location marked on map at: ${newLocation.latitude}, ${newLocation.longitude}');
      debugPrint('💡 Map stays at current view to show fire stations. Use My Location button to zoom.');

      // Clear status message after delay
      await Future.delayed(Duration(seconds: 2));
      state = state.copyWith(statusMessage: '');
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Error getting location: ${e.toString()}',
        isLoadingLocation: false,
        statusMessage: '',
      );
      debugPrint('Location error: $e');
    }
  }

  /// Get route between current location and destination
  Future<void> getRoute(String destination) async {
    if (state.currentLocation == null) {
      state = state.copyWith(errorMessage: 'Please wait for current location to load');
      return;
    }

    if (destination.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter a destination');
      return;
    }

    state = state.copyWith(
      routePoints: [],
      isLoadingRoute: true,
      statusMessage: 'Calculating route...',
      errorMessage: '',
    );

    try {
      // First, geocode the destination address
      final searchQuery = destination.trim();
      final geocodeUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
            'q=${Uri.encodeComponent(searchQuery)}'
            '&format=json&limit=5&addressdetails=1',
      );

      final geocodeResponse = await http.get(
        geocodeUrl,
        headers: {'User-Agent': 'OpenStreetMapFlutterApp/1.0'},
      );

      if (geocodeResponse.statusCode != 200) {
        state = state.copyWith(
          errorMessage: 'Failed to search location. Check your internet connection.',
          isLoadingRoute: false,
          statusMessage: '',
        );
        return;
      }

      final geocodeData = json.decode(geocodeResponse.body) as List;
      if (geocodeData.isEmpty) {
        state = state.copyWith(
          errorMessage: 'Location "$searchQuery" not found. Try:\n'
              '• Full address (e.g., "123 Main St, City")\n'
              '• Place name (e.g., "Eiffel Tower")\n'
              '• City name (e.g., "Paris, France")',
          isLoadingRoute: false,
          statusMessage: '',
        );
        return;
      }

      // Use the first result
      final firstResult = geocodeData[0];
      final lat = double.parse(firstResult['lat']);
      final lon = double.parse(firstResult['lon']);
      final destinationLocation = LatLng(lat, lon);

      final displayName = firstResult['display_name'] ?? searchQuery;
      debugPrint('Found location: $displayName');

      // Update status to show we found the destination
      state = state.copyWith(
        destinationLocation: destinationLocation,
        statusMessage: 'Destination found! Calculating route...',
      );

      // Now get the route using OSRM
      final routeUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
            '${state.currentLocation!.longitude},${state.currentLocation!.latitude};'
            '${destinationLocation.longitude},${destinationLocation.latitude}'
            '?overview=full&geometries=geojson',
      );
      final routeResponse = await http.get(routeUrl);

      if (routeResponse.statusCode != 200) {
        throw Exception('Failed to get route');
      }
      final routeData = json.decode(routeResponse.body);
      if (routeData['code'] != 'Ok') {
        throw Exception('Route not found');
      }
      final coordinates = routeData['routes'][0]['geometry']['coordinates'] as List;
      final distance = routeData['routes'][0]['distance'] / 1000; // Convert to km
      final duration = routeData['routes'][0]['duration'] / 60; // Convert to minutes

      // Convert coordinates to LatLng
      List<LatLng> allPoints = coordinates
          .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
          .toList();

      // Simplify route points if too many
      List<LatLng> simplifiedPoints = [];
      if (allPoints.length > 200) {
        int step = (allPoints.length / 200).ceil();
        for (int i = 0; i < allPoints.length; i += step) {
          simplifiedPoints.add(allPoints[i]);
        }
        if (simplifiedPoints.last != allPoints.last) {
          simplifiedPoints.add(allPoints.last);
        }
      } else {
        simplifiedPoints = allPoints;
      }

      debugPrint('=== Route Calculated Successfully ===');
      debugPrint('Current location: ${state.currentLocation?.latitude}, ${state.currentLocation?.longitude}');
      debugPrint('Destination location: ${destinationLocation.latitude}, ${destinationLocation.longitude}');
      debugPrint('Route points: ${simplifiedPoints.length}');
      debugPrint('Distance: ${distance.toStringAsFixed(1)} km');
      debugPrint('Duration: ${duration.toStringAsFixed(0)} min');

      state = state.copyWith(
        routePoints: simplifiedPoints,
        statusMessage: 'Route found! ${distance.toStringAsFixed(1)} km, ${duration.toStringAsFixed(0)} min',
        isLoadingRoute: false,
      );

      // Center map to show both points - use fitBounds
      await _fitCameraToRoute();

      // Keep the distance/duration message visible longer
      await Future.delayed(Duration(seconds: 8));
      state = state.copyWith(statusMessage: '');
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Error calculating route: ${e.toString()}',
        isLoadingRoute: false,
        statusMessage: '',
      );
    }
  }

  /// Fit camera to show entire route
  Future<void> _fitCameraToRoute() async {
    if (_mapController == null || state.routePoints.isEmpty) return;
    if (state.currentLocation == null || state.destinationLocation == null) return;

    try {
      // Wait for UI and tiles to settle
      await Future.delayed(Duration(milliseconds: 1000));

      // Use fitCamera with bounds for more reliable zooming
      final bounds = LatLngBounds.fromPoints([
        state.currentLocation!,
        state.destinationLocation!,
      ]);

      // Calculate distance to determine appropriate padding
      final latDiff = (state.currentLocation!.latitude - state.destinationLocation!.latitude).abs();
      final lonDiff = (state.currentLocation!.longitude - state.destinationLocation!.longitude).abs();
      final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

      // Determine max zoom based on distance
      double maxZoom;
      if (maxDiff < 0.001) {
        maxZoom = 11.0;
      } else if (maxDiff < 0.01) {
        maxZoom = 12.0;
      } else if (maxDiff < 0.1) {
        maxZoom = 13.0;
      } else {
        maxZoom = 14.0;
      }

      _mapController!.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: EdgeInsets.all(100),
          maxZoom: maxZoom,
        ),
      );

      debugPrint('Map centered with maxZoom: $maxZoom');
    } catch (e) {
      debugPrint('Error fitting camera: $e');
      // Fallback: just center on current location at safe zoom
      try {
        if (state.currentLocation != null) {
          _mapController!.move(state.currentLocation!, 11.0);
        }
      } catch (fallbackError) {
        debugPrint('Fallback move also failed: $fallbackError');
      }
    }
  }

  /// Get route to nearest fire station
  Future<void> getRouteToNearestFireStation(List<LatLng> fireStationLocations) async {
    if (state.currentLocation == null) {
      state = state.copyWith(errorMessage: 'Current location not available. Please wait...');
      return;
    }

    if (fireStationLocations.isEmpty) {
      state = state.copyWith(errorMessage: 'No fire stations loaded. Please download fire stations first.');
      return;
    }

    state = state.copyWith(
      routePoints: [],
      isLoadingRoute: true,
      statusMessage: 'Finding nearest fire station...',
      errorMessage: '',
    );

    try {
      // Find nearest fire station
      LatLng? nearestStation;
      double minDistance = double.infinity;

      for (var stationLocation in fireStationLocations) {
        // Calculate distance using Haversine formula
        double distance = _calculateDistance(
          state.currentLocation!.latitude,
          state.currentLocation!.longitude,
          stationLocation.latitude,
          stationLocation.longitude,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestStation = stationLocation;
        }
      }

      if (nearestStation == null) {
        throw Exception('Could not find nearest fire station');
      }

      debugPrint('🔥 Nearest fire station found at: ${nearestStation.latitude}, ${nearestStation.longitude}');
      debugPrint('📏 Distance: ${minDistance.toStringAsFixed(2)} km');

      // Update status
      state = state.copyWith(
        destinationLocation: nearestStation,
        statusMessage: 'Found nearest station (${minDistance.toStringAsFixed(1)} km away). Getting route...',
      );

      // Get route using OSRM
      final routeUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
            '${state.currentLocation!.longitude},${state.currentLocation!.latitude};'
            '${nearestStation.longitude},${nearestStation.latitude}'
            '?overview=full&geometries=geojson',
      );

      final routeResponse = await http.get(routeUrl);

      if (routeResponse.statusCode != 200) {
        throw Exception('Failed to get route');
      }

      final routeData = json.decode(routeResponse.body);
      if (routeData['code'] != 'Ok') {
        throw Exception('Route not found');
      }

      final coordinates = routeData['routes'][0]['geometry']['coordinates'] as List;
      final distance = routeData['routes'][0]['distance'] / 1000; // Convert to km
      final duration = routeData['routes'][0]['duration'] / 60; // Convert to minutes

      // Convert coordinates to LatLng
      List<LatLng> allPoints = coordinates
          .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
          .toList();

      // Simplify route points if too many
      List<LatLng> simplifiedPoints = [];
      if (allPoints.length > 200) {
        int step = (allPoints.length / 200).ceil();
        for (int i = 0; i < allPoints.length; i += step) {
          simplifiedPoints.add(allPoints[i]);
        }
        if (simplifiedPoints.last != allPoints.last) {
          simplifiedPoints.add(allPoints.last);
        }
      } else {
        simplifiedPoints = allPoints;
      }

      debugPrint('=== Route to Nearest Fire Station Calculated ===');
      debugPrint('Distance: ${distance.toStringAsFixed(1)} km');
      debugPrint('Duration: ${duration.toStringAsFixed(0)} min');

      state = state.copyWith(
        routePoints: simplifiedPoints,
        statusMessage: 'Route to nearest fire station: ${distance.toStringAsFixed(1)} km, ${duration.toStringAsFixed(0)} min',
        isLoadingRoute: false,
      );

      // Fit camera to show route
      await _fitCameraToRoute();

      // Keep message visible longer
      await Future.delayed(Duration(seconds: 8));
      state = state.copyWith(statusMessage: '');

    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Error finding route to fire station: ${e.toString()}',
        isLoadingRoute: false,
        statusMessage: '',
      );
      debugPrint('Error in getRouteToNearestFireStation: $e');
    }
  }

  /// Calculate distance between two points using Haversine formula (in kilometers)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Clear route and destination
  Future<void> clearRoute() async {
    state = state.clearDestination();

    // Move back to current location
    if (_mapController != null && state.currentLocation != null) {
      try {
        _mapController!.move(state.currentLocation!, 15);
      } catch (e) {
        debugPrint('Error moving map after clear: $e');
      }
    }

    await Future.delayed(Duration(seconds: 2));
    state = state.copyWith(statusMessage: '');
  }
}

/// Provider for FlutterMapPageViewModel
final flutterMapPageViewModelProvider = StateNotifierProvider<FlutterMapPageViewModel, FlutterMapPageState>((ref) {
  return FlutterMapPageViewModel();
});
