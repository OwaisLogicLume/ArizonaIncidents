import 'package:hive/hive.dart';
part 'fire_station.g.dart';
@HiveType(typeId: 1)
class FireStation{
@HiveField(0)
 final String id;
@HiveField(1)
  final double lat;
@HiveField(2)
  final double lon;
@HiveField(3)
  final String name;
FireStation({required this.id,required this.lat,required this.lon,required this.name});
}