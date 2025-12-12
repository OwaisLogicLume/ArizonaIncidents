import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_street_map/data/model/fire_station.dart';

class FireStationMarkerManager{
  static List<Marker> buildMarkers(List<FireStation> list){
    return list.map((s){
         return Marker(
           width: 20,
           height: 20,
           point: LatLng(s.lat, s.lon),
           alignment: Alignment.center,
           child: Container(
             decoration: BoxDecoration(
               color: Colors.red.withValues(alpha: 0.8),
               shape: BoxShape.circle,
               border: Border.all(color: Colors.white, width: 2),
             ),
             child: Icon(
               Icons.local_fire_department,
               color: Colors.white,
               size: 30,
             ),
           )
         );
    }).toList();
  }
}