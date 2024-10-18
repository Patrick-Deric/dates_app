import 'package:app_de_dates/screens/home/criar_rota.dart';
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
  int _selectedIndex = 0; // Track selected tab index
  String _mapStyle = MapboxStyles.MAPBOX_STREETS; // Default Mapbox style

  // Initial position on the map (latitude, longitude)
  final LatLng initialPosition = LatLng(
      -23.5505, -46.6333); // São Paulo, Brazil

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

  // Categories List (e.g., Romantic, Family, Cultural, First Date)
  Widget _buildCategories() {
    final categories = ["Romantic", "Family", "Cultural", "First Date"];
    String? _selectedCategory; // To keep track of the selected category

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ChoiceChip(
              label: Text(category),
              selected: _selectedCategory == category,
              selectedColor: Theme
                  .of(context)
                  .primaryColor,
              // Highlight selected chip
              labelStyle: TextStyle(
                color: _selectedCategory == category ? Colors.white : Colors
                    .black,
              ),
              onSelected: (bool isSelected) {
                setState(() {
                  if (isSelected) {
                    _selectedCategory = category;
                  }
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Search Bar Widget
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

  // Build Map and DraggableScrollableSheet
  Widget _buildMapAndMenu() {
    return Stack(
      children: [
        // Map in the background
        _locationPermissionGranted
            ? MapboxMapWidget(styleString: _mapStyle)
            : Center(child: CircularProgressIndicator()),

        // Draggable sheet for categories and search bar
        DraggableScrollableSheet(
          initialChildSize: 0.4, // Visible part initially
          minChildSize: 0.2, // Minimum size when dragged down
          maxChildSize: 0.8, // Maximum size when dragged up
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
                    SizedBox(height: 10), // Padding at the top
                    Container(
                      height: 5,
                      width: 50,
                      color: Colors.grey[300], // Drag handle
                    ),
                    SizedBox(height: 20),

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: _buildSearchBar(),
                    ),
                    SizedBox(height: 10),

                    // Categories
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: _buildCategories(),
                    ),
                    SizedBox(height: 10),

                    // Placeholder content when categories are expanded
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

  // Switch between different pages on Bottom Navigation
  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _buildMapAndMenu();
      case 1:
        return CriarRotaScreen(); // Display Map and the DraggableScrollableSheet for categories
      case 2:
        return FavouritesScreen(); // Navigate to Favourites Screen
      case 3:
        return ProfileScreen(); // Navigate to Profile Screen
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
          style: TextStyle(color: Colors
              .white), // Set text color to white for better contrast
        ),
        backgroundColor: Colors.redAccent,
        // Change this to your desired color for the app bar
        iconTheme: IconThemeData(color: Colors.white),
        // Set icon color to white for visibility
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: Icon(Icons.menu), // Hamburger menu icon
              onPressed: () {
                Scaffold.of(context).openDrawer(); // Open drawer
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
                color: Colors
                    .redAccent, // Match drawer header color with app bar
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
                // Reset to default Mapbox style
                setState(() {
                  _mapStyle = MapboxStyles.MAPBOX_STREETS;
                });
                Navigator.pop(context); // Close the drawer
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.black),
              title: Text('Logout'),
              onTap: _logout, // Call the logout function
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _buildPage(_selectedIndex), // Show selected page
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index; // Update selected index
          });
        },
        backgroundColor: Colors.white,
        // Set background color of the navbar
        selectedItemColor: Colors.redAccent,
        // Set color for the selected icon and text
        unselectedItemColor: Colors.black54,
        // Set color for unselected icons and text
        selectedIconTheme: IconThemeData(color: Colors.redAccent),
        // Set icon color for selected item
        unselectedIconTheme: IconThemeData(color: Colors.black54),
        // Set icon color for unselected items
        selectedLabelStyle: TextStyle(color: Colors.redAccent),
        // Set text color for selected item
        unselectedLabelStyle: TextStyle(color: Colors.black54),
        // Set text color for unselected items
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

