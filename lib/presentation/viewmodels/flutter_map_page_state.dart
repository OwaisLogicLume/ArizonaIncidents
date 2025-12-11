import 'package:latlong2/latlong.dart';

/// State class for the Flutter Map Page
class FlutterMapPageState {
  final LatLng? currentLocation;
  final LatLng? destinationLocation;
  final List<LatLng> routePoints;
  final bool isLoadingLocation;
  final bool isLoadingRoute;
  final String errorMessage;
  final String statusMessage;

  const FlutterMapPageState({
    this.currentLocation,
    this.destinationLocation,
    this.routePoints = const [],
    this.isLoadingLocation = false,
    this.isLoadingRoute = false,
    this.errorMessage = '',
    this.statusMessage = '',
  });

  /// Copy with method for immutable state updates
  FlutterMapPageState copyWith({
    LatLng? currentLocation,
    LatLng? destinationLocation,
    List<LatLng>? routePoints,
    bool? isLoadingLocation,
    bool? isLoadingRoute,
    String? errorMessage,
    String? statusMessage,
  }) {
    return FlutterMapPageState(
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
  FlutterMapPageState clearDestination() {
    return copyWith(
      destinationLocation: null,
      routePoints: [],
      statusMessage: 'Route cleared',
    );
  }

  /// Clear error message
  FlutterMapPageState clearError() {
    return copyWith(errorMessage: '');
  }
}
