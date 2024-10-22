import 'package:flutter/material.dart';
import 'package:app_de_dates/widgets/mapbox_map_widget.dart'; // Import your Mapbox widget
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class MapVisualizationScreen extends StatefulWidget {
  final String routeId; // Pass the route ID to retrieve the route from Firestore

  MapVisualizationScreen({required this.routeId});

  @override
  _MapVisualizationScreenState createState() => _MapVisualizationScreenState();
}

class _MapVisualizationScreenState extends State<MapVisualizationScreen> {
  List<Map<String, dynamic>> routeStops = []; // Store stops from Firestore
  bool isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    _loadRoute(); // Load the route when the screen initializes
  }

  // Function to load the route from Firestore
  Future<void> _loadRoute() async {
    try {
      // Fetch the route document from Firestore using the routeId
      DocumentSnapshot routeDoc = await FirebaseFirestore.instance
          .collection('routes')
          .doc(widget.routeId)
          .get();

      if (routeDoc.exists) {
        // Extract stops from the route document
        List<dynamic> stops = routeDoc['stops'];

        setState(() {
          routeStops = List<Map<String, dynamic>>.from(stops);
          isLoading = false; // Set loading to false once the route is loaded
        });
      } else {
        print('Route not found');
        setState(() {
          isLoading = false; // Stop loading even if route is not found
        });
      }
    } catch (e) {
      print('Error loading route: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Visualizar Rota'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Go back to the previous page
          },
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading indicator while fetching route
          : Center(
        child: routeStops.isNotEmpty
            ? MapboxMapWidget(
          styleString: 'mapbox://styles/mapbox/streets-v11',
          initialLat: routeStops.first['lat'] ?? -23.5505,  // Default to São Paulo
          initialLng: routeStops.first['lng'] ?? -46.6333,  // Default to São Paulo
          selectedStops: routeStops,  // Pass the loaded stops to the map
        )
            : Text('Nenhuma parada selecionada'), // Display if no stops are found
      ),
    );
  }
}

