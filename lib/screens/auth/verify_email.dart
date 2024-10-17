import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'dart:async'; // For Timer functionality

class VerifyEmailPage extends StatefulWidget {
  @override
  _VerifyEmailPageState createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isEmailVerified = false;
  bool _isVerifying = false;
  bool _canResendEmail = true;  // To disable button while email is being resent
  String? _errorMessage;
  Timer? _verificationCheckTimer;

  @override
  void initState() {
    super.initState();
    _checkEmailVerified();
    // Check email verification status every 5 seconds
    _verificationCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _checkEmailVerified();
    });
  }

  @override
  void dispose() {
    _verificationCheckTimer?.cancel();  // Cancel the timer when the widget is disposed
    super.dispose();
  }

  // Check if the user's email is verified
  Future<void> _checkEmailVerified() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      await user?.reload(); // Refresh user data
      if (user?.emailVerified ?? false) {
        _verificationCheckTimer?.cancel();  // Stop checking if verified
        setState(() {
          _isEmailVerified = true;
          _isVerifying = false;
        });

        // Show success message and redirect after 3 seconds
        Future.delayed(Duration(seconds: 3), () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        });
      } else {
        setState(() {
          _isEmailVerified = false;
          _isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao verificar o status: $e';
        _isVerifying = false;
      });
    }
  }

  // Resend the verification email
  Future<void> _resendVerificationEmail() async {
    if (_canResendEmail) {
      setState(() {
        _canResendEmail = false;  // Disable resend button temporarily
        _errorMessage = null;
      });

      try {
        User? user = FirebaseAuth.instance.currentUser;
        await user?.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Email de verificação reenviado com sucesso!'),
          backgroundColor: Colors.green,
        ));
      } catch (e) {
        setState(() {
          _errorMessage = 'Erro ao reenviar o email de verificação: $e';
        });
      } finally {
        // Re-enable the resend button after 5 seconds
        await Future.delayed(Duration(seconds: 5));
        setState(() {
          _canResendEmail = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Verificação de Email"),
      ),
      body: Center(
        child: _isVerifying
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Verifique seu email para continuar',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),

            if (_errorMessage != null)
              Text(_errorMessage!, style: TextStyle(color: Colors.red)),

            ElevatedButton(
              onPressed: _isVerifying ? null : _checkEmailVerified,
              child: Text('Já Verifiquei Meu Email'),
            ),
            SizedBox(height: 10),

            ElevatedButton(
              onPressed: _canResendEmail ? _resendVerificationEmail : null,
              child: _canResendEmail
                  ? Text('Reenviar Verificação')
                  : Text('Aguarde...'),
            ),

            SizedBox(height: 20),

            _isEmailVerified
                ? Column(
              children: [
                Text(
                  'Email verificado com sucesso!',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                CircularProgressIndicator(), // Show loading while redirecting
                SizedBox(height: 10),
                Text(
                  'Redirecionando para a página de login...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            )
                : Text(
              'Aguarde a verificação do email.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}


