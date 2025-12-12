import 'package:hive/hive.dart';
import 'package:open_street_map/core/usgs_downloader.dart';
import 'package:open_street_map/data/fire_station_parser.dart';
import 'package:open_street_map/data/model/fire_station.dart';
import 'package:open_street_map/data/repository/fire_station_repository.dart';

class FireStationService{
  final FireStationRepository repo=FireStationRepository();

  Future<List<FireStation>> getFireStation() async{
    print('\n🚀 FireStationService.getFireStation() called');

    try {
      if(await repo.hasCache()){
        print('✅ Cache found, loading from Hive');
        final stations = await repo.load();

        if (stations.isEmpty) {
          print('⚠️ Cache exists but is empty, forcing download...');
          return await _downloadAndSave();
        }

        return stations;
      }

      print('❌ No cache found, downloading from USGS...');
      return await _downloadAndSave();
    } catch (e, stackTrace) {
      print('❌ ERROR in getFireStation: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<FireStation>> _downloadAndSave() async {
    try {
      print('📡 Starting download from USGS API...');
      final geoJson = await USGSDownloader.downloadFireStations('Arizona');

      if (geoJson.isEmpty) {
        throw Exception('Received empty response from USGS API');
      }

      print('📦 Received GeoJSON data with ${geoJson.length} keys');
      print('   Keys: ${geoJson.keys.toList()}');

      final fireStations = FireStationParser.parse(geoJson);
      print('🔄 Parsed ${fireStations.length} fire stations');

      if (fireStations.isEmpty) {
        print('⚠️ WARNING: No fire stations were parsed from API response!');
        print('   This might be because:');
        print('   - The API returned no features');
        print('   - The data format is unexpected');
        print('   - All features had invalid coordinates');
        throw Exception('No fire stations could be parsed from API response. Check logs for details.');
      }

      print('💾 Saving ${fireStations.length} stations to Hive...');
      await repo.Save(fireStations);
      print("✅ Saved ${fireStations.length} stations to Hive");

      // Verify save was successful
      final box = await Hive.openBox<FireStation>('fire_station');
      print("🔍 Verification: Box now contains ${box.length} items");

      if (box.length != fireStations.length) {
        print('⚠️ WARNING: Saved count mismatch! Expected ${fireStations.length}, got ${box.length}');
      }

      return fireStations;
    } catch (e, stackTrace) {
      print('❌ ERROR in _downloadAndSave: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}