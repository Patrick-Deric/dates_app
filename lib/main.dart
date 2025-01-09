import 'package:app_de_dates/screens/home/homescreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialization
  try {
    await _initializeFirebase();
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  runApp(MyApp());
}

// Consolidated Firebase initialization method
Future<void> _initializeFirebase() async {
  if (Firebase.apps.isEmpty) {
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
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DateFindr',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFFF6F61),  // Warm Rose/Coral
        hintColor: const Color(0xFFFFC107),   // Muted Gold for accents
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),  // Warm Grey/Beige background
        buttonTheme: ButtonThemeData(
          buttonColor: const Color(0xFFFF6F61),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),  // Rounded corners
          ),
        ),
        textTheme: const TextTheme(
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
      initialRoute: '/',  // Define the initial route
      routes: {
        '/': (context) => const AuthWrapper(),  // Entry point
        '/home': (context) => HomeScreen(),  // Route to HomeScreen
        '/login': (context) => LoginPage(),  // Route to LoginPage for flexibility
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),  // Loading spinner
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                'An error occurred. Please try again later.',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User authenticated
          return HomeScreen();
        }

        // User not authenticated
        return LoginPage();
      },
    );
  }
}
