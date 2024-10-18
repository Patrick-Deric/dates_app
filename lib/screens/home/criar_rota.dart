import 'package:flutter/material.dart';

class CriarRotaScreen extends StatefulWidget {
  @override
  _CriarRotaScreenState createState() => _CriarRotaScreenState();
}

class _CriarRotaScreenState extends State<CriarRotaScreen> {
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Criar Rota'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _routeNameController,
              decoration: InputDecoration(
                labelText: 'Nome da Rota',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Handle route creation
              },
              child: Text('Criar Rota'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16.0), backgroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
