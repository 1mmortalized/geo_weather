import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geo_weather/route_builder.dart';

import 'location_search_bar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoWeather',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      home: MainScreen(
        onThemeChanged: (isDark) {
          setState(() {
            this.isDark = isDark;
          });
        },
      ),
    );
  }

// Future<void> _drawRoad() async {
//   RoadInfo roadInfo = await mapController.drawRoad(
//     GeoPoint(latitude: 49.236997, longitude: 28.405208),
//     GeoPoint(latitude: 49.033457, longitude: 27.228157),
//     roadType: RoadType.car,
//     roadOption: const RoadOption(
//       roadWidth: 10,
//       roadColor: Colors.blue,
//       zoomInto: true,
//     ),
//   );
//   print("${roadInfo.distance}km");
//   print("${roadInfo.duration}sec");
//   print("${roadInfo.instructions}");
// }
//
}

class MainScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;

  const MainScreen({super.key, this.onThemeChanged});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late MapController mapController;

  @override
  void initState() {
    mapController = MapController.withUserPosition(
      trackUserLocation: const UserTrackingOption(
        enableTracking: true,
        unFollowUser: false,
      ),
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        OSMFlutter(
          controller: mapController,
          osmOption: OSMOption(
            userTrackingOption: const UserTrackingOption(
              enableTracking: true,
              unFollowUser: false,
            ),
            zoomOption: const ZoomOption(
              initZoom: 8,
              minZoomLevel: 3,
              maxZoomLevel: 19,
              stepZoom: 1.0,
            ),
            userLocationMarker: UserLocationMaker(
              personMarker: const MarkerIcon(
                icon: Icon(
                  Icons.location_history_rounded,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              directionArrowMarker: const MarkerIcon(
                icon: Icon(
                  Icons.double_arrow,
                  size: 48,
                ),
              ),
            ),
            roadConfiguration: const RoadOption(
              roadColor: Colors.yellowAccent,
            ),
            enableRotationByGesture: false,
            showZoomController: true,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: LocationSearchBar(
              onThemeChanged: (isDark) {
                widget.onThemeChanged!(isDark);
              },
              onItemTap: (point) async {
                await mapController.moveTo(point, animate: true);
                await mapController.setZoom(zoomLevel: 17);
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  onPressed: () {},
                  child: const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'navigate-dialog',
                  label: const Text("Navigate"),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NavigateFullscreenDialog(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  icon: const Icon(Icons.turn_right_rounded),
                ),
              ],
            ),
          ),
        )
      ]),
    );
  }

  @override
  void deactivate() {
    super.deactivate();
    mapController.dispose();
  }
}
