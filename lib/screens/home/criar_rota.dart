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
  int _currentStep = 0;
  List<Map<String, dynamic>> selectedStops = [];
  List<Map<String, dynamic>> searchResults = [];
  String apiKey = 'AIzaSyA3Z3QuTeYR2WTtDu1Aj1H5XKaoWM8TqHk';
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isSaving = false;

  String? selectedCategory;
  final List<String> categories = [
    'Date Romântico',
    'Date Cultural',
    'Date ao Ar Livre',
    'Date Familiar',
    'Date Atividade Fisica',
    'Date Festa',
  ];

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      searchResults.clear();
    });

    try {
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
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&location=-23.5505,-46.6333&radius=50000&key=$apiKey';

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
        'placeId': placeId,
      };
    } else {
      throw Exception('Failed to load place details');
    }
  }

  void _selectStop(Map<String, dynamic> stop) async {
    if (selectedStops.length < 5) {
      if (stop['source'] == 'google') {
        var details = await _fetchPlaceDetails(stop['placeId']);
        stop = {...stop, ...details};
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

  Future<void> _saveRoute(BuildContext context) async {
    if (selectedStops.isEmpty || selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adicione paradas e escolha um tipo de date.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Extract placeIds from the selected stops
      List<String> stopPlaceIds = selectedStops
          .where((stop) => stop['placeId'] != null)
          .map((stop) => stop['placeId'] as String)
          .toList();

      DocumentReference routeRef = await FirebaseFirestore.instance
          .collection('routes')
          .add({
        'category': selectedCategory,
        'created_at': Timestamp.now(),
        'stops': selectedStops, // All stops for this route are stored here
        'stopPlaceIds': stopPlaceIds, // Array of placeIds for easier querying
      });

      String routeId = routeRef.id;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rota criada com sucesso!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MapVisualizationScreen(
            routeId: routeId, // Pass the route ID to the map screen
          ),
        ),
      );
    } catch (e) {
      print('Error saving route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar a rota.')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return Column(
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
            if (searchResults.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    var result = searchResults[index];
                    return Column(
                      children: [
                        ListTile(
                          title: Text(result['name']),
                          subtitle: Text(
                            result['source'] == 'firestore'
                                ? result['address']
                                : 'Resultado do Google',
                          ),
                          onTap: () => _selectStop(result),
                        ),
                        Divider(),
                      ],
                    );
                  },
                ),
              ),
            if (selectedStops.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: selectedStops.length,
                  itemBuilder: (context, index) {
                    var stop = selectedStops[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text((index + 1).toString()),
                        backgroundColor: Colors.blueAccent,
                      ),
                      title: Text(stop['name']),
                      subtitle: Text(stop['address']),
                      trailing: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => _removeStop(index),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      case 1:
        return Wrap(
          spacing: 10,
          children: categories.map((category) {
            return ChoiceChip(
              label: Text(category),
              selected: selectedCategory == category,
              onSelected: (selected) {
                setState(() {
                  selectedCategory = selected ? category : null;
                });
              },
            );
          }).toList(),
        );
      case 2:
        return Container(); // Empty, controlled via `controlsBuilder`.
      default:
        return SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Criar Date'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 2) {
            _saveRoute(context); // Save route on final step.
          } else if ((_currentStep == 0 && selectedStops.isEmpty) ||
              (_currentStep == 1 && selectedCategory == null)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Por favor, complete este passo antes de continuar.')),
            );
          } else {
            setState(() {
              _currentStep++;
            });
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep--;
              if (_currentStep == 0) selectedStops.clear();
              if (_currentStep == 1) selectedCategory = null;
            });
          }
        },
        controlsBuilder: (BuildContext context, ControlsDetails controls) {
          final canContinue = (_currentStep == 0 && selectedStops.isNotEmpty) ||
              (_currentStep == 1 && selectedCategory != null) || _currentStep == 2;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: canContinue ? controls.onStepContinue : null,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: canContinue ? Colors.redAccent : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Continuar'),
              ),
              if (_currentStep > 0)
                TextButton(
                  onPressed: controls.onStepCancel,
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  child: Text('Retornar'),
                ),
            ],
          );
        },
        steps: [
          Step(
            title: Text('Adicionar Lugares'),
            isActive: true,
            state: selectedStops.isNotEmpty ? StepState.complete : StepState.indexed,
            content: _buildStepContent(0),
          ),
          Step(
            title: Text('Selecionar Categoria'),
            isActive: true,
            state: selectedCategory != null ? StepState.complete : StepState.indexed,
            content: _buildStepContent(1),
          ),
          Step(
            title: Text('Finalizar e Salvar'),
            isActive: true,
            content: _buildStepContent(2),
          ),
        ],
      ),
    );
  }
}
