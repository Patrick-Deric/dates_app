import 'package:app_de_dates/screens/home/criar_rota.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_page.dart';
import 'favourites.dart';
import 'profile.dart';
import '/widgets/mapbox_map_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';  // Added Geolocator for user location
import 'package:flutter/services.dart';
import 'dart:typed_data';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _locationPermissionGranted = false;
  int _selectedIndex = 0;
  String _mapStyle = MapboxStyles.MAPBOX_STREETS;
  LatLng initialPosition = LatLng(-23.5505, -46.6333); // São Paulo coordinates by default
  MapboxMapController? _mapController;
  List<Map<String, dynamic>> routes = []; // Store fetched routes

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _fetchRoutes();  // Fetch routes from Firestore
  }

  // Fetch the user's current location and set initial map position
  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.status;
    if (status.isGranted) {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _locationPermissionGranted = true;
        initialPosition = LatLng(position.latitude, position.longitude);  // Set initial position to user's location
      });
    } else if (status.isDenied || status.isPermanentlyDenied) {
      final result = await Permission.location.request();
      if (result.isGranted) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

        setState(() {
          _locationPermissionGranted = true;
          initialPosition = LatLng(position.latitude, position.longitude);  // Set initial position to user's location
        });
      } else {
        print('Location permission denied');
      }
    }
  }

  // Fetch routes from Firestore and store them
  Future<void> _fetchRoutes() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('routes').get();

      setState(() {
        routes = querySnapshot.docs.map((doc) {
          Map<String, dynamic> routeData = doc.data() as Map<String, dynamic>;
          routeData['id'] = doc.id;
          return routeData;
        }).toList();
      });
      print('Routes fetched successfully');
    } catch (e) {
      print('Error fetching routes: $e');
    }
  }

  // Ensure custom heart icon is loaded
  Future<void> _loadCustomHeartIcon() async {
    try {
      ByteData byteData = await rootBundle.load('assets/map_icons/heart.png');
      Uint8List imageBytes = byteData.buffer.asUint8List();
      await _mapController?.addImage('heart-icon', imageBytes);
    } catch (e) {
      print('Error loading heart icon: $e');
    }
  }

  // Add heart icon for each route at the first stop
  void _addRouteIcons() async {
    if (_mapController == null) return; // Make sure map controller is initialized

    // Load custom heart icon before adding symbols
    await _loadCustomHeartIcon();

    for (var route in routes) {
      if (route['stops'].isNotEmpty) {
        final firstStop = route['stops'][0]; // First stop of the route
        final lat = firstStop['lat'];
        final lng = firstStop['lng'];

        if (lat != null && lng != null) {
          try {
            _mapController?.addSymbol(SymbolOptions(
              geometry: LatLng(lat, lng),
              iconImage: 'heart-icon',  // Use loaded heart icon
              iconSize: 2.0,
            ));
          } catch (e) {
            print('Error adding symbol: $e');
          }
        }
      }
    }
  }

  // Handle tap on the heart icon to show the custom-designed box with route info
  void _onIconTapped(Map<String, dynamic> route) {
    if (route.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            height: 300,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/love_box.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Date Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10),
                  // Display route stops
                  Expanded(
                    child: ListView.builder(
                      itemCount: route['stops'].length,
                      itemBuilder: (context, index) {
                        var stop = route['stops'][index];
                        return ListTile(
                          title: Text(
                            stop['name'],
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Lat: ${stop['lat']}, Lng: ${stop['lng']}',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      print('No route information available.');
    }
  }

  // Map creation callback
  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
    _addRouteIcons();  // Add heart icons for routes

    // Set up the symbol tap listener
    _mapController?.onSymbolTapped.add((symbol) {
      final geometry = symbol.options.geometry;
      if (geometry != null) {
        // Find the route associated with the tapped symbol (heart icon)
        for (var route in routes) {
          final firstStop = route['stops'][0];
          if (firstStop['lat'] == geometry.latitude && firstStop['lng'] == geometry.longitude) {
            _onIconTapped(route);  // Show route info in the custom box
            break; // Stop the loop once the route is found
          }
        }
      }
    });
  }





  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.0),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10.0)],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey),
          SizedBox(width: 8.0),
          Text("Para onde?", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final categories = ["Romantic", "Family", "Cultural", "First Date"];
    String? _selectedCategory;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ChoiceChip(
              label: Text(category),
              selected: _selectedCategory == category,
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: _selectedCategory == category ? Colors.white : Colors.black,
              ),
              onSelected: (bool isSelected) {
                setState(() {
                  _selectedCategory = isSelected ? category : null;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Logout function
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  Widget _buildMapAndMenu() {
    return Stack(
      children: [
        _locationPermissionGranted
            ? MapboxMap(
          accessToken: 'sk.eyJ1IjoicGF0cmlja2RlcmljIiwiYSI6ImNtMmo1bHY4ZDAxemoya3B4eWdjYjd4bjYifQ',
          styleString: _mapStyle,
          initialCameraPosition: CameraPosition(
            target: initialPosition,
            zoom: 12,
          ),
          onMapCreated: _onMapCreated,
        )
            : Center(child: CircularProgressIndicator()),

        DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Container(
                      height: 5,
                      width: 50,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: _buildSearchBar(),
                    ),
                    SizedBox(height: 10),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: _buildCategories(),
                    ),
                    SizedBox(height: 10),

                    Container(
                      height: 200,
                      child: Center(
                        child: Text("Browse date ideas here"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _buildMapAndMenu();
      case 1:
        return CreateDateScreen();
      case 2:
        return FavouritesScreen();
      case 3:
        return ProfileScreen();
      default:
        return Center(child: Text('Unknown Page'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DateFindr',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        iconTheme: IconThemeData(color: Colors.white),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
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
                color: Colors.redAccent,
              ),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: Icon(Icons.map, color: Colors.black),
              title: Text('Reset Map Style'),
              onTap: () {
                setState(() {
                  _mapStyle = MapboxStyles.MAPBOX_STREETS;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.black),
              title: Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _buildPage(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.black54,
        selectedIconTheme: IconThemeData(color: Colors.redAccent),
        unselectedIconTheme: IconThemeData(color: Colors.black54),
        selectedLabelStyle: TextStyle(color: Colors.redAccent),
        unselectedLabelStyle: TextStyle(color: Colors.black54),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Explorar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Criar Date',
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



