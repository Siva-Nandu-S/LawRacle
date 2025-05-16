import 'package:article_21/article_21.dart';
import 'package:flutter/material.dart';
import 'package:article_21/providers/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home.dart';
import 'create_or_import.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }
  
  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }
    
    if (_isLoggedIn) {
      // If user is logged in, load the main app
      return Article21();
    } else {
      // If user is not logged in, load the CreateOrImportPage
      return const CreateOrImportPage();
    }
  }
  
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Container(
              width: 80,
              height: 80,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.gavel,
                size: 40,
                color: Colors.indigo.shade900,
              ),
            ),
            SizedBox(height: 24),
            
            // App name
            Text(
              'LAWRacle',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Loading your account...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 32),
            
            // Loading indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}