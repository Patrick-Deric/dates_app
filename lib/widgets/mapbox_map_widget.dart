import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:permission_handler/permission_handler.dart';

class MapboxMapWidget extends StatefulWidget {
  final String styleString;  // Accept the styleString as a parameter

  MapboxMapWidget({required this.styleString});

  @override
  _MapboxMapWidgetState createState() => _MapboxMapWidgetState();
}

class _MapboxMapWidgetState extends State<MapboxMapWidget> {
  late MapboxMapController _mapController;
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  // Request location permissions
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

  // Initialize the map controller
  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: _locationPermissionGranted
          ? MapboxMap(
        accessToken: 'sk.eyJ1IjoicGF0cmlja2RlcmljIiwiYSI6ImNtMmF0M29mNTBqcmQyaW94Y2hpcXBvd3MifQ.jjuflSQNzTpkhG0Wo3FB2g',  // Replace with your access token
        styleString: widget.styleString,  // Use the passed styleString
        initialCameraPosition: CameraPosition(
          target: LatLng(37.7749, -122.4194),  // Example coordinates for San Francisco
          zoom: 10,
        ),
        onMapCreated: _onMapCreated,
        myLocationEnabled: true,
        myLocationTrackingMode: MyLocationTrackingMode.Tracking,
      )
          : Center(child: CircularProgressIndicator()),  // Show loading while waiting for permission
    );
  }

  @override
  void dispose() {
    if (_mapController != null) {
      _mapController.dispose();
    }
    super.dispose();
  }
}

