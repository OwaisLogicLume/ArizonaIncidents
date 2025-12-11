import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'map_page_state.dart';

/// ViewModel for Map Page using Riverpod StateNotifier
class MapPageViewModel extends StateNotifier<MapPageState> {
  MapPageViewModel() : super(const MapPageState());

  // MapLibre specific - stored separately as they're not part of UI state
  Circle? _currentLocationMarker;
  Circle? _destinationMarker;
  Line? _routeLine;
  MaplibreMapController? _mapController;

  /// Set map controller
  void setMapController(MaplibreMapController controller) {
    _mapController = controller;
  }

  /// Clear error message
  void clearError() {
    state = state.clearError();
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

      final bool hasExistingRoute = state.routePoints.isNotEmpty && state.destinationLocation != null;
      final newLocation = LatLng(position.latitude, position.longitude);

      state = state.copyWith(
        currentLocation: newLocation,
        statusMessage: hasExistingRoute ? 'Location updated! Showing route...' : 'Location found!',
        isLoadingLocation: false,
      );

      // Move map to current location and add marker
      if (_mapController != null) {
        await Future.delayed(Duration(milliseconds: 300));

        // If route exists, fit to show entire route; otherwise just zoom to current location
        if (hasExistingRoute) {
          await _addCurrentLocationMarker();
          await fitCameraToRoute();
        } else {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(newLocation, 15),
          );
          await _addCurrentLocationMarker();
        }
      }

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

  /// Add current location marker
  Future<void> _addCurrentLocationMarker() async {
    if (_mapController == null || state.currentLocation == null) return;

    try {
      // Remove old marker if exists
      if (_currentLocationMarker != null) {
        await _mapController!.removeCircle(_currentLocationMarker!);
      }

      // Add the current location marker as a large blue circle with white border
      _currentLocationMarker = await _mapController!.addCircle(
        CircleOptions(
          geometry: state.currentLocation!,
          circleRadius: 12.0,
          circleColor: "#2196F3", // Bright blue
          circleStrokeWidth: 4.0,
          circleStrokeColor: "#FFFFFF", // White border
          circleStrokeOpacity: 1.0,
          circleOpacity: 1.0,
        ),
      );
    } catch (e) {
      debugPrint('Error adding current location marker: $e');
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

      // Add route and markers to map
      await _addRouteToMap();
      await _addDestinationMarker();

      // Automatically fit camera to show entire route - like Google Maps
      await fitCameraToRoute();

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

  /// Add route line to map
  Future<void> _addRouteToMap() async {
    if (_mapController == null || state.routePoints.isEmpty) return;

    try {
      // Remove old route line if exists
      if (_routeLine != null) {
        await _mapController!.removeLine(_routeLine!);
      }

      // Add the route line with a thick, bright blue color
      _routeLine = await _mapController!.addLine(
        LineOptions(
          geometry: state.routePoints,
          lineColor: "#2196F3", // Bright blue to match current location
          lineWidth: 6.0,
          lineOpacity: 0.9,
        ),
      );
    } catch (e) {
      debugPrint('Error adding route to map: $e');
    }
  }

  /// Fit camera to show entire route
  Future<void> fitCameraToRoute() async {
    if (_mapController == null || state.routePoints.isEmpty) return;
    if (state.currentLocation == null || state.destinationLocation == null) return;

    try {
      // Wait a bit for markers to be added
      await Future.delayed(Duration(milliseconds: 300));

      // Calculate bounds from all route points for accurate fitting
      double minLat = state.routePoints[0].latitude;
      double maxLat = state.routePoints[0].latitude;
      double minLng = state.routePoints[0].longitude;
      double maxLng = state.routePoints[0].longitude;

      for (var point in state.routePoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      // Add some padding to the bounds (5% on each side)
      double latPadding = (maxLat - minLat) * 0.05;
      double lngPadding = (maxLng - minLng) * 0.05;

      minLat -= latPadding;
      maxLat += latPadding;
      minLng -= lngPadding;
      maxLng += lngPadding;

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      // Animate camera to show the entire route with padding
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 80,    // Left padding
          top: 120,    // Top padding (more space for search bar)
          right: 80,   // Right padding
          bottom: 100, // Bottom padding (space for messages)
        ),
      );

      debugPrint('Camera fitted to route bounds: SW($minLat, $minLng) NE($maxLat, $maxLng)');
    } catch (e) {
      debugPrint('Error fitting camera to route: $e');
      // Fallback: just center on current location
      try {
        if (state.currentLocation != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(state.currentLocation!, 12),
          );
        }
      } catch (fallbackError) {
        debugPrint('Fallback camera move also failed: $fallbackError');
      }
    }
  }

  /// Add destination marker
  Future<void> _addDestinationMarker() async {
    if (_mapController == null || state.destinationLocation == null) return;

    try {
      // Remove old marker if exists
      if (_destinationMarker != null) {
        await _mapController!.removeCircle(_destinationMarker!);
      }

      // Add the destination marker as a large red circle with white border
      _destinationMarker = await _mapController!.addCircle(
        CircleOptions(
          geometry: state.destinationLocation!,
          circleRadius: 14.0,
          circleColor: "#F44336", // Bright red
          circleStrokeWidth: 4.0,
          circleStrokeColor: "#FFFFFF", // White border
          circleStrokeOpacity: 1.0,
          circleOpacity: 1.0,
        ),
      );
    } catch (e) {
      debugPrint('Error adding destination marker: $e');
    }
  }

  /// Clear route and destination
  Future<void> clearRoute() async {
    state = state.clearDestination();

    // Remove route and destination marker from map
    if (_mapController != null) {
      if (_routeLine != null) {
        await _mapController!.removeLine(_routeLine!);
        _routeLine = null;
      }
      if (_destinationMarker != null) {
        await _mapController!.removeCircle(_destinationMarker!);
        _destinationMarker = null;
      }

      // Move back to current location
      if (state.currentLocation != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(state.currentLocation!, 15),
        );
      }
    }

    await Future.delayed(Duration(seconds: 2));
    state = state.copyWith(statusMessage: '');
  }

  /// Re-add all markers and routes after map style change
  Future<void> reAddMarkersAndRoute() async {
    if (_mapController == null) return;

    try {
      debugPrint('Re-adding markers and route after style change...');

      // Clear old references
      _currentLocationMarker = null;
      _destinationMarker = null;
      _routeLine = null;

      // Wait for style to be fully loaded
      await Future.delayed(Duration(milliseconds: 500));

      // Re-add current location marker if exists
      if (state.currentLocation != null) {
        await _addCurrentLocationMarker();
        debugPrint('Current location marker re-added');
      }

      // Re-add route if exists
      if (state.routePoints.isNotEmpty) {
        await _addRouteToMap();
        debugPrint('Route re-added');
      }

      // Re-add destination marker if exists
      if (state.destinationLocation != null) {
        await _addDestinationMarker();
        debugPrint('Destination marker re-added');
      }

      // Re-fit camera to show route if it exists
      if (state.routePoints.isNotEmpty &&
          state.currentLocation != null &&
          state.destinationLocation != null) {
        await fitCameraToRoute();
        debugPrint('Camera re-fitted to route');
      } else if (state.currentLocation != null) {
        // Just center on current location if no route
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(state.currentLocation!, 15),
        );
        debugPrint('Camera centered on current location');
      }
    } catch (e) {
      debugPrint('Error re-adding markers and route: $e');
    }
  }
}
/// Provider for MapPageViewModel
final mapPageViewModelProvider = StateNotifierProvider<MapPageViewModel, MapPageState>((ref) {
  return MapPageViewModel();
});
