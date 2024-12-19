import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(getSystemUiOverlayStyle(context));

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoWeather',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 93, 169, 233),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late MapController mapController;
  GeoPoint? pickedLocation;

  RoadInfo? roadInfo;
  SearchInfo? routeStart;
  SearchInfo? routeEnd;

  // The query currently being searched for. If null, there is no pending
  // request.
  String? _searchingWithQuery;

  // The most recent options received from the API.
  late Iterable<Widget> _lastOptions = <Widget>[];

  List<GeoPoint> markers = List.empty(growable: true);

  final FocusNode _searchBarFocusNode = FocusNode();

  @override
  void initState() {
    mapController = MapController.customLayer(
      initMapWithUserPosition: const UserTrackingOption(
        enableTracking: true,
        unFollowUser: true,
      ),
      customTile:
          getCustomTile(url: "https://api.maptiler.com/maps/dataviz-dark/256/"),
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Transform.translate(
          offset: const Offset(0.5, 0.5),
          child: OSMFlutter(
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
                personMarker: MarkerIcon(
                  icon: Icon(
                    Icons.circle,
                    color: Theme.of(context).colorScheme.primary,
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
            onMapMoved: (region) {
              if (_searchBarFocusNode.hasFocus) _searchBarFocusNode.unfocus();
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child:
                roadInfo != null ? getRouteInfoCard() : getLocationSearchBar(),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    onPressed: () async {
                      mapController.setZoom(zoomLevel: 17);
                      mapController.currentLocation();
                    },
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
          ),
        ),
      ]),
    );
  }

  CustomTile getCustomTile({required String url}) {
    return CustomTile(
      sourceName: "maptiler",
      tileExtension: ".png",
      minZoomLevel: 2,
      maxZoomLevel: 19,
      urlsServers: [
        TileURLs(
          url: url,
          subdomains: [],
        )
      ],
      keyApi: MapEntry("key", dotenv.env['MAPTILER_API_KEY']!),
      tileSize: 256,
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
                _drawRoad(routeStart!.point!, routeEnd!.point!);
              },
              child: const Text("Go"),
            )
          ],
          systemOverlayStyle: getSystemUiOverlayStyle(context),
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
                      decoration: InputDecoration(
                        icon: Icon(
                          Icons.trip_origin,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        hintText: 'Enter start point',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(8.0),
                      ),
                      onTap: () {
                        controller.openView();
                      },
                    );
                  },
                  suggestionsBuilder:
                      (BuildContext context, SearchController controller) {
                    return _suggestionBuilder(context, controller,
                        onItemTap: (searchInfo) {
                      routeStart = searchInfo;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SearchAnchor(
                  builder: (BuildContext context, SearchController controller) {
                    return TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        icon: Icon(
                          Icons.location_on_rounded,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        hintText: 'Enter destination point',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(8.0),
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
          focusNode: _searchBarFocusNode,
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
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          )),
          trailing: pickedLocation != null
              ? <Widget>[
                  Tooltip(
                    message: "Clear",
                    child: IconButton(
                      onPressed: () {
                        if (pickedLocation != null) {
                          setState(() {
                            mapController.removeMarker(pickedLocation!);
                            pickedLocation = null;
                            controller.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
                  )
                ]
              : [],
        );
      },
      suggestionsBuilder: searchLocationSuggestionBuilder,
    );
  }

  Widget getRouteInfoCard() {
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child:
                    Row(
                      children: [
                        Chip(
                          avatar: const Icon(Icons.directions_rounded),
                          label: Text("${roadInfo!.distance!.toInt()} km"),
                        ),
                        const SizedBox(width: 16),
                        Chip(
                          avatar: const Icon(Icons.directions_car_rounded),
                          label: Text(calculateTripTime(roadInfo!.distance!, 60)),
                        ),
                      ],
                    )
                  ),
                  Container(
                    transform: Matrix4.translationValues(12, 0, 0),
                    child: IconButton(
                      onPressed: () {
                        mapController.clearAllRoads();
                        mapController.removeMarkers(markers);
                        markers.clear();

                        setState(() {
                          roadInfo = null;
                        });
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trip_origin,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      routeStart!.address.toString(),
                      overflow: TextOverflow.fade,
                      maxLines: 1,
                      softWrap: false,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      routeEnd!.address.toString(),
                      overflow: TextOverflow.fade,
                      maxLines: 1,
                      softWrap: false,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  FutureOr<Iterable<Widget>> searchLocationSuggestionBuilder(
      BuildContext context, SearchController controller) {
    final colorTertiary = Theme.of(context).colorScheme.tertiary;

    return _suggestionBuilder(context, controller,
        onItemTap: (searchInfo) async {
      if (pickedLocation != null) {
        await mapController.removeMarker(pickedLocation!);
      }
      pickedLocation = searchInfo.point;

      await mapController.moveTo(searchInfo.point!, animate: true);
      await mapController.setZoom(zoomLevel: 17);
      await mapController.addMarker(
        iconAnchor: IconAnchor(anchor: Anchor.top),
        searchInfo.point!,
        markerIcon: MarkerIcon(
          icon: Icon(
            Icons.location_pin,
            size: 48,
            color: colorTertiary,
          ),
        ),
      );
    });
  }

  FutureOr<Iterable<Widget>> _suggestionBuilder(
      BuildContext context, SearchController controller,
      {Function(SearchInfo)? onItemTap}) async {
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
          _searchBarFocusNode.unfocus();
          onItemTap?.call(item);
        },
      );
    });

    return _lastOptions;
  }

  Future<void> _drawRoad(GeoPoint start, GeoPoint end) async {
    await mapController.clearAllRoads();
    await mapController.removeMarkers(markers);
    markers.clear();

    final primaryContainer =
        mounted ? Theme.of(context).colorScheme.primaryContainer : Colors.white;

    RoadInfo roadInfo = await mapController.drawRoad(
      start,
      end,
      roadType: RoadType.car,
      roadOption: RoadOption(
        roadBorderColor: primaryContainer,
        roadBorderWidth: 10,
        roadColor: primaryContainer,
        zoomInto: true,
      ),
    );

    if (pickedLocation != null) {
      mapController.removeMarker(pickedLocation!);
    }

    setState(() {
      this.roadInfo = roadInfo;
      pickedLocation = null;
    });

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

String calculateTripTime(double distanceKm, double speedKmh) {
  if (speedKmh <= 0) {
    throw ArgumentError('Speed must be greater than 0 km/h');
  }

  // Calculate time in hours
  double timeHours = distanceKm / speedKmh;

  // Convert time to hours and minutes
  int hours = timeHours.floor();
  int minutes = ((timeHours - hours) * 60).round();

  // Return formatted string
  return '${hours}h ${minutes}m';
}

SystemUiOverlayStyle getSystemUiOverlayStyle(BuildContext context) {
  return SystemUiOverlayStyle(
    systemNavigationBarContrastEnforced: true,
    systemStatusBarContrastEnforced: true,
    statusBarColor:
        Theme.of(context).scaffoldBackgroundColor.withOpacity(0.002),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black.withOpacity(0.002),
    systemNavigationBarIconBrightness: Brightness.light,
  );
}
