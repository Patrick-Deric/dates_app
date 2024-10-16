import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'favourites.dart'; // Import Favourites Screen
import 'profile.dart';  // Import Profile Screen
import '/widgets/mapbox_map_widget.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _locationPermissionGranted = false;
  int _selectedIndex = 0;  // Track selected tab index

  // Initial position on the map (latitude, longitude)
  final LatLng initialPosition = LatLng(-23.5505, -46.6333);  // São Paulo, Brazil

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  // Request location permission
  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.status;
    if (status.isGranted) {
      setState(() {
        _locationPermissionGranted = true;
      });
    } else if (status.isDenied || status.isPermanentlyDenied) {
      final result = await Permission.location.request();
      if (result.isGranted) {
        setState(() {
          _locationPermissionGranted = true;
        });
      } else {
        print('Location permission denied');
      }
    }
  }

  // Switch between different pages on Bottom Navigation
  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _locationPermissionGranted
            ? MapboxMapWidget(
          styleString: 'mapbox://styles/patrickderic/cm2bxbfxm000401qsd90u9wpe',
        )
            : Center(child: CircularProgressIndicator());
      case 1:
        return FavouritesScreen();  // Navigate to Favourites Screen
      case 2:
        return ProfileScreen();  // Navigate to Profile Screen
      default:
        return Center(child: Text('Unknown Page'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _buildPage(_selectedIndex),  // Show selected page
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;  // Update selected index
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Explorar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
