import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; // For location access
import 'package:mapbox_gl/mapbox_gl.dart'; // For map view after route creation

class CreateDateScreen extends StatefulWidget {
  @override
  _CreateDateScreenState createState() => _CreateDateScreenState();
}

class _CreateDateScreenState extends State<CreateDateScreen> {
  List<Map<String, dynamic>> selectedStops = []; // Store selected stops
  List<Map<String, dynamic>> searchResults = []; // Store search results
  bool _isRouteCreated = false; // To track if the route is created
  String apiKey = 'AIzaSyA3Z3QuTeYR2WTtDu1Aj1H5XKaoWM8TqHk'; // Google Places API Key
  Position? _userLocation; // Store user's current location

  // Fetch user's location to limit search results
  Future<void> _getUserLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _userLocation = position;
    });
  }

  @override
  void initState() {
    super.initState();
    _getUserLocation(); // Fetch user's current location on start
  }

  // Function to handle search with distance restriction
  void _performSearch(String query) async {
    setState(() {
      searchResults.clear();
    });

    // Step 1: Check Firestore for custom businesses
    var firestoreResults = await FirebaseFirestore.instance
        .collection('businesses')
        .where('businessName', isGreaterThanOrEqualTo: query)
        .where('businessName', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    if (firestoreResults.docs.isNotEmpty) {
      firestoreResults.docs.forEach((doc) {
        searchResults.add({
          'name': doc['businessName'],
          'address': doc['address'],
          'location': doc['geolocation'],
          'source': 'firestore',
        });
      });
    }

    // Step 2: Query Google Places API for nearby places
    if (searchResults.isEmpty && _userLocation != null) {
      var googlePlacesResults = await _fetchGooglePlaces(query);
      googlePlacesResults.forEach((place) {
        searchResults.add({
          'name': place['description'],
          'placeId': place['place_id'],
          'source': 'google',
        });
      });
    }

    setState(() {});
  }

  // Fetch results from Google Places API with location and radius
  Future<List<dynamic>> _fetchGooglePlaces(String query) async {
    if (_userLocation == null) return [];

    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&location=${_userLocation!.latitude},${_userLocation!.longitude}&radius=40000&key=$apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      return data['predictions'];
    } else {
      throw Exception('Failed to load places');
    }
  }

  // Fetch place details from Google Places
  Future<Map<String, dynamic>> _fetchPlaceDetails(String placeId) async {
    String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      var location = data['result']['geometry']['location'];
      return {
        'name': data['result']['name'],
        'address': data['result']['formatted_address'],
        'lat': location['lat'],
        'lng': location['lng'],
      };
    } else {
      throw Exception('Failed to load place details');
    }
  }

  // Handle stop selection
  void _selectStop(Map<String, dynamic> stop) async {
    if (selectedStops.length < 5) {
      if (stop['source'] == 'google') {
        var details = await _fetchPlaceDetails(stop['placeId']);
        stop.addAll(details); // Add details to the stop
      }
      setState(() {
        selectedStops.add(stop);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Você só pode adicionar até 5 paradas.')));
    }
  }

  // Build search results
  Widget _buildSearchResults() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        var result = searchResults[index];
        return ListTile(
          title: Text(result['name']),
          subtitle: Text(result['source'] == 'firestore'
              ? result['address']
              : 'Resultado do Google'),
          onTap: () {
            _selectStop(result);
          },
        );
      },
    );
  }

  // Build selected stops
  Widget _buildSelectedStops() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: selectedStops.map((stop) {
        return ListTile(
          title: Text(stop['name']),
          subtitle: stop['source'] == 'firestore'
              ? Text(stop['address'])
              : Text('Google Place'),
        );
      }).toList(),
    );
  }

  // Submit Button (for saving the route to Firestore)
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: () {
        if (selectedStops.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Por favor, selecione pelo menos uma parada.')));
          return;
        }
        setState(() {
          _isRouteCreated = true; // Indicate that the route is created
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rota criada com sucesso!')));
      },
      child: Text('Criar Rota'),
    );
  }

  // Show map once the route is created (initially collapsed)
  Widget _buildMapView() {
    return _isRouteCreated
        ? GestureDetector(
      onTap: () {
        // Logic to expand the map and show the full route
      },
      child: Container(
        height: 200, // Collapsed map height
        color: Colors.grey[200],
        child: Center(
          child: Text('Visualizar Rota no Mapa'),
        ),
      ),
    )
        : Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Criar Date'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Search bar
            TextField(
              decoration: InputDecoration(
                labelText: 'Procure um lugar...',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: (query) {
                if (query.isNotEmpty) {
                  _performSearch(query);
                } else {
                  setState(() {
                    searchResults.clear();
                  });
                }
              },
            ),
            SizedBox(height: 10),

            // Display selected stops
            Text('Paradas Selecionadas:', style: TextStyle(fontSize: 16)),
            Expanded(child: _buildSelectedStops()),

            // Display search results
            Expanded(flex: 2, child: _buildSearchResults()),

            // Submit Button
            _buildSubmitButton(),

            // Collapsed Map view for the created route
            _buildMapView(),
          ],
        ),
      ),
    );
  }
}

