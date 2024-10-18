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
  String? _profileImageUrl; // Store the profile image URL
  final _picker = ImagePicker();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  User? user;

  final _nameController = TextEditingController();
  DateTime? _selectedDate;

  bool _isEditing = false; // To track if the user is editing

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user!.uid).get();
      if (userDoc.exists) {
        setState(() {
          _nameController.text = userDoc['name'] ?? '';
          _selectedDate = userDoc['birthdate']?.toDate() ?? DateTime.now();
          _profileImageUrl = userDoc['profileImageUrl']; // Load profile image URL
        });
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
      try {
        String fileName = basename(_profileImage!.path);
        Reference storageRef = _storage.ref().child('profile_images/${user!.uid}/$fileName');
        UploadTask uploadTask = storageRef.putFile(_profileImage!);
        TaskSnapshot snapshot = await uploadTask;
        String imageUrl = await snapshot.ref.getDownloadURL();

        // Save the profile image URL in Firestore
        await _firestore.collection('users').doc(user!.uid).update({
          'profileImageUrl': imageUrl,
        });

        setState(() {
          _profileImageUrl = imageUrl; // Update the UI with the new profile image URL
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Imagem de perfil atualizada com sucesso!'),
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao fazer upload da imagem: $e'),
        ));
      }
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveProfile(BuildContext context) async {
    if (user != null) {
      await _firestore.collection('users').doc(user!.uid).update({
        'name': _nameController.text,
        'birthdate': _selectedDate,
      });
      setState(() {
        _isEditing = false; // Exit editing mode
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Perfil atualizado com sucesso')));
    }
  }

  // Toggle edit mode
  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  // Function to capitalize the first letter of each word
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
          // Show "Editar" or "Salvar" button depending on editing mode
          TextButton(
            onPressed: _isEditing ? () => _saveProfile(context) : _toggleEditMode,
            child: Text(_isEditing ? 'Salvar' : 'Editar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile image and name section with birthdate and email
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : (_profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null),
                        child: _profileImage == null && _profileImageUrl == null
                            ? Icon(Icons.person, size: 40)
                            : null,
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
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Text(
                              user?.email ?? 'Email',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 10),
                            Text(
                              _selectedDate != null
                                  ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
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
              SizedBox(height: 20),

              // Edit Profile Picture Button (only visible in editing mode)
              if (_isEditing)
                ElevatedButton.icon(
                  icon: Icon(Icons.camera_alt),
                  label: Text('Alterar Foto de Perfil'),
                  onPressed: () => _pickImage(context),
                ),

              if (_isEditing) ...[
                SizedBox(height: 20),

                // Display or Edit Name (only visible in editing mode)
                TextField(
                  controller: _nameController,
                  enabled: _isEditing,
                  decoration: InputDecoration(
                    labelText: 'Nome Completo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Display or Edit Date of Birth (only visible in editing mode)
                GestureDetector(
                  onTap: _isEditing ? () => _pickDate(context) : null,
                  child: AbsorbPointer(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: _selectedDate != null
                            ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                            : 'Data de Nascimento',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

