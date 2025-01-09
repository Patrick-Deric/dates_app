import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Route_visualization.dart';
import 'favorites_details.dart';

class FavouritesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Favoritos'),
          backgroundColor: Colors.redAccent,
        ),
        body: Center(
          child: Text(
            'Você precisa estar logado para ver seus favoritos.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Favoritos'),
        backgroundColor: Colors.redAccent,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('favourites')
            .doc(currentUser.uid)
            .collection('collections')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar favoritos.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma coleção encontrada. Crie uma coleção para começar.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final collections = snapshot.data!.docs;

          return ListView.builder(
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              final collectionName = collection.id;

              return Card(
                margin: EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 3,
                child: ListTile(
                  leading: Icon(Icons.folder, color: Colors.blueAccent),
                  title: Text(collectionName),
                  trailing: Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CollectionDetailScreen(collectionName: collectionName),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewCollection(context),
        child: Icon(Icons.add),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _createNewCollection(BuildContext context) {
    TextEditingController controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Criar nova coleção'),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(hintText: 'Nome da coleção'),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancelar'),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    final newCollectionName = controller.text.trim();
                    final userId = FirebaseAuth.instance.currentUser?.uid;

                    if (userId != null && newCollectionName.isNotEmpty) {
                      setState(() {
                        isLoading = true;
                      });

                      try {
                        final collectionRef = FirebaseFirestore.instance
                            .collection('favourites')
                            .doc(userId)
                            .collection('collections')
                            .doc(newCollectionName);

                        final existingCollection = await collectionRef.get();
                        if (!existingCollection.exists) {
                          await collectionRef.set({});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Coleção "$newCollectionName" criada com sucesso!'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'A coleção "$newCollectionName" já existe.'),
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao criar coleção: $e'),
                          ),
                        );
                      }

                      setState(() {
                        isLoading = false;
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: isLoading
                      ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text('Criar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
