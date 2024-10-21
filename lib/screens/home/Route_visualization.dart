import 'package:flutter/material.dart';
import 'package:app_de_dates/widgets/mapbox_map_widget.dart'; // Import your Mapbox widget

class MapVisualizationScreen extends StatelessWidget {
  final List<Map<String, dynamic>> selectedStops;

  MapVisualizationScreen({required this.selectedStops});

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
      body: Center(
        child: selectedStops.isNotEmpty
            ? MapboxMapWidget(
          styleString: 'mapbox://styles/mapbox/streets-v11',
          initialLat: selectedStops.first['lat'],
          initialLng: selectedStops.first['lng'],
          selectedStops: selectedStops,  // Pass the selected stops to the map
        )
            : Text('Nenhuma parada selecionada'),
      ),
    );
  }
}
