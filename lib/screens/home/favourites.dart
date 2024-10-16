import 'package:flutter/material.dart';

class FavouritesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favoritos'),
      ),
      body: Center(
        child: Text('Aqui você verá suas rotas favoritas!'),
      ),
    );
  }
}
