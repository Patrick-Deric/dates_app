import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';  // Import LoginPage for redirection

class VerifyEmailPage extends StatefulWidget {
  @override
  _VerifyEmailPageState createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isEmailVerified = false;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkEmailVerified();
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
      setState(() {
        _isEmailVerified = user?.emailVerified ?? false;
        _isVerifying = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao verificar o status: $e';
        _isVerifying = false;
      });
    }
  }

  // Resend the verification email
  Future<void> _resendVerificationEmail() async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              onPressed: _checkEmailVerified,  // Check again if verified
              child: Text('Já Verifiquei Meu Email'),
            ),
            SizedBox(height: 10),

            ElevatedButton(
              onPressed: _resendVerificationEmail,  // Resend verification email
              child: Text('Reenviar Verificação'),
            ),

            SizedBox(height: 20),

            _isEmailVerified
                ? Column(
              children: [
                Text(
                  'Email verificado com sucesso!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: Text('Ir para a página de Login'),
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
