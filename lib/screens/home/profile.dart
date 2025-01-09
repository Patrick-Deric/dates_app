import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;
  String? _profileImageUrl;
  final _picker = ImagePicker();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  User? user;

  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user != null) {
      try {
        final userDoc =
        await _firestore.collection('users').doc(user!.uid).get();
        if (userDoc.exists) {
          setState(() {
            _nameController.text = userDoc['name'] ?? '';
            _selectedDate =
                userDoc['birthdate']?.toDate() ?? DateTime(2000, 1, 1);
            _profileImageUrl = userDoc['profileImageUrl'];
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> _pickImage(BuildContext context) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      await _uploadImageToFirebase(context);
    }
  }

  Future<void> _uploadImageToFirebase(BuildContext context) async {
    if (_profileImage != null && user != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        String fileName = basename(_profileImage!.path);
        Reference storageRef =
        _storage.ref().child('profile_images/${user!.uid}/$fileName');
        UploadTask uploadTask = storageRef.putFile(_profileImage!);
        TaskSnapshot snapshot = await uploadTask;
        String imageUrl = await snapshot.ref.getDownloadURL();

        await _firestore.collection('users').doc(user!.uid).update({
          'profileImageUrl': imageUrl,
        });

        setState(() {
          _profileImageUrl = imageUrl;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Imagem de perfil atualizada com sucesso!'),
        ));
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao fazer upload da imagem: $e'),
        ));
      }
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveProfile(BuildContext context) async {
    if (user != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _firestore.collection('users').doc(user!.uid).update({
          'name': _nameController.text,
          'birthdate': _selectedDate,
        });
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Perfil atualizado com sucesso')));
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar o perfil: $e')),
        );
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  String capitalizeName(String name) {
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil'),
        actions: [
          _isLoading
              ? Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: Colors.white),
          )
              : TextButton(
            onPressed:
            _isEditing ? () => _saveProfile(context) : _toggleEditMode,
            child: Text(
              _isEditing ? 'Salvar' : 'Editar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : (_profileImageUrl != null
                                ? NetworkImage(_profileImageUrl!)
                                : null),
                            child: _profileImage == null &&
                                _profileImageUrl == null
                                ? Icon(Icons.person, size: 40)
                                : null,
                          ),
                          if (_isEditing)
                            IconButton(
                              icon: Icon(Icons.camera_alt, color: Colors.white),
                              onPressed: () => _pickImage(context),
                            ),
                        ],
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameController.text.isNotEmpty
                                  ? capitalizeName(_nameController.text)
                                  : 'Nome Completo',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Text(
                              user?.email ?? 'Email',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 10),
                            Text(
                              _selectedDate != null
                                  ? DateFormat('dd/MM/yyyy')
                                  .format(_selectedDate!)
                                  : 'Data de Nascimento',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isEditing)
                Column(
                  children: [
                    SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome Completo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isEditing ? () => _pickDate(context) : null,
                      child: AbsorbPointer(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: _selectedDate != null
                                ? DateFormat('dd/MM/yyyy')
                                .format(_selectedDate!)
                                : 'Data de Nascimento',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
