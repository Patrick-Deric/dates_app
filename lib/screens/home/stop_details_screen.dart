import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_de_dates/screens/home/route_visualization.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class StopDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> stop;

  StopDetailsScreen({required this.stop});

  @override
  _StopDetailsScreenState createState() => _StopDetailsScreenState();
}

class _StopDetailsScreenState extends State<StopDetailsScreen> {
  List<Map<String, dynamic>> linkedDates = [];
  List<Map<String, dynamic>> filteredDates = [];
  List<String> photos = [];
  String selectedFilter = 'Todos';
  String? priceRange;
  Map<String, dynamic>? openingHours;
  bool isLoading = true;

  // Icons for categories
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
    _fetchLinkedDates();
    _fetchGooglePlaceDetails();
  }

  Future<void> _fetchLinkedDates() async {
    try {
      final placeId = widget.stop['placeId'];
      if (placeId == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('routes')
          .where('stopPlaceIds', arrayContains: placeId)
          .get();

      List<Map<String, dynamic>> dates = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      setState(() {
        linkedDates = dates;
        filteredDates = dates;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching linked dates: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchGooglePlaceDetails() async {
    try {
      const apiKey = 'AIzaSyA3Z3QuTeYR2WTtDu1Aj1H5XKaoWM8TqHk';
      final placeId = widget.stop['placeId'];
      if (placeId == null) return;

      final response = await http.get(
        Uri.parse(
            'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];

        setState(() {
          priceRange = result['price_level'] != null
              ? '\$' * result['price_level']
              : null;
          openingHours = result['opening_hours']?['weekday_text'] != null
              ? Map.fromIterable(
            result['opening_hours']['weekday_text'],
            key: (item) => item.split(': ')[0],
            value: (item) => item.split(': ')[1],
          )
              : null;
          photos = result['photos'] != null
              ? List<String>.from(result['photos']
              .map((photo) => _getPhotoUrl(photo['photo_reference'])))
              : [];
        });
      }
    } catch (e) {
      print('Error fetching Google Place details: $e');
    }
  }

  String _getPhotoUrl(String photoReference) {
    const apiKey = 'AIzaSyA3Z3QuTeYR2WTtDu1Aj1H5XKaoWM8TqHk';
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoReference&key=$apiKey';
  }

  void _filterDates(String filter) {
    setState(() {
      selectedFilter = filter;
      if (filter == 'Todos') {
        filteredDates = linkedDates;
      } else {
        filteredDates =
            linkedDates.where((date) => date['category'] == filter).toList();
      }
    });
  }

  void _searchPlaceInGoogle() {
    final name = widget.stop['name'];
    if (name != null) {
      final googleSearchUrl = 'https://www.google.com/search?q=$name';
      launch(googleSearchUrl);
    }
  }

  String _getPreferredTransport(List stops) {
    double totalDistance = 0;
    for (int i = 0; i < stops.length - 1; i++) {
      final lat1 = stops[i]['lat'];
      final lng1 = stops[i]['lng'];
      final lat2 = stops[i + 1]['lat'];
      final lng2 = stops[i + 1]['lng'];

      final distance = _calculateDistance(lat1, lng1, lat2, lng2);
      totalDistance += distance;
    }
    return totalDistance > 2 ? 'Carro' : 'A pé';
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295; // Pi/180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lng2 - lng1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2*R*asin...
  }

  void _openGallery() {
    final name = widget.stop['name'];
    if (name != null) {
      final googleSearchUrl = 'https://www.google.com/search?tbm=isch&q=$name';
      launch(googleSearchUrl);
    }
  }

  Widget _buildPhotoGallery() {
    if (photos.isEmpty) return SizedBox.shrink();

    final additionalPhotos = photos.length > 4 ? '+${photos.length - 4}' : null;

    return GestureDetector(
      onTap: _openGallery,
      child: Stack(
        children: [
          Row(
            children: List.generate(
              min(4, photos.length),
                  (index) => Expanded(
                child: Container(
                  height: 200,
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(photos[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (additionalPhotos != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  additionalPhotos,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stop['name'] ?? 'Detalhes do Ponto'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildPhotoGallery(),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.stop['name'] ?? 'Nome Desconhecido',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.stop['address'] ?? 'Endereço indisponível',
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  if (priceRange != null)
                    Text(
                      'Faixa de Preço: $priceRange',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey[800]),
                    ),
                  SizedBox(height: 8),
                  if (openingHours != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Horários de Funcionamento:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        ...openingHours!.entries.map((entry) {
                          return Text(
                            '${entry.key}: ${entry.value}',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[800]),
                          );
                        }).toList(),
                      ],
                    ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _searchPlaceInGoogle,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Colors.blueAccent,
                      padding: EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    icon: Image.asset(
                      'assets/icons_buttons_cards/google.png',
                      width: 24,
                      height: 24,
                    ),
                    label: Text('Pesquisar no Google',
                        style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
            Divider(),
            SingleChildScrollView(
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
                        if (selected) _filterDates(filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: filteredDates.length,
              itemBuilder: (context, index) {
                final date = filteredDates[index];
                final iconPath =
                    categoryIcons[date['category']] ?? 'assets/default.png';
                final totalStops = date['stops']?.length ?? 0;
                final transport = _getPreferredTransport(date['stops'] ?? []);
                final transportIcon = transport == 'Carro'
                    ? 'assets/icons_buttons_cards/car.png'
                    : 'assets/icons_buttons_cards/man-walking.png';
                final totalDistance = _calculateDistance(
                    date['stops'][0]['lat'],
                    date['stops'][0]['lng'],
                    date['stops'].last['lat'],
                    date['stops'].last['lng']);

                return Card(
                  margin: EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 3,
                  child: ListTile(
                    leading: SizedBox(
                      width: 40,
                      height: 40,
                      child: Image.asset(
                        iconPath,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(date['category'] ?? 'Categoria'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Paradas: $totalStops'),
                        Row(
                          children: [
                            Image.asset(
                              transportIcon,
                              width: 16,
                              height: 16,
                            ),
                            SizedBox(width: 8),
                            Text('Transporte'),
                          ],
                        ),
                        Text('Distância total: ${totalDistance.toStringAsFixed(1)} km'),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapVisualizationScreen(
                              routeId: date['id']),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
