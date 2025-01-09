import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'Route_visualization.dart';

class CreateDateScreen extends StatefulWidget {
  @override
  _CreateDateScreenState createState() => _CreateDateScreenState();
}

class _CreateDateScreenState extends State<CreateDateScreen> {
  List<Map<String, dynamic>> selectedStops = [];
  List<Map<String, dynamic>> searchResults = [];
  bool _isRouteCreated = false;
  String apiKey = 'AIzaSyA3Z3QuTeYR2WTtDu1Aj1H5XKaoWM8TqHk'; // Replace with your actual Google API key
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Categories for the date
  String? selectedCategory;
  final List<String> categories = [
    'Date Romântico',
    'Date Cultural',
    'Date ao Ar Livre',
    'Date Familiar',
    'Date Atividade Fisica',
    'Date Festa',
  ];

  // Static location for the user's city
  double userLatitude = -23.5505; // São Paulo latitude
  double userLongitude = -46.6333; // São Paulo longitude

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      searchResults.clear();
    });

    try {
      // Firestore search
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

      // Google Places search if no Firestore results
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
    } catch (e) {
      print('Error during search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao procurar lugares.')),
      );
    }

    setState(() {
      _isSearching = false;
    });
  }

  Future<List<dynamic>> _fetchGooglePlaces(String query) async {
    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&location=$userLatitude,$userLongitude&radius=50000&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      return data['predictions'];
    } else {
      throw Exception('Failed to load places');
    }
  }

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

  void _selectStop(Map<String, dynamic> stop) async {
    if (selectedStops.length < 5) {
      if (stop['source'] == 'google') {
        var details = await _fetchPlaceDetails(stop['placeId']);
        stop.addAll(details);
      }
      setState(() {
        selectedStops.add(stop);
        _searchController.clear();
        searchResults.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Você só pode adicionar até 5 paradas.')),
      );
    }
  }

  void _removeStop(int index) {
    setState(() {
      selectedStops.removeAt(index);
    });
  }

  Widget _buildSearchResults() {
    if (_searchController.text.isNotEmpty && searchResults.isNotEmpty) {
      return ListView.builder(
        shrinkWrap: true,
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          var result = searchResults[index];
          return ListTile(
            title: Text(result['name']),
            subtitle: Text(
              result['source'] == 'firestore'
                  ? result['address']
                  : 'Resultado do Google',
            ),
            onTap: () {
              _selectStop(result);
              FocusScope.of(context).unfocus();
            },
          );
        },
      );
    }
    return SizedBox.shrink();
  }

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
              child: Text((index + 1).toString()),
            ),
            title: Text(stop['name']),
            subtitle: Text(stop['address']),
            trailing: IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                _removeStop(index);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySelection() {
    return Wrap(
      spacing: 10,
      children: categories.map((category) {
        return ChoiceChip(
          label: Text(category),
          selected: selectedCategory == category,
          onSelected: (bool selected) {
            setState(() {
              selectedCategory = selected ? category : null;
            });
          },
        );
      }).toList(),
    );
  }

  Future<void> _saveRoute() async {
    if (selectedStops.isEmpty || selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adicione paradas e escolha um tipo de date.')),
      );
      return;
    }

    try {
      DocumentReference routeRef = await FirebaseFirestore.instance
          .collection('routes')
          .add({
        'stops': selectedStops,
        'created_at': Timestamp.now(),
        'category': selectedCategory,
      });

      setState(() {
        _isRouteCreated = true;
        routeId = routeRef.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rota criada com sucesso!')),
      );
    } catch (e) {
      print('Error saving route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar a rota.')),
      );
    }
  }

  String? routeId;

  Widget _buildViewMapButton() {
    return ElevatedButton(
      onPressed: () {
        if (routeId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MapVisualizationScreen(routeId: routeId!),
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

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _saveRoute,
      child: Text('Criar Rota'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Criar Date')),
      body: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Procure um lugar...',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      searchResults.clear();
                    });
                  },
                ),
              ),
              onChanged: (query) {
                if (query.isNotEmpty) {
                  _performSearch(query);
                }
              },
            ),
            SizedBox(height: 10),
            Expanded(child: _buildSelectedStops()),
            _buildSearchResults(),
            SizedBox(height: 10),
            _buildCategorySelection(),
            _buildViewMapButton(),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }
}
