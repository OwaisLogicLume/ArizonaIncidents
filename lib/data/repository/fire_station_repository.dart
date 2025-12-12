import 'package:hive/hive.dart';
import 'package:open_street_map/data/model/fire_station.dart';

class FireStationRepository{
  static const String boxName='fire_station';

  Future<void> Save(List<FireStation> list) async{
    print('💾 Saving ${list.length} fire stations to Hive...');
    final box= await Hive.openBox<FireStation>(boxName);
    await box.clear();
    await box.addAll(list);
    print('✅ Successfully saved ${box.length} fire stations');
  }

  Future<List<FireStation>> load()  async{
    print('📖 Loading fire stations from Hive...');
    final box=await Hive.openBox<FireStation>(boxName);
    print('   📦 Box name: $boxName, isOpen: ${box.isOpen}, length: ${box.length}');
    print('   🔑 Keys in box: ${box.keys.toList()}');

    final stations = box.values.toList();
    print('✅ Loaded ${stations.length} fire stations from cache');

    if (stations.isEmpty) {
      print('⚠️ WARNING: Box is empty! No fire stations in cache.');
    } else {
      print('📍 First station: ${stations.first.name} at (${stations.first.lat}, ${stations.first.lon})');
    }
    return stations;
  }

  Future<bool> hasCache() async{
    try {
      final exists = await Hive.boxExists(boxName);
      print('🔍 Checking cache: boxExists = $exists');

      if (exists) {
        // Open box to check if it has data
        final box = await Hive.openBox<FireStation>(boxName);
        final hasData = box.isNotEmpty;
        print('   📦 Box has data: $hasData (${box.length} items)');
        // Don't close - it will be used immediately after
        return hasData;
      }

      return false;
    } catch (e) {
      print('❌ Error checking cache: $e');
      return false;
    }
  }
}