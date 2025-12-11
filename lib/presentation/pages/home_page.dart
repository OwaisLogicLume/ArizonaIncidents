import 'package:flutter/material.dart';
import 'package:open_street_map/presentation/pages/open_source_map_page_refactored.dart';
import 'package:open_street_map/presentation/pages/open_source_map_page2_refactored.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Open Street Map Demo'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Select Map Implementation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 40),

              // FlutterMap version
           Container(
                  height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.blue
                ),
                  child:Center(
                    child:  ListTile(
                      leading: Icon(Icons.map, color: Colors.blue, size: 40),
                      title: Text('FlutterMap ', style: TextStyle(fontSize: 18,color: Colors.white, fontWeight: FontWeight.w600)),
                      trailing: Icon(Icons.arrow_forward_ios,color: Colors.white,),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => OpenSourceMapPage()),
                        );
                      },
                    ),
                  ),
                ),

              SizedBox(height: 16),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.blue
                  ),
                  child:Center(
                    child:  ListTile(
                      leading: Icon(Icons.map, color: Colors.blue, size: 40),
                      title: Text('MapLibre ', style: TextStyle(fontSize: 18,color: Colors.white, fontWeight: FontWeight.w600)),
                      trailing: Icon(Icons.arrow_forward_ios,color: Colors.white,),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => OpenSourceMapPage2()),
                        );
                      },
                    ),
                  ),
                ),
              // MapLibre version
              // Card(
              //   elevation: 4,
              //   child: ListTile(
              //     leading: Icon(Icons.navigation, color: Colors.green, size: 40),
              //     title: Text('MapLibre ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              //     trailing: Icon(Icons.arrow_forward_ios),
              //     onTap: () {
              //       Navigator.push(
              //         context,
              //         MaterialPageRoute(builder: (context) => OpenSourceMapPage2()),
              //       );
              //     },
              //   ),
              // ),

              SizedBox(height: 40),

            ],
          ),
        ),
      ),
    );
  }
}
