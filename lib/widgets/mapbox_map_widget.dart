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

  MapboxMapWidget({
    required this.styleString,
    required this.initialLat,
    required this.initialLng,
    required this.selectedStops,
  });

  @override
  _MapboxMapWidgetState createState() => _MapboxMapWidgetState();
}

class _MapboxMapWidgetState extends State<MapboxMapWidget> {
  MapboxMapController? _mapController;
  bool _locationPermissionGranted = false;
  String? distanceText; // To store the distance
  String? durationText; // To store the duration

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

  Future<void> _loadCustomMarker() async {
    ByteData byteData = await rootBundle.load('assets/map_icons/custom-marker.png');
    Uint8List imageBytes = byteData.buffer.asUint8List();
    if (_mapController != null) {
      await _mapController!.addImage('custom-marker', imageBytes);
    }
  }

  void _onMapCreated(MapboxMapController controller) async {
    _mapController = controller;
    print('Map created successfully');

    await _loadCustomMarker();  // Load the custom marker icon
    _addStopMarkers();  // Add markers once the map is created
    _fetchAndDrawRoute();  // Fetch route and draw it on the map
  }

  // Add markers for the selected stops
  void _addStopMarkers() {
    if (_mapController != null && widget.selectedStops.isNotEmpty) {
      for (var stop in widget.selectedStops) {
        final lat = stop['lat'];
        final lng = stop['lng'];

        if (lat != null && lng != null) {
          print('Adding marker: ${stop['name']}');
          try {
            _mapController!.addSymbol(SymbolOptions(
              geometry: LatLng(lat, lng),
              iconImage: 'custom-marker',
              iconSize: 2.0,
              textField: stop['name'],
              textOffset: Offset(0, 1.5),
            ));
          } catch (e) {
            print('Error adding marker for ${stop['name']}: $e');
          }
        } else {
          print('Error: Lat/Lng is null for stop: ${stop['name']}');
        }
      }

      if (widget.selectedStops.isNotEmpty) {
        var firstStop = widget.selectedStops.first;
        final lat = firstStop['lat'];
        final lng = firstStop['lng'];
        if (lat != null && lng != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(
            LatLng(lat, lng),
          ));
        }
      }
    }
  }

  // Fetch route data and draw it on the map
  Future<void> _fetchAndDrawRoute() async {
    String coordinates = '';
    for (var stop in widget.selectedStops) {
      coordinates += '${stop['lng']},${stop['lat']};';
    }
    coordinates = coordinates.substring(0, coordinates.length - 1); // Remove the last semicolon

    final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/$coordinates'
        '?geometries=geojson&access_token=sk.eyJ1IjoicGF0cmlja2RlcmljIiwiYSI6ImNtMmo1bHY4ZDAxemoya3B4eWdjYjd4bjYifQ.ie9qwYOo7bEjjNFiAGxp2g'; // Replace with your Mapbox token

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Extract the route geometry
      final geometry = data['routes'][0]['geometry'];
      final distance = data['routes'][0]['distance'];
      final duration = data['routes'][0]['duration'];

      // Convert distance to km and duration to minutes
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

          LatLngBounds bounds = _boundsFromLatLngList(routePoints);
          _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds));
        } catch (e) {
          print('Error drawing route: $e');
        }
      }
    } else {
      print('Failed to load directions');
    }
  }

  // Calculate LatLngBounds from a list of LatLng
  LatLngBounds _boundsFromLatLngList(List<LatLng> points) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in points) {
      if (x0 == null || latLng.latitude > x0) x0 = latLng.latitude;
      if (x1 == null || latLng.latitude < x1) x1 = latLng.latitude;
      if (y0 == null || latLng.longitude > y0) y0 = latLng.longitude;
      if (y1 == null || latLng.longitude < y1) y1 = latLng.longitude;
    }
    return LatLngBounds(southwest: LatLng(x1!, y1!), northeast: LatLng(x0!, y0!));
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
            accessToken: 'sk.eyJ1IjoicGF0cmlja2RlcmljIiwiYSI6ImNtMmo1bHY4ZDAxemoya3B4eWdjYjd4bjYifQ.ie9qwYOo7bEjjNFiAGxp2g', // Replace with your token
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
        if (distanceText != null && durationText != null) ...[
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
      ],
    );
  }

  @override
  void dispose() {
    if (_mapController != null) {
      _mapController!.dispose();
      _mapController = null;
    }
    super.dispose();
  }
}






