import 'package:flutter/material.dart';
import 'package:app_de_dates/widgets/mapbox_map_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapVisualizationScreen extends StatefulWidget {
  final String routeId;

  MapVisualizationScreen({required this.routeId});

  @override
  _MapVisualizationScreenState createState() => _MapVisualizationScreenState();
}

class _MapVisualizationScreenState extends State<MapVisualizationScreen> {
  List<Map<String, dynamic>> routeStops = [];
  bool isLoading = true;
  bool isFavorited = false;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _checkIfFavorited();
  }

  Future<void> _loadRoute() async {
    try {
      DocumentSnapshot routeDoc = await FirebaseFirestore.instance
          .collection('routes')
          .doc(widget.routeId)
          .get();

      if (routeDoc.exists) {
        List<dynamic> stops = routeDoc['stops'];
        setState(() {
          routeStops = List<Map<String, dynamic>>.from(stops).asMap().entries.map((entry) {
            final index = entry.key;
            final stop = entry.value;

            final iconNames = ['one.png', 'two.png', 'three.png', 'four.png', 'five.png'];
            stop['icon'] = 'assets/number_map_icons/${iconNames[index]}';
            return stop;
          }).toList();
          isLoading = false;
        });
      } else {
        print('Route not found');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading route: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _checkIfFavorited() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final favDoc = await FirebaseFirestore.instance
          .collection('favourites')
          .doc(userId)
          .collection('routes')
          .doc(widget.routeId)
          .get();

      setState(() {
        isFavorited = favDoc.exists;
      });
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  void _toggleFavorite() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    TextEditingController controller = TextEditingController();
    String? selectedCollection;

    final collectionsSnapshot = await FirebaseFirestore.instance
        .collection('favourites')
        .doc(userId)
        .collection('collections')
        .get();

    List<String> collections = collectionsSnapshot.docs.map((doc) => doc.id).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Adicionar aos Favoritos'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedCollection,
                    hint: Text('Selecione uma coleção'),
                    isExpanded: true,
                    items: collections.map((collection) {
                      return DropdownMenuItem(
                        value: collection,
                        child: Text(collection),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCollection = value;
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  Divider(),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Criar nova coleção',
                      prefixIcon: Icon(Icons.create_new_folder),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    final collectionToAdd = selectedCollection ?? controller.text.trim();
                    if (collectionToAdd.isNotEmpty) {
                      try {
                        final collectionRef = FirebaseFirestore.instance
                            .collection('favourites')
                            .doc(userId)
                            .collection('collections')
                            .doc(collectionToAdd);

                        final existingCollection = await collectionRef.get();
                        if (!existingCollection.exists) {
                          await collectionRef.set({});
                        }

                        await collectionRef
                            .collection('routes')
                            .doc(widget.routeId)
                            .set({'routeId': widget.routeId});

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Adicionado à coleção "$collectionToAdd"!')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao adicionar à coleção: $e')),
                        );
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openInGoogleMaps() {
    if (routeStops.isNotEmpty) {
      final origin = '${routeStops.first['lat']},${routeStops.first['lng']}';
      final destination = '${routeStops.last['lat']},${routeStops.last['lng']}';
      final waypoints = routeStops
          .sublist(1, routeStops.length - 1)
          .map((stop) => '${stop['lat']},${stop['lng']}')
          .join('|');

      final googleMapsUrl =
          'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&waypoints=$waypoints';

      launch(googleMapsUrl);
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
            Navigator.popUntil(context, (route) => route.isFirst); // Always navigate back to home
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFavorited ? Icons.favorite : Icons.favorite_border,
              color: Colors.red,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : routeStops.isNotEmpty
          ? Column(
        children: [
          Expanded(
            child: MapboxMapWidget(
              styleString: 'mapbox://styles/mapbox/streets-v11',
              initialLat: routeStops.first['lat'] ?? -23.5505,
              initialLng: routeStops.first['lng'] ?? -46.6333,
              selectedStops: routeStops,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _openInGoogleMaps,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Abrir no Google Maps', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      )
          : Center(child: Text('Nenhuma parada selecionada')),
    );
  }
}
