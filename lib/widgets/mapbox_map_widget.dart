import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapboxMapWidget extends StatefulWidget {
  final String styleString;
  final double initialLat;
  final double initialLng;
  final List<Map<String, dynamic>> selectedStops;
  final void Function(Map<String, dynamic>) onStopTap; // Callback for stop taps

  MapboxMapWidget({
    required this.styleString,
    required this.initialLat,
    required this.initialLng,
    required this.selectedStops,
    required this.onStopTap,
  });

  @override
  _MapboxMapWidgetState createState() => _MapboxMapWidgetState();
}

class _MapboxMapWidgetState extends State<MapboxMapWidget> {
  MapboxMapController? _mapController;
  bool _locationPermissionGranted = false;
  String? distanceText;
  String? durationText;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    if (await Permission.location.isGranted) {
      setState(() {
        _locationPermissionGranted = true;
      });
    } else {
      final status = await Permission.location.request();
      if (status.isGranted) {
        setState(() {
          _locationPermissionGranted = true;
        });
      } else {
        print('Location permission denied');
      }
    }
  }

  Future<void> _loadNumberedIcons() async {
    for (int i = 0; i < widget.selectedStops.length; i++) {
      final iconName = 'number_${i + 1}';
      final iconPath = 'assets/number_map_icons/${_numberToWord(i + 1)}.png';
      try {
        ByteData byteData = await rootBundle.load(iconPath);
        Uint8List imageBytes = byteData.buffer.asUint8List();
        await _mapController?.addImage(iconName, imageBytes);
      } catch (e) {
        print('Error loading icon for stop ${i + 1}: $e');
      }
    }
  }

  String _numberToWord(int number) {
    switch (number) {
      case 1:
        return 'one';
      case 2:
        return 'two';
      case 3:
        return 'three';
      case 4:
        return 'four';
      case 5:
        return 'five';
      default:
        throw ArgumentError('Unsupported stop number: $number');
    }
  }

  void _onMapCreated(MapboxMapController controller) async {
    _mapController = controller;

    await _loadNumberedIcons(); // Load numbered icons
    _addStopMarkers(); // Add markers with text
    await _fetchAndDrawRoute(); // Draw the route line

    _mapController!.onSymbolTapped.add((Symbol symbol) {
      final symbolLat = symbol.options.geometry?.latitude;
      final symbolLng = symbol.options.geometry?.longitude;

      for (var stop in widget.selectedStops) {
        if (stop['lat'] == symbolLat && stop['lng'] == symbolLng) {
          widget.onStopTap(stop); // Trigger the onStopTap callback
          break;
        }
      }
    });
  }

  void _addStopMarkers() {
    if (_mapController != null && widget.selectedStops.isNotEmpty) {
      for (int i = 0; i < widget.selectedStops.length; i++) {
        final stop = widget.selectedStops[i];
        final lat = stop['lat'];
        final lng = stop['lng'];
        final iconName = 'number_${i + 1}';

        if (lat != null && lng != null) {
          try {
            _mapController!.addSymbol(SymbolOptions(
              geometry: LatLng(lat, lng),
              iconImage: iconName,
              iconSize: 2.5,
              textField: stop['name'] ?? '',
              textOffset: Offset(0, 2.0),
              textColor: '#000000',
              textSize: 14.0,
              textHaloColor: '#FFFFFF',
              textHaloWidth: 1.5,
            ));
          } catch (e) {
            print('Error adding marker for stop ${i + 1}: $e');
          }
        }
      }

      if (widget.selectedStops.isNotEmpty) {
        final firstStop = widget.selectedStops.first;
        final lat = firstStop['lat'];
        final lng = firstStop['lng'];
        if (lat != null && lng != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
        }
      }
    }
  }

  Future<void> _fetchAndDrawRoute() async {
    try {
      String coordinates = widget.selectedStops
          .map((stop) => '${stop['lng']},${stop['lat']}')
          .join(';');

      final url =
          'https://api.mapbox.com/directions/v5/mapbox/driving/$coordinates'
          '?geometries=geojson&access_token=sk.eyJ1IjoicGF0cmlja2RlcmljIiwiYSI6ImNtMmo1bHY4ZDAxemoya3B4eWdjYjd4bjYifQ.ie9qwYOo7bEjjNFiAGxp2g';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['routes'][0]['geometry'];
        final distance = data['routes'][0]['distance'];
        final duration = data['routes'][0]['duration'];

        setState(() {
          distanceText = '${(distance / 1000).toStringAsFixed(2)} km';
          durationText = '${(duration / 60).toStringAsFixed(0)} min';
        });

        final List<LatLng> routePoints = (geometry['coordinates'] as List)
            .map((point) => LatLng(point[1], point[0]))
            .toList();

        if (routePoints.isNotEmpty) {
          try {
            _mapController!.addLine(LineOptions(
              geometry: routePoints,
              lineColor: '#ff0000',
              lineWidth: 5.0,
              lineOpacity: 0.8,
            ));
          } catch (e) {
            print('Error adding route line: $e');
          }

          LatLngBounds bounds = _boundsFromLatLngList(routePoints);
          _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds));
        }
      } else {
        print('Failed to fetch directions: ${response.body}');
      }
    } catch (e) {
      print('Error fetching directions: $e');
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> points) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in points) {
      if (x0 == null || latLng.latitude > x0) x0 = latLng.latitude;
      if (x1 == null || latLng.latitude < x1) x1 = latLng.latitude;
      if (y0 == null || latLng.longitude > y0) y0 = latLng.longitude;
      if (y1 == null || latLng.longitude < y1) y1 = latLng.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(x1!, y1!),
      northeast: LatLng(x0!, y0!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: _locationPermissionGranted
              ? MapboxMap(
            accessToken: 'sk.eyJ1IjoicGF0cmlja2RlcmljIiwiYSI6ImNtMmo1bHY4ZDAxemoya3B4eWdjYjd4bjYifQ.ie9qwYOo7bEjjNFiAGxp2g',
            styleString: widget.styleString,
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.initialLat, widget.initialLng),
              zoom: 12,
            ),
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.Tracking,
          )
              : Center(child: CircularProgressIndicator()),
        ),
        if (distanceText != null && durationText != null)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    'Distância: $distanceText',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    'Duração: $durationText',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
