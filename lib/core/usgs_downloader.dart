import 'package:http/http.dart' as http;
import 'dart:convert';

class USGSDownloader {
  /// Downloads fire station data from USGS National Map ArcGIS REST API
  ///
  /// Uses the USGS Structures MapServer Layer 16 (Fire Stations/EMS Stations)
  /// API Documentation: https://carto.nationalmap.gov/arcgis/rest/services/structures/MapServer/16
  static Future<Map<String, dynamic>> downloadFireStations(String state) async {
    try {
      print('\n🔵 Querying USGS ArcGIS REST API for Fire Stations...');

      // Define state bounding boxes
      Map<String, Map<String, double>> stateBounds = {
        'Arizona': {
          'west': -114.82,
          'south': 31.33,
          'east': -109.05,
          'north': 37.00,
        }
      };

      var bounds = stateBounds[state];
      if (bounds == null) {
        throw Exception('State "$state" is not supported. Available: ${stateBounds.keys.join(", ")}');
      }

      // USGS National Map Structures - Fire Stations/EMS Stations (Layer 16)
      // Using ArcGIS REST API Query endpoint
      String baseUrl = 'https://carto.nationalmap.gov/arcgis/rest/services/structures/MapServer/16/query';

      // Build query parameters
      Map<String, String> queryParams = {
        'where': '1=1', // Get all features in the bbox
        'geometry': '${bounds['west']},${bounds['south']},${bounds['east']},${bounds['north']}',
        'geometryType': 'esriGeometryEnvelope',
        'inSR': '4326', // WGS84
        'spatialRel': 'esriSpatialRelIntersects',
        'outFields': '*', // Get all fields
        'returnGeometry': 'true',
        'outSR': '4326', // Return in WGS84
        'f': 'geojson', // Return as GeoJSON format
      };

      // Build full URL
      String apiUrl = baseUrl + '?' + queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

      print('📡 API URL: $apiUrl');
      print('📍 Querying $state: (${bounds['south']}, ${bounds['west']}) to (${bounds['north']}, ${bounds['east']})');

      // Make the request with timeout
      print('⏳ Making HTTP request...');
      var response = await http.get(Uri.parse(apiUrl)).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out after 30 seconds');
        },
      );

      print('✅ Response received!');
      print('   Status: ${response.statusCode}');
      print('   Body length: ${response.body.length} bytes');
      print('   Headers: ${response.headers}');

      if (response.statusCode != 200) {
        print('❌ Bad response status: ${response.statusCode}');
        print('   Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        throw Exception('USGS API returned status code: ${response.statusCode}');
      }

      if (response.body.isEmpty) {
        throw Exception('USGS API returned empty body');
      }

      // Parse GeoJSON response
      print('🔄 Parsing JSON...');
      var geoJson = json.decode(response.body) as Map<String, dynamic>;
      print('✅ JSON decoded successfully');
      print('   GeoJSON keys: ${geoJson.keys.toList()}');

      // Check if features exist
      if (geoJson['features'] == null) {
        throw Exception('API response does not contain "features" field. Response: $geoJson');
      }

      List features = geoJson['features'] as List;
      print('📊 Total fire stations found: ${features.length}');

      if (features.isEmpty) {
        print('⚠️  Warning: No fire stations found in $state region');
      } else {
        // Log first few features for debugging
        print('\n🔎 Sample fire station:');
        if (features.isNotEmpty) {
          var firstFeature = features[0];
          print('  Type: ${firstFeature['type']}');
          print('  Geometry: ${firstFeature['geometry']}');
          if (firstFeature['properties'] != null) {
            print('  Properties: ${firstFeature['properties']}');
          }
        }
      }

      print('✅ Successfully retrieved fire station data from USGS');
      return geoJson;

    } catch (e, stackTrace) {
      print('\n❌ Error in downloadFireStations: $e');
      print('Stack trace: $stackTrace');
      rethrow; // Re-throw to be caught by the calling function
    }
  }
}