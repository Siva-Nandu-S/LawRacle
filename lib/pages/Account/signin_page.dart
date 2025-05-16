import 'dart:convert';
import 'package:article_21/article_21.dart';
import 'package:article_21/blockchain/user_encryption.dart';
import 'package:article_21/components/mnemonic_loader.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:article_21/providers/wallet_provider.dart';
import 'package:article_21/pages/home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3dart/web3dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  _SignInState createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mnemonicController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  String mnemonic = "";
  bool isVerified = false;
  bool showMnemonicUI = false;
  String verificationText = '';
  bool isNewUser = false;
  String walletAddress = '';
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _emailController.dispose();
    _mnemonicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.indigo.shade900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 20),
                  
                  // Header section
                  _buildHeaderSection(),
                  SizedBox(height: 40),
                  
                  // Form section
                  if (!showMnemonicUI)
                    _buildLoginForm()
                  else
                    _buildLoadingSection(),
                  
                  SizedBox(height: 16),
                  
                  // Footer section
                  _buildFooterSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.lock_outlined,
                color: Colors.indigo.shade900,
                size: 28,
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Sign in to access your account',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email field
          _buildInputField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          SizedBox(height: 16.0),
          
          // Password field
          _buildInputField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          SizedBox(height: 8.0),
          
          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // Implement forgot password functionality
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  color: Colors.indigo.shade900,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(height: 24.0),
          
          // Sign in button
          ElevatedButton(
            onPressed: _isLoading ? null : _confirmCredentials,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade900,
              disabledBackgroundColor: Colors.indigo.shade200,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: _isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Signing In...',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 30),
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade900),
          strokeWidth: 3,
        ),
        SizedBox(height: 24),
        Text(
          'Accessing your account...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Please wait while we verify your credentials',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterSection() {
    return Column(
      children: [
        SizedBox(height: 16),
        SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pop(context); // Go back to create account page
              },
              child: Text(
                'Sign Up',
                style: TextStyle(
                  color: Colors.indigo.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.black87, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.indigo.shade900, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade700, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }

  void _confirmCredentials() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        _showSnackBar('All fields are required');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      var userData = await readUserData();

      if (userData.isNotEmpty) {
        final userEmail = userData['email'];
        final userPassword = userData['password'];

        await dotenv.load();
        String apiUrl = dotenv.env['SERVER_URL']!;

        if (_emailController.text == userEmail &&
            _passwordController.text != userPassword) {
          _showSnackBar('Invalid password');
          setState(() {
            _isLoading = false;
          });
          return;
        } else if (_emailController.text != userEmail) {
          final response = await http.post(
            Uri.parse('$apiUrl/check-user'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8'
            },
            body: jsonEncode(<String, String>{
              'email': _emailController.text,
              'password': _passwordController.text,
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['status'] == 'success') {
              setState(() {
                showMnemonicUI = true;
                isNewUser = true;
                _generateMnemonic();
              });
            } else {
              _showSnackBar('Invalid credentials');
              setState(() {
                _isLoading = false;
              });
              return;
            }
          } else {
            _showSnackBar('Please try again later');
            setState(() {
              _isLoading = false;
            });
            return;
          }
        } else {
          setState(() {
            showMnemonicUI = true;
            isNewUser = false;
            _generateMnemonic();
          });
        }

        setState(() {
          showMnemonicUI = true;
          _generateMnemonic();
        });
      } else {
        setState(() {
          showMnemonicUI = true;
          _generateMnemonic();
        });
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: message.contains('Invalid') || message.contains('error') 
          ? Colors.red.shade800 
          : Colors.indigo.shade900,
      ),
    );
  }

  void navigateToHomePage() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => Home()));
  }

  void _generateMnemonic() {
    if (isNewUser) {
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      mnemonic = walletProvider.generateMnemonic();
      _verifyMnemonic();
    } else {
      readUserData().then((value) {
        if (value.isNotEmpty) {
          setState(() {
            mnemonic = value['mnemonic']!;
            isVerified = true;
          });
        } else {
          setState(() {
            final walletProvider =
                Provider.of<WalletProvider>(context, listen: false);
            mnemonic = walletProvider.generateMnemonic();
          });
        }

        _verifyMnemonic();
      });
    }
  }

  void _verifyMnemonic() {
    if (mnemonic.trim() == mnemonic.trim()) {
      setState(() {
        isVerified = true;
      });
      // Don't show mnemonic verification message anymore
      _createAccount();
    } else {
      setState(() {
        _isLoading = false;
        showMnemonicUI = false;
      });
      _showSnackBar('Account verification failed');
    }
  }

  Future<void> _createAccount() async {
    if (mnemonic.isEmpty) {
      _showSnackBar('Verification failed');
      setState(() {
        _isLoading = false;
        showMnemonicUI = false;
      });
      return;
    }

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final privateKey = await walletProvider.getPrivateKey(mnemonic);

      if (privateKey.isNotEmpty) {
        final walletProvider = WalletProvider();
        await walletProvider.loadPrivateKey();
        EthereumAddress address = await walletProvider.getPublicKey(privateKey);
        setState(() {
          walletAddress = address.hex;
        });
        
        await dotenv.load();
        String apiUrl = dotenv.env['SERVER_URL']!;

        final response = await http.post(
          Uri.parse('$apiUrl/login'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8'
          },
          body: jsonEncode(<String, String>{
            'email': _emailController.text,
            'password': _passwordController.text,
            'publicKey': walletAddress,
          }),
        );

        if (response.statusCode == 200) {
          final name = jsonDecode(response.body)['name'];

          Map<String, String> data = {
            'mnemonic': mnemonic,
            'password': _passwordController.text,
            'name': name,
            'email': _emailController.text,
          };

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('email', _emailController.text);
          await prefs.setString('name', name);
          await prefs.setString('wallet_address', walletAddress);
          await prefs.setBool('isLoggedIn', true);

          await writeUserData(data);

          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => Article21()));
        } else {
          setState(() {
            _isLoading = false;
            showMnemonicUI = false;
          });
          _showSnackBar('Failed to login to account');
        }
      } else {
        setState(() {
          _isLoading = false;
          showMnemonicUI = false;
        });
        _showSnackBar('Failed to verify wallet');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        showMnemonicUI = false;
      });
      _showSnackBar('Error signing in: $e');
    }
  }
}