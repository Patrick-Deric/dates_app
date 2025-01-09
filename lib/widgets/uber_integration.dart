import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UberIntegrationScreen extends StatelessWidget {
  final List<Map<String, dynamic>> routeStops;

  UberIntegrationScreen({required this.routeStops});

  void _launchUber() {
    if (routeStops.isNotEmpty) {
      final pickup = '${routeStops.first['lat']},${routeStops.first['lng']}';
      final dropoff = '${routeStops.last['lat']},${routeStops.last['lng']}';
      final waypoints = routeStops
          .sublist(1, routeStops.length - 1)
          .map((stop) => '${stop['lat']},${stop['lng']}')
          .join('|');

      final uberDeepLink = Uri.parse(
        'https://m.uber.com/ul/?client_id=YOUR_UBER_CLIENT_ID'
            '&action=setPickup'
            '&pickup[latitude]=${pickup.split(",")[0]}'
            '&pickup[longitude]=${pickup.split(",")[1]}'
            '&dropoff[latitude]=${dropoff.split(",")[0]}'
            '&dropoff[longitude]=${dropoff.split(",")[1]}'
            '&waypoints=$waypoints',
      );

      launchUrl(uberDeepLink, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chamar Uber'),
        backgroundColor: Colors.redAccent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.car_rental, size: 100, color: Colors.redAccent),
              SizedBox(height: 20),
              Text(
                'Deseja abrir a rota no Uber?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _launchUber,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Abrir Uber',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
