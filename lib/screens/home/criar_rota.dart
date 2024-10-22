// AIzaSyA3Z3QuTeYR2WTtDu1Aj1H5XKaoWM8TqHk
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:app_de_dates/widgets/mapbox_map_widget.dart'; // Import the Mapbox map widget
import 'Route_visualization.dart';

class CreateDateScreen extends StatefulWidget {
  @override
  _CreateDateScreenState createState() => _CreateDateScreenState();
}

class _CreateDateScreenState extends State<CreateDateScreen> {
  List<Map<String, dynamic>> selectedStops = []; // Store selected stops
  List<Map<String, dynamic>> searchResults = []; // Store search results
  bool _isRouteCreated = false; // To track if the route is created
  String apiKey = 'AIzaSyA3Z3QuTeYR2WTtDu1Aj1H5XKaoWM8TqHk'; // Google Places API Key
  TextEditingController _searchController = TextEditingController(); // Controller for search bar
  bool _isSearching = false; // Track if the user is searching

  // Define a static location for the user's city (example: São Paulo)
  double userLatitude = -23.5505; // São Paulo latitude
  double userLongitude = -46.6333; // São Paulo longitude

  // Function to handle search with location bias
  void _performSearch(String query) async {
    setState(() {
      _isSearching = true; // User started searching
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

    // Step 2: If no Firestore results, query Google Places API with location bias
    if (searchResults.isEmpty) {
      var googlePlacesResults = await _fetchGooglePlaces(query);
      googlePlacesResults.forEach((place) {
        searchResults.add({
          'name': place['description'],
          'placeId': place['place_id'],
          'source': 'google',
        });
      });
    }

    setState(() {
      _isSearching = false; // Searching done
    });
  }

  // Fetch results from Google Places API with location bias to user's city
  Future<List<dynamic>> _fetchGooglePlaces(String query) async {
    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query'
        '&location=$userLatitude,$userLongitude'  // Bias the search to São Paulo
        '&radius=50000'  // Restrict the search to a 50 km radius (adjust as needed)
        '&key=$apiKey';

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
        _searchController.clear(); // Clear search bar after selection
        searchResults.clear(); // Clear search results after stop selection
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Você só pode adicionar até 5 paradas.')));
    }
  }

  // Handle stop removal
  void _removeStop(int index) {
    setState(() {
      selectedStops.removeAt(index);
    });
  }

  // Build search results
  Widget _buildSearchResults() {
    // Only show the widget if there is input in the search bar and there are results
    if (_searchController.text.isNotEmpty && searchResults.isNotEmpty) {
      return ListView.builder(
        shrinkWrap: true,
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          var result = searchResults[index];
          return ListTile(
            title: Text(
              result['name'],
              overflow: TextOverflow.ellipsis,  // Ensures one-line display
              style: TextStyle(fontSize: 16),
            ),
            subtitle: Text(
              result['source'] == 'firestore'
                  ? result['address']
                  : 'Resultado do Google',
              style: TextStyle(fontSize: 14),
            ),
            onTap: () {
              _selectStop(result);
              FocusScope.of(context).unfocus(); // Hide keyboard after selection
            },
          );
        },
      );
    } else {
      // If the search bar is empty or no results, return an empty widget
      return SizedBox.shrink();
    }
  }

  // Build selected stops with numbering, clean design, and border for separation
  Widget _buildSelectedStops() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: selectedStops.length,
      itemBuilder: (context, index) {
        var stop = selectedStops[index];
        return Container(
          margin: EdgeInsets.symmetric(vertical: 5),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.redAccent,
              child: Text((index + 1).toString(),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(stop['name'],
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            subtitle: Text(stop['address']),
            trailing: IconButton(
              icon: Icon(Icons.close, color: Colors.redAccent),
              onPressed: () {
                _removeStop(index); // Remove the selected stop
              },
            ),
          ),
        );
      },
    );
  }

  // Button to navigate to the map visualization screen
  // Assuming you have routeId stored after saving the route to Firestore
  String? routeId; // Add this variable to track the route ID

// Update your _buildViewMapButton to use routeId
  Widget _buildViewMapButton() {
    return ElevatedButton(
      onPressed: () {
        if (routeId != null) {
          // Navigate to MapVisualizationScreen, passing the routeId
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MapVisualizationScreen(routeId: routeId!), // Pass the routeId
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Crie a rota primeiro antes de visualizar no mapa.')),
          );
        }
      },
      child: Text('Visualizar no Mapa'),
    );
  }

  // Submit Button (for saving the route to Firestore)
  // Submit Button (for saving the route to Firestore)
  // Submit Button (for saving the route to Firestore)
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: () async {
        if (selectedStops.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Por favor, selecione pelo menos uma parada.')));
          return;
        }

        // Save route to Firestore and store the routeId
        DocumentReference routeRef = await FirebaseFirestore.instance.collection('routes').add({
          'stops': selectedStops,
          'created_at': Timestamp.now(),
        });

        setState(() {
          _isRouteCreated = true;
          routeId = routeRef.id; // Store the generated route ID
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rota criada com sucesso!')));
      },
      child: Text('Criar Rota'),
    );
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
            // Search bar with clear functionality
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Procure um lugar...',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear(); // Clear the search bar when the clear button is pressed
                    setState(() {
                      searchResults.clear(); // Clear search results as well
                    });
                  },
                ),
              ),
              onChanged: (query) {
                if (query.isNotEmpty) {
                  _performSearch(query);
                } else {
                  setState(() {
                    searchResults.clear(); // Clear search results when input is cleared
                  });
                }
              },
            ),
            SizedBox(height: 10),

            // Display selected stops
            Text('Paradas Selecionadas:', style: TextStyle(fontSize: 16)),
            Expanded(child: _buildSelectedStops()),

            // Display search results (only when input is not empty and results are available)
            _buildSearchResults(),

            // View Map Button
            _buildViewMapButton(),

            // Submit Button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }
}


