import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';  // Para usar File
import 'package:firebase_auth/firebase_auth.dart';  // Para autenticação
import 'package:cloud_firestore/cloud_firestore.dart';  // Para Firestore
import 'package:firebase_storage/firebase_storage.dart';  // Para Firebase Storage
import 'package:path/path.dart';  // Para pegar o nome do arquivo
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;  // Armazena a imagem do perfil
  final _picker = ImagePicker();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;  // Instância do Firebase Storage
  User? user;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    _loadUserData();  // Carregar dados do Firestore
  }

  Future<void> _loadUserData() async {
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user!.uid).get();
      if (userDoc.exists) {
        setState(() {
          _nameController.text = userDoc['name'] ?? '';
          _emailController.text = user!.email ?? '';
          _selectedDate = userDoc['birthdate']?.toDate() ?? DateTime.now();
        });
      }
    }
  }

  // Função para escolher a imagem e fazer upload no Firebase Storage
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });

      await _uploadImageToFirebase();
    }
  }

  // Função para fazer o upload da imagem no Firebase Storage
  Future<void> _uploadImageToFirebase() async {
    if (_profileImage != null && user != null) {
      try {
        String fileName = basename(_profileImage!.path);  // Nome do arquivo
        Reference storageRef = _storage.ref().child('profile_images/${user!.uid}/$fileName');

        // Faz o upload da imagem para o Firebase Storage
        UploadTask uploadTask = storageRef.putFile(_profileImage!);
        TaskSnapshot snapshot = await uploadTask;

        // Pega o link da imagem carregada
        String imageUrl = await snapshot.ref.getDownloadURL();

        // Atualiza o Firestore com o link da imagem
        await _firestore.collection('users').doc(user!.uid).update({
          'profileImageUrl': imageUrl,  // Salva o URL da imagem no Firestore
        });

        ScaffoldMessenger.of(context as BuildContext).showSnackBar(SnackBar(
          content: Text('Imagem de perfil atualizada com sucesso!'),
        ));
      } catch (e) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(SnackBar(
          content: Text('Erro ao fazer upload da imagem: $e'),
        ));
      }
    }
  }

  // Função para escolher data de nascimento
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

  // Função para salvar alterações no Firestore
  Future<void> _saveProfile() async {
    if (user != null) {
      await _firestore.collection('users').doc(user!.uid).update({
        'name': _nameController.text,
        'birthdate': _selectedDate,
      });
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(SnackBar(content: Text('Perfil atualizado com sucesso')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),

              // Imagem de perfil com tamanho padronizado
              CircleAvatar(
                radius: 60,  // Tamanho padrão da imagem
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null ? Icon(Icons.person, size: 60) : null,
              ),

              SizedBox(height: 20),

              // Botão para alterar a foto do perfil
              ElevatedButton.icon(
                icon: Icon(Icons.camera_alt),
                label: Text('Alterar Foto de Perfil'),
                onPressed: _pickImage,  // Escolher imagem
              ),

              SizedBox(height: 40),

              // Campo de nome
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

              // Campo de data de nascimento com seletor de data
              GestureDetector(
                onTap: () => _pickDate(context),  // Abrir seletor de data
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

              // Campo de e-mail (apenas leitura)
              TextField(
                controller: _emailController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),

              SizedBox(height: 40),

              // Botão para salvar alterações
              ElevatedButton(
                onPressed: _saveProfile,
                child: Text('Salvar Alterações'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


