import 'dart:convert';
import 'dart:io';
import 'package:article_21/article_21.dart';
import 'package:article_21/blockchain/user_encryption.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:article_21/providers/wallet_provider.dart';
import 'package:article_21/pages/home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3dart/web3dart.dart';

class CreateAccount extends StatefulWidget {
  const CreateAccount({Key? key}) : super(key: key);

  @override
  _CreateAccountState createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _cnfPasswordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mnemonicController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  String mnemonic = "";
  bool isVerified = false;
  bool showMnemonicUI = false;
  String verificationText = '';
  String selectedGender = "Select Gender";
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _mnemonicController.dispose();
    _cnfPasswordController.dispose();
    super.dispose();
  }

  Future<void> _confirmCredentials() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_termsAccepted) {
      _showSnackBar('Please accept the terms and conditions');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bool isDuplicate = await _checkDuplicateUsername(_emailController.text);
      
      if (isDuplicate) {
        _showSnackBar('Email is already registered');
        setState(() {
          _isLoading = false;
        });
        return;
      } else {
        setState(() {
          showMnemonicUI = true;
          _generateMnemonic();
        });
      }
    } catch (e) {
      _showSnackBar('Error checking email: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createAccount() async {
    if (mnemonic.isEmpty) {
      _showSnackBar('Mnemonic generation failed');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final privateKey = await walletProvider.getPrivateKey(mnemonic);

      // Get public key / wallet address properly
      final publicKey = await _getPublicKeyFromPrivateKey(privateKey);
      
      if (privateKey.isNotEmpty && publicKey != null) {
        await dotenv.load();
        String apiUrl = dotenv.env['SERVER_URL']!;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('privateKey', privateKey);
        await prefs.setString('mnemonic', mnemonic);
        await prefs.setString('wallet_address', publicKey);

        // Save user data to local file system
        final userData = {
          'mnemonic': mnemonic,
          'email': _emailController.text,
          'password': _passwordController.text,
          'name': _usernameController.text,
          'privateKey': privateKey,
          'walletAddress': publicKey,
        };
        await writeUserData(userData);

        final response = await http.post(
          Uri.parse('$apiUrl/signup'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8'
          },
          body: jsonEncode(<String, String>{
            'name': _usernameController.text,
            'email': _emailController.text,
            'password': _passwordController.text,
            'gender': selectedGender,
            'publicKey': publicKey,
          }),
        );

        if (response.statusCode == 200) {
          prefs.setString('email', _emailController.text);  
          prefs.setString('name', _usernameController.text);
          prefs.setString('gender', selectedGender);
          prefs.setBool('isLoggedIn', true);

          _showSuccessDialog();
        } else {
          _showSnackBar('Failed to create account: ${response.statusCode}');
          setState(() {
            _isLoading = false;
            showMnemonicUI = false;
          });
        }
      } else {
        _showSnackBar('Failed to generate wallet keys');
        setState(() {
          _isLoading = false;
          showMnemonicUI = false;
        });
      }
    } catch (e) {
      _showSnackBar('Error creating account: $e');
      setState(() {
        _isLoading = false;
        showMnemonicUI = false;
      });
    }
  }

  // Fixed method to properly get public key
  Future<String?> _getPublicKeyFromPrivateKey(String privateKey) async {
    try {
      final walletProvider = WalletProvider();
      await walletProvider.loadPrivateKey();
      
      // Correctly get the Ethereum address from private key
      final credentials = EthPrivateKey.fromHex(privateKey);
      final address = await credentials.extractAddress();
      
      return address.hex; // Return the hex string representation
    } catch (e) {

      return null;
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 60,
              ),
              SizedBox(height: 16),
              Text(
                "Account Created!",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            "Your account has been successfully created. Your wallet is ready to use.",
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                backgroundColor: Colors.indigo.shade900,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Continue",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Article21()),
                );
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
          contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 16),
          actionsPadding: EdgeInsets.only(bottom: 24),
        );
      },
    );
  }

  Future<bool> _checkDuplicateUsername(String email) async {
    try {
      await dotenv.load();
      String apiUrl = dotenv.env['SERVER_URL']!;

      final response = await http.get(Uri.parse('$apiUrl/checkUser/$email'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['message'] == "exists";
      } else {
        _showSnackBar('Server error, please try again later');
        return true;
      }
    } catch (e) {
      _showSnackBar('Network error, please check your connection');
      return true;
    }
  }

  void _generateMnemonic() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    mnemonic = walletProvider.generateMnemonic();
    _verifyMnemonic();
  }

  Future<void> _verifyMnemonic() async {
    if (mnemonic.trim().isNotEmpty) {
      Map<String, String> data = {
          'mnemonic': mnemonic,
          'email': _emailController.text,
          'password': _passwordController.text,
        };
      
      await writeUserData(data);

      setState(() {
        isVerified = true;
      });
      _createAccount();
    } else {
      setState(() {
        _isLoading = false;
        showMnemonicUI = false;
      });
      _showSnackBar('Mnemonic verification failed');
    }
  }

  // File management methods for storing and retrieving user data
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/user_data.json');
  }

  Future<File> writeUserData(Map<String, String> data) async {
    try {
      final file = await _localFile;
      return file.writeAsString(jsonEncode(data));
    } catch (e) {
      // Return an empty file to prevent errors
      final file = await _localFile;
      return file;
    }
  }

  Future<Map<String, String>> readUserData() async {
    try {
      final file = await _localFile;
      String contents = await file.readAsString();
      return Map<String, String>.from(jsonDecode(contents));
    } catch (e) {
      // If the file doesn't exist or can't be read, return an empty map
      return {};
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: message.contains('Failed') || message.contains('Error') 
            ? Colors.red.shade800 
            : Colors.indigo.shade900,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rest of the UI code remains the same
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.indigo.shade900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Create Account",
          style: TextStyle(
            color: Colors.indigo.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading && showMnemonicUI 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.indigo.shade900,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 24),
                  Text(
                    "Creating your account...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Generating your secure wallet",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Join Article 21',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Text(
                      'Create a new account to get started',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 32.0),
                    
                    // Name field
                    _buildInputField(
                      controller: _usernameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.0),
                    
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
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.0),
                    
                    // Confirm password field
                    _buildInputField(
                      controller: _cnfPasswordController,
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.0),
                    
                    // Gender dropdown
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: Colors.grey[600],
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                        ),
                        style: TextStyle(color: Colors.black87, fontSize: 16),
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down, color: Colors.indigo.shade900),
                        isExpanded: true,
                        items: <String>['Select Gender', 'Male', 'Female', 'Other']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedGender = newValue!;
                          });
                        },
                        validator: (value) {
                          if (value == 'Select Gender') {
                            return 'Please select your gender';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 24.0),
                    
                    // Terms and conditions
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _termsAccepted,
                            onChanged: (bool? value) {
                              setState(() {
                                _termsAccepted = value ?? false;
                              });
                            },
                            activeColor: Colors.indigo.shade900,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'I agree to the ',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: TextStyle(
                                    color: Colors.indigo.shade900,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  // Add tap gesture here
                                ),
                                TextSpan(
                                  text: ' and ',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: Colors.indigo.shade900,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  // Add tap gesture here
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32.0),
                    
                    // Create account button
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
                                'Creating Account...',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                    ),
                    SizedBox(height: 16.0),
                    
                    // Sign in option
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign In',
                                style: TextStyle(
                                  color: Colors.indigo.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
}