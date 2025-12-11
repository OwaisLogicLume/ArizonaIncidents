import 'package:maplibre_gl/maplibre_gl.dart';

/// State class for the Map Page
class MapPageState {
  final LatLng? currentLocation;
  final LatLng? destinationLocation;
  final List<LatLng> routePoints;
  final bool isLoadingLocation;
  final bool isLoadingRoute;
  final String errorMessage;
  final String statusMessage;

  const MapPageState({
    this.currentLocation,
    this.destinationLocation,
    this.routePoints = const [],
    this.isLoadingLocation = false,
    this.isLoadingRoute = false,
    this.errorMessage = '',
    this.statusMessage = '',
  });

  /// Copy with method for immutable state updates
  MapPageState copyWith({
    LatLng? currentLocation,
    LatLng? destinationLocation,
    List<LatLng>? routePoints,
    bool? isLoadingLocation,
    bool? isLoadingRoute,
    String? errorMessage,
    String? statusMessage,
  }) {
    return MapPageState(
      currentLocation: currentLocation ?? this.currentLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      routePoints: routePoints ?? this.routePoints,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
      errorMessage: errorMessage ?? this.errorMessage,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  /// Clear destination location
  MapPageState clearDestination() {
    return copyWith(
      destinationLocation: null,
      routePoints: [],
      statusMessage: 'Route cleared',
    );
  }

  /// Clear error message
  MapPageState clearError() {
    return copyWith(errorMessage: '');
  }
}
