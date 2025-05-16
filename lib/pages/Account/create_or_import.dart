import 'package:article_21/pages/Account/createAccount.dart';
import 'package:article_21/pages/Account/signin_page.dart';
import 'package:flutter/material.dart';

class CreateOrImportPage extends StatelessWidget {
  const CreateOrImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height: screenHeight - MediaQuery.of(context).padding.top,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                // Top spacer
                SizedBox(height: screenHeight * 0.06),
                
                // App Logo and Title
                _buildLogo(),
                SizedBox(height: screenHeight * 0.04),
                
                // Welcome Message
                _buildWelcomeText(),
                SizedBox(height: screenHeight * 0.06),
                
                // Image/Illustration
                Expanded(
                  flex: 3,
                  child: _buildIllustration(),
                ),
                
                // Bottom action buttons
                Expanded(
                  flex: 2,
                  child: _buildActionButtons(context),
                ),
                
                // Footer
                _buildFooter(),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.indigo.shade900,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.gavel,
            color: Colors.white,
            size: 24,
          ),
        ),
        SizedBox(width: 12),
        Text(
          'LawRacle',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Welcome to LawRacle',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        Text(
          'The best place to manage your legal documents',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildIllustration() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background shape
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.indigo.shade50,
            ),
          ),
          // Image
          Image.asset(
            'assets/images/artificial-intelligence.png',
            width: 240,
            fit: BoxFit.contain,
          ),
          // Optional decorative elements
          Positioned(
            top: 20,
            right: 50,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.indigo.shade200,
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 60,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.indigo.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sign Up Button
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateAccount(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade900,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Create Account',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        
        SizedBox(height: 16),
        
        // Login Button
        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SignIn(),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.indigo.shade900,
            side: BorderSide(color: Colors.indigo.shade900),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Login to Existing Account',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        
        SizedBox(height: 24),
        
        // Terms & Privacy
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'By continuing, you agree to our ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            GestureDetector(
              onTap: () {
                // Navigate to Terms of Service
              },
              child: Text(
                'Terms & Privacy Policy',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          '© 2024 JRSS. All rights reserved.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Version 1.0.0',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }
}