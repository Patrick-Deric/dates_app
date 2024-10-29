import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:app_de_dates/widgets/mapbox_map_widget.dart';
import 'Route_visualization.dart';

class CreateDateScreen extends StatefulWidget {
  @override
  _CreateDateScreenState createState() => _CreateDateScreenState();
}

class _CreateDateScreenState extends State<CreateDateScreen> {
  List<Map<String, dynamic>> selectedStops = [];
  List<Map<String, dynamic>> searchResults = [];
  bool _isRouteCreated = false;
  String apiKey = 'AIzaSyA3Z3QuTeYR2WTtDu1Aj1H5XKaoWM8TqHk';
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
    'Date Festa'
  ];

  // Static location for the user's city
  double userLatitude = -23.5505; // São Paulo latitude
  double userLongitude = -46.6333; // São Paulo longitude

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      searchResults.clear();
    });

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
      _isSearching = false;
    });
  }

  Future<List<dynamic>> _fetchGooglePlaces(String query) async {
    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query'
        '&location=$userLatitude,$userLongitude'
        '&radius=50000'
        '&key=$apiKey';

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
          SnackBar(content: Text('Você só pode adicionar até 5 paradas.')));
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
            title: Text(
              result['name'],
              overflow: TextOverflow.ellipsis,
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
              FocusScope.of(context).unfocus();
            },
          );
        },
      );
    } else {
      return SizedBox.shrink();
    }
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
              child: Text((index + 1).toString(),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(stop['name'],
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            subtitle: Text(stop['address']),
            trailing: IconButton(
              icon: Icon(Icons.close, color: Colors.redAccent),
              onPressed: () {
                _removeStop(index);
              },
            ),
          ),
        );
      },
    );
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
      onPressed: () async {
        if (selectedStops.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Por favor, selecione pelo menos uma parada.')));
          return;
        }

        if (selectedCategory == null) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Por favor, selecione um tipo de date.')));
          return;
        }

        DocumentReference routeRef = await FirebaseFirestore.instance.collection('routes').add({
          'stops': selectedStops,
          'created_at': Timestamp.now(),
          'category': selectedCategory,
        });

        setState(() {
          _isRouteCreated = true;
          routeId = routeRef.id;
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rota criada com sucesso!')));
      },
      child: Text('Criar Rota'),
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecione o Tipo de Date:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Wrap(
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
        ),
      ],
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
                } else {
                  setState(() {
                    searchResults.clear();
                  });
                }
              },
            ),
            SizedBox(height: 10),
            Text('Paradas Selecionadas:', style: TextStyle(fontSize: 16)),
            Expanded(child: _buildSelectedStops()),
            _buildSearchResults(),
            _buildCategorySelection(),
            _buildViewMapButton(),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }
}
