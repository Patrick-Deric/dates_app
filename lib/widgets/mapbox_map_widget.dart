import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:permission_handler/permission_handler.dart';

class MapboxMapWidget extends StatefulWidget {
  final String styleString;
  final double initialLat; // Latitude to center the map
  final double initialLng; // Longitude to center the map
  final List<Map<String, dynamic>> selectedStops; // List of stops to add markers for

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
  MapboxMapController? _mapController; // Make the controller nullable
  bool _locationPermissionGranted = false;

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

  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
    _addStopMarkers(); // Add markers once the map is created
  }

  // Function to add markers for the selected stops
  void _addStopMarkers() {
    if (_mapController != null) {
      for (var stop in widget.selectedStops) {
        _mapController!.addSymbol(SymbolOptions(
          geometry: LatLng(stop['lat'], stop['lng']),
          iconImage: 'marker-15', // Default marker icon
          iconSize: 2.0,
          textField: stop['name'],
          textOffset: Offset(0, 1.5),
        ));
      }

      // Center the map on the first stop if any stop exists
      if (widget.selectedStops.isNotEmpty) {
        var firstStop = widget.selectedStops.first;
        _mapController!.animateCamera(CameraUpdate.newLatLng(
          LatLng(firstStop['lat'], firstStop['lng']),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: _locationPermissionGranted
          ? MapboxMap(
        accessToken: 'YOUR_MAPBOX_ACCESS_TOKEN', // Replace with your token
        styleString: widget.styleString,
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.initialLat, widget.initialLng), // Center on initialLat and initialLng
          zoom: 12, // Initial zoom level
        ),
        onMapCreated: _onMapCreated,
        myLocationEnabled: true,
        myLocationTrackingMode: MyLocationTrackingMode.Tracking,
      )
          : Center(child: CircularProgressIndicator()), // Show loading while waiting for permission
    );
  }

  @override
  void dispose() {
    if (_mapController != null) {
      _mapController!.dispose();
      _mapController = null; // Set to null after disposal
    }
    super.dispose();
  }
}

