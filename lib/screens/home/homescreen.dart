import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'favourites.dart'; // Import Favourites Screen
import 'profile.dart';  // Import Profile Screen
import '/widgets/mapbox_map_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_de_dates/screens/auth/login_page.dart';  // Import login page to redirect on logout

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _locationPermissionGranted = false;
  int _selectedIndex = 0;  // Track selected tab index
  String _mapStyle = MapboxStyles.MAPBOX_STREETS;  // Default Mapbox style

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

  // Logout the user
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    // Navigate back to login page after logging out
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  // Switch between different pages on Bottom Navigation
  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _locationPermissionGranted
            ? MapboxMapWidget(
          styleString: _mapStyle,  // Use selected map style
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
      appBar: AppBar(
        title: Text('DateFindr'),
        backgroundColor: Theme.of(context).primaryColor,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: Icon(Icons.menu),  // Hamburger menu icon
              onPressed: () {
                Scaffold.of(context).openDrawer();  // Open drawer
              },
            );
          },
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: Icon(Icons.map),
              title: Text('Reset Map Style'),
              onTap: () {
                // Reset to default Mapbox style
                setState(() {
                  _mapStyle = MapboxStyles.MAPBOX_STREETS;
                });
                Navigator.pop(context);  // Close the drawer
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: _logout,  // Call the logout function
            ),
          ],
        ),
      ),
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

