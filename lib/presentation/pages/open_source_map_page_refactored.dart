import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_street_map/core/fire_station_maker_manager.dart';
import 'package:open_street_map/data/model/fire_station.dart';
import 'package:open_street_map/data/services/fire_station_service.dart';
import 'package:open_street_map/presentation/viewmodels/flutter_map_page_viewmodel.dart';
class OpenSourceMapPage extends ConsumerStatefulWidget {
  const OpenSourceMapPage({super.key});

  @override
  ConsumerState<OpenSourceMapPage> createState() => _OpenSourceMapPageState();
}

class _OpenSourceMapPageState extends ConsumerState<OpenSourceMapPage> {
  int selectedLayerIndex = 0;
  final MapController mapController = MapController();
  final TextEditingController destinationController = TextEditingController();
  final GlobalKey _mapKey = GlobalKey();
  List<MapLayerConfig> mapLayers = [];
  List<Marker> markers = [];
  bool _markersLoaded = false;
  bool _isDownloading = false;
  Future<void> getfireStation() async {
    if (_markersLoaded && markers.isNotEmpty) {
      print('⚠️ Fire stations already loaded, skipping. (${markers.length} markers)');
      return;
    }

    print('🔄 Loading fire stations from cache/download...');
    List<FireStation> station = await FireStationService().getFireStation();
    print('✅ Loaded ${station.length} fire stations');

    if (mounted) {
      setState(() {
        markers = FireStationMarkerManager.buildMarkers(station);
        _markersLoaded = true;
      });
      print('🎯 Created ${markers.length} markers on map');
    } else {
      print('❌ Widget not mounted, cannot set markers');
    }
  }


  Future<void> downloadFireStation() async {
    setState(() {
      _isDownloading = true;
      _markersLoaded = false; // Reset flag to allow reload
      markers.clear(); // Clear existing markers
    });

    try {
      print('📡 Starting fresh download of fire stations...');

      // Clear the cache first to force a fresh download
      final box = await Hive.openBox<FireStation>('fire_station');
      await box.clear();
      await box.close();
      print('🗑️ Cleared existing cache');

      // Also delete the box file to ensure clean state
      await Hive.deleteBoxFromDisk('fire_station');
      print('🗑️ Deleted box from disk');

      // Use the service to download and save
      await getfireStation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded and loaded ${markers.length} fire stations!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ ERROR in downloadFireStation: $e');
      print('Stack trace: $stackTrace');
      developer.log('Download error', error: e, stackTrace: stackTrace);

      String errorMessage = 'Download failed';
      if (e.toString().contains('RangeError')) {
        errorMessage = 'Data parsing error. API may have returned invalid data.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Connection timeout. Check your internet connection.';
      } else if (e.toString().contains('No fire stations')) {
        errorMessage = 'API returned no data. Try again later.';
      } else {
        errorMessage = 'Download failed: ${e.toString().substring(0, 100)}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 7),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: downloadFireStation,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
      print('🏁 downloadFireStation() completed\n');
    }
  }


  // Future<void> loadFireStations() async {
  //   print('\n🚀 loadFireStations() CALLED - Starting to load...');
  //
  //   try {
  //     // Arizona state bounding box
  //     // For Phoenix only, use: south: 33.29, west: -112.32, north: 33.93, east: -111.93
  //     const double arizonaSouth = 31.33;  // Southern border with Mexico
  //     const double arizonaWest = -114.82; // Western border
  //     const double arizonaNorth = 37.00;  // Northern border
  //     const double arizonaEast = -109.05; // Eastern border with New Mexico
  //
  //     print('🔥 Loading fire stations in Arizona:');
  //     print('  South: $arizonaSouth, West: $arizonaWest');
  //     print('  North: $arizonaNorth, East: $arizonaEast');
  //
  //     developer.log('🔥 Loading fire stations in Arizona:');
  //     developer.log('  South: $arizonaSouth, West: $arizonaWest');
  //     developer.log('  North: $arizonaNorth, East: $arizonaEast');
  //
  //     final stations = await HelperClass.fetchFireStations(
  //       south: arizonaSouth,
  //       west: arizonaWest,
  //       north: arizonaNorth,
  //       east: arizonaEast,
  //     );
  //
  //     developer.log('✅ Found ${stations.length} fire stations');
  //     print('\n========== FIRE STATIONS ==========');
  //     print('Total found: ${stations.length}');
  //
  //     // Log each fire station details
  //     for (var i = 0; i < stations.length; i++) {
  //       final station = stations[i];
  //       final lat = station['lat'] ?? station['center']?['lat'];
  //       final lon = station['lon'] ?? station['center']?['lon'];
  //       final name = station['tags']?['name'] ?? 'Unnamed';
  //       final id = station['id'];
  //
  //       print('\n--- Fire Station ${i + 1} ---');
  //       print('  ID: $id');
  //       print('  Name: $name');
  //       print('  Latitude: $lat');
  //       print('  Longitude: $lon');
  //       print('  Type: ${station['type']}');
  //
  //       // Print all available tags
  //       if (station['tags'] != null) {
  //         print('  Tags:');
  //         (station['tags'] as Map).forEach((key, value) {
  //           print('    $key: $value');
  //         });
  //       }
  //     }
  //
  //     print('=====================================\n');
  //
  //     // Print first 3 coordinates to verify
  //     print('📍 Sample coordinates:');
  //     for (var i = 0; i < (stations.length > 3 ? 3 : stations.length); i++) {
  //       final s = stations[i];
  //       final lat = s['lat'] ?? s['center']?['lat'];
  //       final lon = s['lon'] ?? s['center']?['lon'];
  //       print('  Station $i: Lat=$lat, Lon=$lon');
  //     }
  //
  //     markers = stations.map((station){
  //       // Coordinates are already validated in HelperClass
  //       double lat = (station['lat'] ?? station['center']?['lat']) as double;
  //       double lon = (station['lon'] ?? station['center']?['lon']) as double;
  //
  //       return Marker(
  //         width: 60,
  //         height: 60,
  //         point: LatLng(lat, lon),
  //         child: Icon(
  //           Icons.local_fire_department,
  //           color: Colors.red,
  //           size: 40,
  //           shadows: [
  //             Shadow(
  //               color: Colors.white,
  //               blurRadius: 10,
  //             ),
  //             Shadow(
  //               color: Colors.white,
  //               blurRadius: 20,
  //             ),
  //           ],
  //         ),
  //       );
  //     }).toList();
  //
  //     print('🎯 Created ${markers.length} markers');
  //     print('🎯 First marker point: ${markers.isNotEmpty ? markers[0].point : "no markers"}');
  //     print('🎯 Calling setState to rebuild widget...');
  //
  //     if (mounted) {
  //       setState(() {
  //         _markersLoaded = true;
  //         print('✅ setState executed, markers.length = ${markers.length}, _markersLoaded = $_markersLoaded');
  //       });
  //     }
  //   } catch (e) {
  //     print('❌ Error loading fire stations: $e');
  //     developer.log('Error details: $e', error: e);
  //     // Optionally show error to user
  //   }
  // }



  @override
  void initState() {
    super.initState();
    mapLayers = [
      MapLayerConfig('Free OSM', 'No API', 0),
      MapLayerConfig('Basic', 'MapTiler API', 1),
      MapLayerConfig('Streets', 'MapTiler API', 2),
      MapLayerConfig('Bright', 'MapTiler API', 3),
      MapLayerConfig('Outdoor', 'MapTiler API', 4),
      MapLayerConfig('Dark', 'MapTiler API', 5),
      MapLayerConfig('Topo', 'MapTiler API', 6),
    ];

    // Set the map controller in ViewModel and get location
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(flutterMapPageViewModelProvider.notifier).setMapController(mapController);

      // Load fire stations first before getting location
      print('⏰ Map initialized, loading fire stations first...');
      await getfireStation();
      print('✅ Fire stations loaded, now getting current location...');

      // Then get current location
      ref.read(flutterMapPageViewModelProvider.notifier).getCurrentLocation();
    });
  }

  @override
  void dispose() {
    destinationController.dispose();
    mapController.dispose();
    super.dispose();
  }

  void _handleGetRoute() {
    ref.read(flutterMapPageViewModelProvider.notifier).getRoute(destinationController.text);
  }

  void _handleClearRoute() {
    ref.read(flutterMapPageViewModelProvider.notifier).clearRoute();
    destinationController.clear();
  }

  void _handleRouteToNearestFireStation() {
    print('🚒 Finding route to nearest fire station...');

    // Check if current location is available
    final state = ref.read(flutterMapPageViewModelProvider);
    if (state.currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please wait for current location to be determined'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check if fire stations are loaded
    if (markers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No fire stations loaded. Please download fire stations first.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'DOWNLOAD',
            textColor: Colors.white,
            onPressed: downloadFireStation,
          ),
        ),
      );
      return;
    }

    // Extract fire station locations from markers
    // markers list contains FireStation markers created by FireStationMarkerManager
    // We need to get the original fire station data
    print('📍 Fire stations loaded: ${markers.length}');

    // Since markers don't contain the original data, we need to reload fire stations
    // or store them separately. For now, let's extract locations from markers
    List<LatLng> fireStationLocations = markers.map((marker) => marker.point).toList();

    print('🔍 Searching among ${fireStationLocations.length} fire stations...');

    // Call the ViewModel to calculate and display route
    ref.read(flutterMapPageViewModelProvider.notifier)
        .getRouteToNearestFireStation(fireStationLocations);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the state from the ViewModel
    final state = ref.watch(flutterMapPageViewModelProvider);
    final viewModel = ref.read(flutterMapPageViewModelProvider.notifier);

    // Debug: Log detailed state on every build
    print('🔄 BUILD START: markers.length = ${markers.length}, _markersLoaded = $_markersLoaded');
    print('   📍 currentLocation = ${state.currentLocation}');
    print('   🎯 destinationLocation = ${state.destinationLocation}');
    print('   🗺️  FlutterMap key hashCode = ${_mapKey.hashCode}');

    // Failsafe: If markers were loaded but now empty, reload them
    if (_markersLoaded && markers.isEmpty) {
      print('🚨 CRITICAL: Markers were loaded but now empty! Reloading...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        getfireStation();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Navigation Map'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            onPressed: _isDownloading ? null : downloadFireStation,
            icon: _isDownloading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.download),
            tooltip: 'Download Fire Stations',
          ),
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: () {
              if (state.currentLocation == null) {
                viewModel.getCurrentLocation();
              } else {
                viewModel.zoomToCurrentLocation();
              }
            },
            tooltip: 'Zoom to My Location',
          ),
          IconButton(
            icon: Icon(Icons.local_fire_department),
            onPressed: getfireStation,
            tooltip: 'Load Fire Stations',
          ),
          IconButton(
            icon: Icon(Icons.layers),
            onPressed: _showLayerSelector,
            tooltip: 'Change Map Style',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map background
          FlutterMap(
            key: _mapKey,
            mapController: mapController,
            options: MapOptions(
              initialCenter: LatLng(33.4484, -112.0740), // Phoenix, Arizona
              initialZoom: 10,
              minZoom: 3,
              maxZoom: 18,
              backgroundColor: Colors.grey,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                pinchZoomThreshold: 0.5,
                scrollWheelVelocity: 0.005,
              ),
              onTap: (_, __) => viewModel.clearError(),
            ),
            children: [
              _getSelectedTileLayer(),

              // Route polyline
              if (state.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: state.routePoints,
                      strokeWidth: 5,
                      color: Colors.blue,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // ALL markers in a single MarkerLayer for better performance
              MarkerLayer(
                markers: () {
                  final allMarkers = [
                    // Fire station markers
                    ...markers,

                    // DEBUG: Test marker at Phoenix center
                  // Marker(
                  //   point: LatLng(33.4484, -112.0740),
                  //   width: 60,
                  //   height: 60,
                  //   alignment: Alignment.center,
                  //   child: Container(
                  //     decoration: BoxDecoration(
                  //       color: Colors.yellow,
                  //       shape: BoxShape.circle,
                  //       border: Border.all(color: Colors.black, width: 3),
                  //     ),
                  //     child: Center(
                  //       child: Text(
                  //         '${markers.length}',
                  //         style: TextStyle(
                  //           color: Colors.black,
                  //           fontWeight: FontWeight.bold,
                  //           fontSize: 12,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),

                  // Current location marker
                  if (state.currentLocation != null)
                    Marker(
                      point: state.currentLocation!,
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),

                  // Destination marker
                  if (state.destinationLocation != null)
                    Marker(
                      point: state.destinationLocation!,
                      width: 60,
                      height: 60,
                      alignment: Alignment.topCenter,
                      child: Container(
                        child: Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 60,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];

                  print('🎨 MarkerLayer rendering ${allMarkers.length} total markers:');
                  print('   - ${markers.length} fire stations');
                  print('   - 1 debug circle');
                  print('   - ${state.currentLocation != null ? 1 : 0} current location');
                  print('   - ${state.destinationLocation != null ? 1 : 0} destination');

                  return allMarkers;
                }(),
              ),
            ],
          ),

          // nearest fire station button
          Positioned(
            bottom: 30,
            right: 20,
            child: ElevatedButton(
              onPressed: _handleRouteToNearestFireStation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, size: 20),
                  SizedBox(width: 8),
                  Text('Nearest Fire Station'),
                ],
              ),
            ),
          ),
          // Search bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: destinationController,
                      decoration: InputDecoration(
                        hintText: 'Enter destination',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleGetRoute(),
                    ),
                  ),
                  if (state.routePoints.isEmpty)
                    IconButton(
                      icon: Icon(Icons.directions, color: Colors.blue),
                      onPressed: state.isLoadingRoute ? null : _handleGetRoute,
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.clear, color: Colors.red),
                      onPressed: _handleClearRoute,
                    ),
                ],
              ),
            ),
          ),

          // Loading indicator
          if (state.isLoadingLocation || state.isLoadingRoute)
            Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        state.isLoadingLocation
                            ? 'Getting location...'
                            : 'Calculating route...',
                        style: TextStyle(fontSize: 16),
                      ),
                      if (state.isLoadingLocation) ...[
                        SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            // Cancel location loading - can implement later if needed
                          },
                          child: Text('Skip'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Status message
          if (state.statusMessage.isNotEmpty && !state.isLoadingLocation && !state.isLoadingRoute)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.statusMessage,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error message
          if (state.errorMessage.isNotEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.errorMessage,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => viewModel.clearError(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showLayerSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Map Style',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...mapLayers.asMap().entries.map((entry) {
                int index = entry.key;
                MapLayerConfig layer = entry.value;
                bool isSelected = selectedLayerIndex == index;

                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue : Colors.grey,
                  ),
                  title: Text(layer.name),
                  subtitle: Text(layer.type),
                  selected: isSelected,
                  onTap: () {
                    Navigator.pop(context);
                    // Call setState after Navigator.pop to avoid conflicts
                    if (mounted) {
                      setState(() {
                        selectedLayerIndex = index;
                      });
                    }
                  },
                );
              }),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  TileLayer _getSelectedTileLayer() {
    try {
      String urlTemplate;
      Map<String, String>? additionalOptions;

      switch (selectedLayerIndex) {
        case 0:
          urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
          additionalOptions = {
            'maxZoom': '19',
          };
          break;
        case 1:
          urlTemplate =
              'https://api.maptiler.com/maps/basic-v2/{z}/{x}/{y}.png?key=MopTwHN2RooWHp2b7vBg';
          break;
        case 2:
          urlTemplate =
              'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=MopTwHN2RooWHp2b7vBg';
          break;
        case 3:
          urlTemplate =
              'https://api.maptiler.com/maps/bright-v2/{z}/{x}/{y}.png?key=MopTwHN2RooWHp2b7vBg';
          break;
        case 4:
          urlTemplate =
              'https://api.maptiler.com/maps/outdoor-v2/{z}/{x}/{y}.png?key=MopTwHN2RooWHp2b7vBg';
          break;
        case 5:
          urlTemplate =
              'https://api.maptiler.com/maps/dataviz/{z}/{x}/{y}.png?key=MopTwHN2RooWHp2b7vBg';
          break;
        case 6:
          urlTemplate =
              'https://api.maptiler.com/maps/topo-v2/{z}/{x}/{y}.png?key=MopTwHN2RooWHp2b7vBg';
          break;
        default:
          urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      }

      return TileLayer(
        urlTemplate: urlTemplate,
        userAgentPackageName: 'com.arizona.azincidentalert',
        maxZoom: 18,
        maxNativeZoom: 18,
        keepBuffer: 4,
        panBuffer: 2,
        tileProvider: NetworkTileProvider(),
        additionalOptions: additionalOptions ?? {},
      );
    } catch (e) {
      print('❌ Error creating tile layer: $e');
      developer.log('Tile layer error', error: e);
      // Return default OSM layer as fallback
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.arizona.azincidentalert',
        maxZoom: 18,
        maxNativeZoom: 18,
        keepBuffer: 4,
        panBuffer: 2,
        tileProvider: NetworkTileProvider(),
      );
    }
  }
}

class MapLayerConfig {
  final String name;
  final String type;
  final int index;

  MapLayerConfig(this.name, this.type, this.index);
}
