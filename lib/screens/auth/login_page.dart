import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_page.dart';  // Link to the Register Page

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;  // Controls password visibility
  bool _isSigningIn = false;
  String? _errorMessage;

  // Email & Password sign-in function
  Future<void> _signInWithEmailAndPassword() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Sign in the user with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if Firestore user exists and has the correct role
      final userId = userCredential.user!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        String role = userDoc.get('role');

        // Assuming "regular" role is allowed, you can add checks for other roles later
        if (role == 'regular') {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          setState(() {
            _errorMessage = 'Usuário não tem permissão suficiente.';
          });
          await FirebaseAuth.instance.signOut();
        }
      } else {
        setState(() {
          _errorMessage = 'Usuário não encontrado no Firestore.';
        });
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao fazer login: Verifique suas credenciais.';
      });
    } finally {
      setState(() {
        _isSigningIn = false;
      });
    }
  }

// Google sign-in function
  Future<User?> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _isSigningIn = false;
        });
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Authenticate with Firebase
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Check if Firestore user exists
      final userId = userCredential.user!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        // Create user in Firestore if they don't exist
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'email': userCredential.user!.email,
          'role': 'regular',  // Default role for new Google sign-in
          'createdAt': Timestamp.now(),
        });
      }

      // After successful sign-in, navigate to the HomeScreen
      Navigator.pushReplacementNamed(context, '/home');

      return userCredential.user;
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao fazer login com Google: $e';
      });
      return null;
    } finally {
      setState(() {
        _isSigningIn = false;
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
              // Welcome text
              Text(
                "Bem-vindo de volta",
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // Email input field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Endereço de Email*',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 20),

              // Password input field with toggle visibility
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,  // Toggle password visibility
                decoration: InputDecoration(
                  labelText: 'Senha*',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Continue button (for email and password login)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,  // Use Warm Rose
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _signInWithEmailAndPassword,
                child: Text("Continuar"),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              SizedBox(height: 20),

              // "Don't have an account? Sign up"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Não tem uma conta? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RegisterPage()),
                      );
                    },
                    child: Text(
                      "Registre-se",
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // OR divider
              Row(
                children: [
                  Expanded(child: Divider(thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text("OU"),
                  ),
                  Expanded(child: Divider(thickness: 1)),
                ],
              ),
              SizedBox(height: 20),

              // Google Sign-in button
              _isSigningIn
                  ? CircularProgressIndicator()
                  : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black, backgroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(color: Colors.grey),  // Border for Google button
                  ),
                ),
                icon: Image.asset('assets/google_icon.png', height: 24),  // Assuming Google icon asset
                label: Text('Continuar com Google'),
                onPressed: _signInWithGoogle,
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}


