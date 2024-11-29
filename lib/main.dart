import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:weather/weather.dart';

void main() async {
  await dotenv.load(fileName: ".env");
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
          seedColor: Colors.green,
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
}

class MainScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;

  const MainScreen({super.key, this.onThemeChanged});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool isDark = false;

  late MapController mapController;
  GeoPoint? pickedLocation;

  GeoPoint? routeStart;
  GeoPoint? routeEnd;

  // The query currently being searched for. If null, there is no pending
  // request.
  String? _searchingWithQuery;

  // The most recent options received from the API.
  late Iterable<Widget> _lastOptions = <Widget>[];

  List<GeoPoint> markers = List.empty(growable: true);

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
            child: getLocationSearchBar(),
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
                        builder: (context) => getNavigateDialog(),
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

  Widget getNavigateDialog() {
    return Hero(
      tag: 'navigate-dialog',
      child: Dialog.fullscreen(
          child: Scaffold(
        appBar: AppBar(
          title: const Text("Creating a route"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _drawRoad(routeStart!, routeEnd!).then((_) {
                  routeStart = null;
                  routeEnd = null;
                });
              },
              child: const Text("Go"),
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: Column(
              children: [
                SearchAnchor(
                  builder: (BuildContext context, SearchController controller) {
                    return TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        icon: Icon(Icons.trip_origin),
                        hintText: 'Enter start point',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(8.0),
                      ),
                      onTap: () {
                        controller.openView();
                      },
                    );
                  },
                  suggestionsBuilder:
                      (BuildContext context, SearchController controller) {
                    return _suggestionBuilder(context, controller,
                        onItemTap: (point) {
                      routeStart = point;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SearchAnchor(
                  builder: (BuildContext context, SearchController controller) {
                    return TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        icon: Icon(
                          Icons.location_on_rounded,
                          color: Colors.red,
                        ),
                        hintText: 'Enter destination point',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(8.0),
                      ),
                      onTap: () {
                        controller.openView();
                      },
                    );
                  },
                  suggestionsBuilder:
                      (BuildContext context, SearchController controller) {
                    return _suggestionBuilder(context, controller,
                        onItemTap: (point) {
                      routeEnd = point;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget getLocationSearchBar() {
    return SearchAnchor(
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          padding: const WidgetStatePropertyAll<EdgeInsets>(
              EdgeInsets.symmetric(horizontal: 16.0)),
          onTap: () {
            controller.openView();
          },
          onChanged: (_) {
            controller.openView();
          },
          hintText: "Search",
          leading: const Icon(Icons.search),
          trailing: <Widget>[
            Tooltip(
              message: 'Change brightness mode',
              child: IconButton(
                isSelected: isDark,
                onPressed: () {
                  setState(() {
                    isDark = !isDark;
                    widget.onThemeChanged?.call(isDark);
                  });
                },
                icon: const Icon(Icons.wb_sunny_outlined),
                selectedIcon: const Icon(Icons.brightness_2_outlined),
              ),
            )
          ],
        );
      },
      suggestionsBuilder: searchLocationSuggestionBuilder,
    );
  }

  FutureOr<Iterable<Widget>> searchLocationSuggestionBuilder(
      BuildContext context, SearchController controller) {
    return _suggestionBuilder(context, controller, onItemTap: (point) async {
      if (pickedLocation != null) {
        await mapController.removeMarker(pickedLocation!);
      }
      pickedLocation = point;

      await mapController.moveTo(point, animate: true);
      await mapController.setZoom(zoomLevel: 17);
      await mapController.addMarker(
        iconAnchor: IconAnchor(anchor: Anchor.top),
        point,
        markerIcon: const MarkerIcon(
          icon: Icon(Icons.location_pin, size: 48, color: Colors.red),
        ),
      );
    });
  }

  FutureOr<Iterable<Widget>> _suggestionBuilder(
      BuildContext context, SearchController controller,
      {Function(GeoPoint)? onItemTap}) async {
    _searchingWithQuery = controller.text;

    final List<SearchInfo> suggestions =
        await addressSuggestion(_searchingWithQuery!);

    // If another search happened after this one, throw away these options.
    // Use the previous options instead and wait for the newer request to
    // finish.
    if (_searchingWithQuery != controller.text) {
      return _lastOptions;
    }

    _lastOptions = List<ListTile>.generate(suggestions.length, (int index) {
      final SearchInfo item = suggestions[index];
      return ListTile(
        title: Text(item.address.toString()),
        onTap: () {
          controller.closeView(item.address.toString());
          onItemTap?.call(item.point!);
        },
      );
    });

    return _lastOptions;
  }

  Future<void> _drawRoad(GeoPoint start, GeoPoint end) async {
    await mapController.clearAllRoads();
    await mapController.removeMarkers(markers);
    markers.clear();

    RoadInfo roadInfo = await mapController.drawRoad(
      start,
      end,
      roadType: RoadType.car,
      roadOption: const RoadOption(
        roadBorderColor: Colors.blue,
        roadBorderWidth: 7,
        roadColor: Colors.blue,
        zoomInto: true,
      ),
    );

    final key = dotenv.env['WEATHER_API_KEY']!;
    WeatherFactory wf = WeatherFactory(key);

    for (GeoPoint point in getEquidistantValues(roadInfo.route, 5)) {
      Weather weather =
          await wf.currentWeatherByLocation(point.latitude, point.longitude);
      int? temperature = weather.temperature?.celsius?.round();
      weather.weatherIcon;

      await mapController.addMarker(point,
          markerIcon: MarkerIcon(
            iconWidget: Card(
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(
                        "https://openweathermap.org/img/wn/${weather.weatherIcon}.png"),
                    const SizedBox(width: 8),
                    Text("${temperature ?? "NaN"} °C"),
                  ],
                ),
              ),
            ),
          ));
      markers.add(point);
    }
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}

List<T> getEquidistantValues<T>(List<T> list, int count) {
  if (list.length <= count) {
    return list;
  }

  int step = (list.length - 1) ~/ (count - 1);
  return List.generate(count, (index) {
    int position = index * step;
    if (index == count - 1) {
      // Ensure the last value is the last element of the list
      return list.last;
    }
    return list[position];
  });
}
