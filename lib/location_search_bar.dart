import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class LocationSearchBar extends StatefulWidget {
  final Function(bool)? onThemeChanged;

  const LocationSearchBar({super.key, this.onThemeChanged});

  @override
  State<LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends State<LocationSearchBar> {
  // The query currently being searched for. If null, there is no pending
  // request.
  String? _searchingWithQuery;

  // The most recent options received from the API.
  late Iterable<Widget> _lastOptions = <Widget>[];

  bool isDark = false;

  _LocationSearchBarState();

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(builder:
        (BuildContext context, SearchController controller) {
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
        leading: const Icon(Icons.search),
        trailing: <Widget>[
          Tooltip(
            message: 'Change brightness mode',
            child: IconButton(
              isSelected: isDark,
              onPressed: () {
                setState(() {
                  isDark = !isDark;
                  widget.onThemeChanged!(isDark);
                });
              },
              icon: const Icon(Icons.wb_sunny_outlined),
              selectedIcon: const Icon(Icons.brightness_2_outlined),
            ),
          )
        ],
      );
    }, suggestionsBuilder:
        (BuildContext context, SearchController controller) async {
      _searchingWithQuery = controller.text;

      final List<SearchInfo> suggestions =
      await addressSuggestion(_searchingWithQuery!);

      // If another search happened after this one, throw away these options.
      // Use the previous options instead and wait for the newer request to
      // finish.
      if (_searchingWithQuery != controller.text) {
        return _lastOptions;
      }

      _lastOptions =
      List<ListTile>.generate(suggestions.length, (int index) {
        final SearchInfo item = suggestions[index];
        return ListTile(
          title: Text(item.address.toString()),
          onTap: () {
            controller.closeView(item.address.toString());
          },
        );
      });

      return _lastOptions;
    });
  }
}
