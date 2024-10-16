import 'package:app_de_dates/screens/home/homescreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialization based on the platform
  await _initializeFirebase();

  runApp(MyApp());
}

Future<void> _initializeFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyDig63k8nIl0RUT_e_VaQm6re78EADE53k",
        authDomain: "app-de-dates.firebaseapp.com",
        projectId: "app-de-dates",
        storageBucket: "app-de-dates.appspot.com",
        messagingSenderId: "71304613127",
        appId: "1:71304613127:web:f23a67a7b7d212e3fa49a2",
        measurementId: "G-7VSYZ3DNY0",
      ),
    );
  } else if (Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DateFindr',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFFFF6F61),  // Warm Rose/Coral
        hintColor: Color(0xFFFFC107),   // Muted Gold for accents
        scaffoldBackgroundColor: Color(0xFFF5F5F5),  // Warm Grey/Beige background
        buttonTheme: ButtonThemeData(
          buttonColor: Color(0xFFFF6F61),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),  // Rounded corners
          ),
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D4037),  // Deep Brown
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Color(0xFF5D4037),  // Deep Brown
          ),
          labelLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      home: AuthWrapper(),  // AuthWrapper determines whether to show LoginPage or HomeScreen
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());  // Loading indicator while Firebase checks authentication
        }
        if (snapshot.hasData && snapshot.data != null) {
          return HomeScreen();  // User logged in
        }
        return LoginPage();  // If not logged in, show LoginPage
      },
    );
  }
}

