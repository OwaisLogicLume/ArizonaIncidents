import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:open_street_map/presentation/viewmodels/map_page_viewmodel.dart';
import 'open_source_map_page_refactored.dart';

class OpenSourceMapPage2 extends ConsumerStatefulWidget {
  const OpenSourceMapPage2({super.key});

  @override
  ConsumerState<OpenSourceMapPage2> createState() => _OpenSourceMapPage2State();
}

class _OpenSourceMapPage2State extends ConsumerState<OpenSourceMapPage2> {
  int selectedLayerIndex = 0;
  MaplibreMapController? controller;
  List<MapLayerConfig> mapLayers = [];
  final TextEditingController destinationController = TextEditingController();

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
    // Wait for widget to be built before getting location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapPageViewModelProvider.notifier).getCurrentLocation();
    });
  }

  @override
  void dispose() {
    destinationController.dispose();
    super.dispose();
  }

  void _handleGetRoute() {
    ref.read(mapPageViewModelProvider.notifier).getRoute(destinationController.text);
  }

  void _handleClearRoute() {
    ref.read(mapPageViewModelProvider.notifier).clearRoute();
    destinationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the state from the ViewModel
    final state = ref.watch(mapPageViewModelProvider);
    final viewModel = ref.read(mapPageViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Navigation Map', style: TextStyle(fontSize: 20)),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: () => viewModel.getCurrentLocation(),
            tooltip: 'Get Current Location',
          ),
          IconButton(
            onPressed: () => _showLayerSelector(),
            icon: Icon(Icons.layers),
            tooltip: 'Change Map Style',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map background
          MaplibreMap(
            key: ValueKey('map_$selectedLayerIndex'),
            styleString: osmTile(),
            initialCameraPosition: const CameraPosition(
              target: LatLng(35.0, 105.0), // Center of world initially
              zoom: 3,
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(3, 18),
            myLocationEnabled: false,
            onMapCreated: (mapController) async {
              controller = mapController;
              // Set the controller in the ViewModel
              viewModel.setMapController(mapController);
            },
            onStyleLoadedCallback: () async {
              debugPrint('Map style loaded successfully: Layer $selectedLayerIndex');
              // Re-add markers and route after style change
              await viewModel.reAddMarkersAndRoute();
            },
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
                            // Cancel location loading - we can implement this later if needed
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
                    // Update selected layer and rebuild map
                    setState(() {
                      selectedLayerIndex = index;
                    });
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

  String osmTile() {
    final String urlTemplate;
    switch (selectedLayerIndex) {
      case 0:
        // Free OSM - no API key needed
        urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
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

    // Return proper MapLibre style JSON
    return """
{
  "version": 8,
  "name": "Raster Map",
  "sources": {
    "raster-tiles": {
      "type": "raster",
      "tiles": ["$urlTemplate"],
      "tileSize": 256,
      "attribution": "© OpenStreetMap contributors"
    }
  },
  "layers": [
    {
      "id": "simple-tiles",
      "type": "raster",
      "source": "raster-tiles",
      "minzoom": 0,
      "maxzoom": 22
    }
  ]
}
""";
  }
}
