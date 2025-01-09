import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Route_visualization.dart';

class CollectionDetailScreen extends StatefulWidget {
  final String collectionName;

  CollectionDetailScreen({required this.collectionName});

  @override
  _CollectionDetailScreenState createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final Map<String, String> categoryIcons = {
    'Date Romântico': 'assets/map_icons/heart.png',
    'Date Cultural': 'assets/map_icons/livro.png',
    'Date ao Ar Livre': 'assets/map_icons/arvore.png',
    'Date Familiar': 'assets/map_icons/familia.png',
    'Date Atividade Fisica': 'assets/map_icons/corrida.png',
    'Date Festa': 'assets/map_icons/confete.png',
  };

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.collectionName),
          backgroundColor: Colors.redAccent,
        ),
        body: Center(
          child: Text(
            'Você precisa estar logado para visualizar esta coleção.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collectionName),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            tooltip: 'Renomear coleção',
            onPressed: () => _renameCollection(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('favourites')
            .doc(currentUser.uid)
            .collection('collections')
            .doc(widget.collectionName)
            .collection('routes')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar rotas.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma rota adicionada nesta coleção.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final routes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];
              final routeId = route['routeId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('routes')
                    .doc(routeId)
                    .get(),
                builder: (context, routeSnapshot) {
                  if (routeSnapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: LinearProgressIndicator(),
                    );
                  }

                  if (routeSnapshot.hasError ||
                      !routeSnapshot.hasData ||
                      !routeSnapshot.data!.exists) {
                    return ListTile(
                      title: Text('Erro ao carregar rota.'),
                      subtitle: Text('ID: $routeId'),
                      leading: Icon(Icons.error, color: Colors.red),
                    );
                  }

                  final routeData =
                      routeSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final firstStopName = (routeData['stops'] != null &&
                      (routeData['stops'] as List).isNotEmpty)
                      ? routeData['stops'][0]['name']
                      : 'Parada desconhecida';
                  final category = routeData['category'] ?? 'Desconhecido';
                  final iconPath = categoryIcons[category] ?? 'assets/map_icons/default.png';

                  return Card(
                    margin: EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 3,
                    child: ListTile(
                      leading: Image.asset(
                        iconPath,
                        width: 40,
                        height: 40,
                      ),
                      title: Text(firstStopName),
                      subtitle: Text('Categoria: $category'),
                      trailing: PopupMenuButton(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteRoute(routeId);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Deletar'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MapVisualizationScreen(routeId: routeId),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _renameCollection(BuildContext context) async {
    TextEditingController controller =
    TextEditingController(text: widget.collectionName);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Renomear coleção'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Novo nome da coleção'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty || newName == widget.collectionName) return;

                try {
                  final collectionRef = FirebaseFirestore.instance
                      .collection('favourites')
                      .doc(currentUser.uid)
                      .collection('collections');

                  final existingCollection = await collectionRef.doc(newName).get();

                  if (existingCollection.exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('A coleção "$newName" já existe.')),
                    );
                  } else {
                    // Rename collection
                    final oldData =
                    await collectionRef.doc(widget.collectionName).get();
                    await collectionRef.doc(newName).set(oldData.data() ?? {});
                    await collectionRef.doc(widget.collectionName).delete();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Coleção renomeada para "$newName".'),
                      ),
                    );
                    Navigator.pop(context);
                    Navigator.pop(context);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao renomear coleção: $e')),
                  );
                }
              },
              child: Text('Renomear'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteRoute(String routeId) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    try {
      final routeRef = FirebaseFirestore.instance
          .collection('favourites')
          .doc(currentUser.uid)
          .collection('collections')
          .doc(widget.collectionName)
          .collection('routes')
          .doc(routeId);

      await routeRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rota removida com sucesso.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover rota: $e')),
      );
    }
  }
}
