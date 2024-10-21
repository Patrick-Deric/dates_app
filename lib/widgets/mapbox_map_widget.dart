import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:permission_handler/permission_handler.dart';

class MapboxMapWidget extends StatefulWidget {
  final String styleString;

  MapboxMapWidget({required this.styleString});

  @override
  _MapboxMapWidgetState createState() => _MapboxMapWidgetState();
}

class _MapboxMapWidgetState extends State<MapboxMapWidget> {
  MapboxMapController? _mapController;  // Make the controller nullable
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
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: _locationPermissionGranted
          ? MapboxMap(
        accessToken: 'sk.eyJ1IjoicGF0cmlja2RlcmljIiwiYSI6ImNtMmo1bHY4ZDAxemoya3B4eWdjYjd4bjYifQ.ie9qwYOo7bEjjNFiAGxp2g',
        styleString: widget.styleString,
        initialCameraPosition: CameraPosition(
          target: LatLng(37.7749, -122.4194),  // Example coordinates
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
    // Check if _mapController is initialized before calling dispose
    if (_mapController != null) {
      _mapController!.dispose();
      _mapController = null;  // Set to null after disposal
    }
    super.dispose();
  }
}

