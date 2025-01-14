import 'dart:math';
import 'package:app_de_dates/screens/home/stop_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:permission_handler/permission_handler.dart' as permHandler;
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';
import 'Route_visualization.dart';
import 'favourites.dart';
import 'profile.dart';
import 'criar_rota.dart';
import 'package:url_launcher/url_launcher.dart'; // For Google Maps link


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
  String selectedFilter = 'Todos';

  // Icons based on categories
  final Map<String, String> categoryIcons = {
    'Date Romântico': 'assets/map_icons/heart.png',
    'Date Cultural': 'assets/map_icons/livro.png',
    'Date ao Ar Livre': 'assets/map_icons/arvore.png',
    'Date Familiar': 'assets/map_icons/familia.png',
    'Date Atividade Fisica': 'assets/map_icons/corrida.png',
    'Date Festa': 'assets/map_icons/confete.png',
  };

  final List<String> filters = [
    'Todos',
    'Date Romântico',
    'Date Cultural',
    'Date ao Ar Livre',
    'Date Familiar',
    'Date Atividade Fisica',
    'Date Festa',
  ];

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

  void _addRouteIcons() async {
    if (_mapController == null) return;

    for (String icon in categoryIcons.values) {
      await _loadIconForCategory(icon);
    }

    for (var route in routes) {
      if (route['stops'].isNotEmpty) {
        for (var stop in route['stops']) {
          final category = route['category'] ?? 'Todos';
          final iconImage = categoryIcons[category] ?? 'assets/map_icons/default.png';

          if (stop['lat'] != null && stop['lng'] != null) {
            _mapController?.addSymbol(
              SymbolOptions(
                geometry: LatLng(stop['lat'], stop['lng']),
                iconImage: iconImage,
                iconSize: 2.0,
              ),
            );
          }
        }
      }
    }
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

  void _showRouteVisualization(String routeId) {
    print('Navigating to visualization for route ID: $routeId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapVisualizationScreen(routeId: routeId),
      ),
    );
  }

  void _openStopDetails(Map<String, dynamic> stop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StopDetailsScreen(stop: stop),
      ),
    );
  }


  List<Widget> _buildNearbyRoutesCards() {
    if (routes.isEmpty) {
      return [Text('Nenhuma rota encontrada.', style: TextStyle(color: Colors.grey))];
    }

    final filteredRoutes = routes.where((route) {
      final category = route['category'] ?? 'Todos';
      return selectedFilter == 'Todos' || category == selectedFilter;
    }).toList();

    if (filteredRoutes.isEmpty) {
      return [Text('Nenhuma rota encontrada para o filtro selecionado.', style: TextStyle(color: Colors.grey))];
    }

    return filteredRoutes.map((route) {
      // Get the icon for the route's category
      final category = route['category'] ?? 'Todos';
      final iconPath = categoryIcons[category] ?? 'assets/map_icons/default.png';

      return Card(
        margin: EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        child: ListTile(
          leading: Image.asset(
            iconPath,
            width: 40,
            height: 40,
          ),
          title: Text(route['stops'][0]['name']),
          subtitle: Text('Categoria: ${route['category']}'),
          trailing: IconButton(
            icon: Icon(Icons.arrow_forward),
            onPressed: () => _openStopDetails(route['stops'][0]),
          ),
          onTap: () => _showRouteVisualization(route['id']),
        ),
      );
    }).toList();
  }


  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
    _addRouteIcons();

    _mapController?.onSymbolTapped.add((symbol) {
      final geometry = symbol.options.geometry;
      if (geometry != null) {
        const double tolerance = 0.0001;
        for (var route in routes) {
          if (route['stops'] != null && route['stops'].isNotEmpty) {
            for (var stop in route['stops']) {
              if ((stop['lat'] - geometry.latitude).abs() < tolerance &&
                  (stop['lng'] - geometry.longitude).abs() < tolerance) {
                _openStopDetails(stop);
                return;
              }
            }
          }
        }
        print('No matching stop found for symbol at ${geometry.latitude}, ${geometry.longitude}');
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

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ChoiceChip(
              label: Text(filter),
              selected: selectedFilter == filter,
              selectedColor: Colors.redAccent,
              onSelected: (bool selected) {
                setState(() {
                  selectedFilter = selected ? filter : 'Todos';
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      children: [
        _buildFilters(),
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
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
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
