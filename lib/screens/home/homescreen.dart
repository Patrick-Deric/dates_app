import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:permission_handler/permission_handler.dart' as permHandler;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../auth/login_page.dart';
import 'favourites.dart';
import 'profile.dart';
import 'criar_rota.dart';

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
  List<Map<String, dynamic>> routes = [];

  // Map of icons for each category
  final Map<String, String> categoryIcons = {
    'Date Romântico': 'assets/map_icons/heart.png',
    'Date Cultural': 'assets/map_icons/livro.png',
    'Date ao Ar Livre': 'assets/map_icons/arvore.png',
    'Date Familiar': 'assets/map_icons/familia.png',
    'Date Atividade Fisica': 'assets/map_icons/corrida.png',
    'Date Festa': 'assets/map_icons/confete.png',
  };

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _fetchRoutes();
  }

  Future<void> _requestLocationPermission() async {
    var status = await permHandler.Permission.location.status;
    if (status.isDenied) {
      status = await permHandler.Permission.location.request();
    }

    if (status.isGranted) {
      setState(() {
        _locationPermissionGranted = true;
      });
    }
  }

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
      _addRouteIcons();
    } catch (e) {
      print('Error fetching routes: $e');
    }
  }

  Future<void> _loadIconForCategory(String iconName) async {
    try {
      ByteData byteData = await rootBundle.load(iconName);
      Uint8List imageBytes = byteData.buffer.asUint8List();
      await _mapController?.addImage(iconName, imageBytes);
    } catch (e) {
      print('Error loading icon for $iconName: $e');
    }
  }

  // Add icons to the map based on route category
  void _addRouteIcons() async {
    if (_mapController == null) return;

    // Load icons for each category
    for (String icon in categoryIcons.values) {
      await _loadIconForCategory(icon);
    }

    // Display icons on the map
    for (var route in routes) {
      if (route['stops'].isNotEmpty) {
        final firstStop = route['stops'][0];
        final category = route['category'] ?? 'default';
        final iconImage = categoryIcons[category] ?? 'assets/map_icons/default.png';

        if (firstStop['lat'] != null && firstStop['lng'] != null) {
          _mapController?.addSymbol(
            SymbolOptions(
              geometry: LatLng(firstStop['lat'], firstStop['lng']),
              iconImage: iconImage,
              iconSize: 2.0,
            ),
          );
        }
      }
    }
  }

  void _onIconTapped(Map<String, dynamic> route) {
    if (route.isNotEmpty) {
      _drawRouteOnMap(route['stops']);
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: route['stops'].length,
                      itemBuilder: (context, index) {
                        var stop = route['stops'][index];
                        return ListTile(
                          title: Text(stop['name'], style: TextStyle(color: Colors.white)),
                          subtitle: Text(
                              'Lat: ${stop['lat']}, Lng: ${stop['lng']}', style: TextStyle(color: Colors.white70)),
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
    }
  }

  void _drawRouteOnMap(List<dynamic> stops) {
    _mapController?.clearSymbols();

    for (var stop in stops) {
      _mapController?.addSymbol(SymbolOptions(
        geometry: LatLng(stop['lat'], stop['lng']),
        iconImage: 'assets/map_icons/heart.png', // Change the icon if needed based on stop
        iconSize: 1.5,
      ));
    }
  }

  List<Widget> _buildNearbyRoutesCards() {
    if (routes.isEmpty) return [];
    return routes.where((route) {
      final firstStop = route['stops'][0];
      final distance = _calculateDistance(
        initialPosition,
        LatLng(firstStop['lat'], firstStop['lng']),
      );
      return distance <= 15;
    }).map((route) {
      var duration = (route['duration'] ?? 0) / 60;
      return Card(
        margin: EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        child: ListTile(
          leading: Icon(Icons.date_range, color: Colors.redAccent),
          title: Text(route['stops'][0]['name']),
          subtitle: Text(
            'Stops: ${route['stops'].length}, Duration: ${duration.toStringAsFixed(0)} mins',
          ),
          trailing: Icon(Icons.arrow_forward),
          onTap: () => _onIconTapped(route),
        ),
      );
    }).toList();
  }

  double _calculateDistance(LatLng pos1, LatLng pos2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((pos2.latitude - pos1.latitude) * p) / 2 +
        cos(pos1.latitude * p) * cos(pos2.latitude * p) *
            (1 - cos((pos2.longitude - pos1.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a)); // Distance in km
  }

  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
    _addRouteIcons();

    _mapController?.onSymbolTapped.add((symbol) {
      final geometry = symbol.options.geometry;
      if (geometry != null) {
        for (var route in routes) {
          final firstStop = route['stops'][0];
          if (firstStop['lat'] == geometry.latitude && firstStop['lng'] == geometry.longitude) {
            _onIconTapped(route);
            break;
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

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      print('Error logging out: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao fazer logout.')));
    }
  }

  Widget _buildCategories() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ["Romantic", "Family", "Cultural", "First Date"].map((category) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ChoiceChip(
                  label: Text(category),
                  selected: false,
                  selectedColor: Theme.of(context).primaryColor,
                  labelStyle: TextStyle(color: Colors.black),
                  onSelected: (_) {},
                ),
              );
            }).toList(),
          ),
        ),
        ..._buildNearbyRoutesCards(),
      ],
    );
  }

  Widget _buildMapAndMenu() {
    return Stack(
      children: [
        _locationPermissionGranted
            ? MapboxMap(
          accessToken: 'sk.eyJ1IjoicGF0cmlja2RlcmljIiwiYSI6ImNtMmo1bHY4ZDAxemoya3B4eWdjYjd4bjYifQ.ie9qwYOo7bEjjNFiAGxp2g',
          styleString: _mapStyle,
          initialCameraPosition: CameraPosition(target: initialPosition, zoom: 12),
          onMapCreated: _onMapCreated,
          myLocationEnabled: true,
          myLocationTrackingMode: MyLocationTrackingMode.Tracking,
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
                    Container(height: 5, width: 50, color: Colors.grey[300]),
                    SizedBox(height: 20),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 20.0), child: _buildSearchBar()),
                    SizedBox(height: 10),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: _buildCategories()),
                    SizedBox(height: 10),
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
        title: Text('DateFindr', style: TextStyle(color: Colors.white)),
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
              decoration: BoxDecoration(color: Colors.redAccent),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
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
      body: SafeArea(child: _buildPage(_selectedIndex)),
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
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Explorar'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Criar Date'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoritos'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
