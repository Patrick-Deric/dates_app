import 'package:app_de_dates/screens/auth/verify_email.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  // For Firestore user collection

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSigningUp = false;
  String? _errorMessage;

  // Function to register the user with email and password
  Future<void> _registerWithEmailAndPassword() async {
    setState(() {
      _isSigningUp = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      if (password != confirmPassword) {
        setState(() {
          _errorMessage = 'As senhas não coincidem.';
          _isSigningUp = false;
          return;
        });
      }

      // Register the user with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // After registration, create a user document in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'role': 'regular',  // Default role is "regular"
        'createdAt': Timestamp.now(),
      });

      // Create a blank profile subcollection to hold user profile data
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).collection('profile').doc('info').set({
        'fullName': '',
        'dateOfBirth': '',
      });

      // Send verification email
      await userCredential.user!.sendEmailVerification();

      // Navigate to Verify Email Page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => VerifyEmailPage()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao registrar: $e';
      });
    } finally {
      setState(() {
        _isSigningUp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Crie sua conta",
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),

              // Email field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 20),

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 20),

              // Confirm password field
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirme a senha',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 20),

              _isSigningUp
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _registerWithEmailAndPassword,
                child: Text('Registrar'),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),

              SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);  // Go back to login
                },
                child: Text('Já tem uma conta? Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


