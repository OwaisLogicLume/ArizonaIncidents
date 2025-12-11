import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:open_street_map/data/model/Incident.dart';
import 'package:http/http.dart' as https;
class HelperClass{

  static Future<List<Map<String, dynamic>>> fetchFireStations({
    double? south,
    double? west,
    double? north,
    double? east,
  }) async {
    const url = "https://overpass-api.de/api/interpreter";

    // Build bounding box string if coordinates are provided
    String boundingBox = '';
    if (south != null && west != null && north != null && east != null) {
      boundingBox = '($south,$west,$north,$east)';
    }

    final query = """
  [out:json][timeout:60];
  (
    node["amenity"="fire_station"]$boundingBox;
    way["amenity"="fire_station"]$boundingBox;
    relation["amenity"="fire_station"]$boundingBox;
  );
  out center;
  """;

    final response = await http.post(
      Uri.parse(url),
      body: {"data": query},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final elements = data['elements'] as List? ?? [];

      // Filter out elements without valid coordinates
      return elements.where((element) {
        final lat = element['lat'] ?? element['center']?['lat'];
        final lon = element['lon'] ?? element['center']?['lon'];
        return lat != null && lon != null;
      }).map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception("Overpass request failed: ${response.statusCode}");
    }
  }

  Future<List<Incident>> fetchIncidents() async {
    final url = Uri.parse("https://az511.gov/api/v2/events?key=YOUR_API_KEY");

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body);

    return (data["events"] as List).map((e) {
      final coords = e["location"]["coordinates"];
      return Incident(
        lat: coords[1],
        lng: coords[0],
        type: e["eventType"] ?? "",
        description: e["headline"] ?? "",
      );
    }).toList();
  }
  bool isIncidentOnRoute(Incident incident, List<LatLng> routePoints) {
    const double alertDistance = 300; // meters

    final distanceCalc = Distance();

    for (final point in routePoints) {
      final d = distanceCalc(
        point,
        LatLng(incident.lat, incident.lng),
      );

      if (d < alertDistance) {
        return true;
      }
    }
    return false;
  }
  void checkRouteForIncidents(List<LatLng> route) async {
    final incidents = await fetchIncidents();

    for (final incident in incidents) {
      if (isIncidentOnRoute(incident, route)) {
       /// showIncidentAlert(incident);
        break;
      }
    }
  }
  // void showIncidentAlert(Incident incident) {
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: Text("⚠ Route Incident Detected"),
  //       content: Text(
  //         "Type: ${incident.type}\n\nDetails: ${incident.description}",
  //       ),
  //       actions: [
  //         TextButton(
  //           child: Text("OK"),
  //           onPressed: () => Navigator.pop(context),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}