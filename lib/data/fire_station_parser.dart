import 'package:open_street_map/data/model/fire_station.dart';

class FireStationParser {
  static List<FireStation> parse(Map<String, dynamic> geoJson) {
    try {
      print('🔍 Parsing GeoJSON...');
      print('   GeoJSON keys: ${geoJson.keys.toList()}');

      // Validate features exist
      if (!geoJson.containsKey("features")) {
        print('❌ GeoJSON does not contain "features" key');
        print('   Available keys: ${geoJson.keys}');
        return [];
      }

      var featuresData = geoJson["features"];
      if (featuresData == null) {
        print('❌ Features is null');
        return [];
      }

      List features = featuresData as List;
      print('   Found ${features.length} features to parse');

      if (features.isEmpty) {
        print('⚠️ Features list is empty!');
        return [];
      }

      // Parse features with validation
      List<FireStation> stations = [];
      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < features.length; i++) {
        try {
          var f = features[i];

          // Validate structure
          if (f == null) {
            print('⚠️ Feature $i is null, skipping');
            errorCount++;
            continue;
          }

          var props = f["properties"];
          var geom = f["geometry"];

          if (props == null || geom == null) {
            print('⚠️ Feature $i missing properties or geometry, skipping');
            errorCount++;
            continue;
          }

          // Validate coordinates
          var coordinates = geom["coordinates"];
          if (coordinates == null || coordinates is! List || coordinates.length < 2) {
            print('⚠️ Feature $i has invalid coordinates: $coordinates, skipping');
            errorCount++;
            continue;
          }

          // Extract data with validation
          var objectId = props["objectid"] ?? props["OBJECTID"] ?? i.toString();
          var name = props["name"] ?? props["NAME"] ?? "Unknown Station";
          var lon = coordinates[0] as num;
          var lat = coordinates[1] as num;

          // Validate coordinate ranges
          if (lon < -180 || lon > 180 || lat < -90 || lat > 90) {
            print('⚠️ Feature $i has invalid coordinate range: ($lat, $lon), skipping');
            errorCount++;
            continue;
          }

          stations.add(FireStation(
            id: objectId.toString(),
            name: name,
            lon: lon.toDouble(),
            lat: lat.toDouble(),
          ));
          successCount++;

        } catch (e) {
          print('❌ Error parsing feature $i: $e');
          errorCount++;
          continue;
        }
      }

      print('✅ Parsing complete: $successCount successful, $errorCount errors');
      if (successCount > 0) {
        print('📍 Sample: ${stations.first.name} at (${stations.first.lat}, ${stations.first.lon})');
      }

      return stations;

    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR in FireStationParser.parse: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
}
