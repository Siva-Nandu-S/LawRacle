import 'dart:convert';
import 'package:article_21/article_21.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _cnfPasswordController.text.isEmpty ||
        selectedGender == "Select Gender") {
      _showSnackBar('All fields are required');
      return;
    }

    if (_passwordController.text != _cnfPasswordController.text) {
      _showSnackBar('Passwords do not match');
      return;
    }

    final bool isDuplicate =
        await _checkDuplicateUsername(_emailController.text);
    if (isDuplicate) {
      _showSnackBar('Email is already registered');
      return;
    } else {
      setState(() {
        showMnemonicUI = true;
        _generateMnemonic();
      });
    }
  }

  Future<void> _createAccount() async {
    if (mnemonic.isEmpty) {
      _showSnackBar('Mnemonic generation failed');
      return;
    }

    String walletAddress = '';

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final privateKey = await walletProvider.getPrivateKey(mnemonic);

    if (privateKey != null) {
      final walletProvider = WalletProvider();
      await walletProvider.loadPrivateKey();
      EthereumAddress address = await walletProvider.getPublicKey(privateKey);
      setState(() {
        walletAddress = address.hex;
      });
    }

    if (privateKey.isNotEmpty) {
      _showSnackBar('Private key stored successfully');

      await dotenv.load();
      String apiUrl = dotenv.env['SERVER_URL']!;

      print(privateKey);
      print(walletAddress);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('privateKey', privateKey);

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
          'publicKey': walletAddress,
        }),
      );

      if (response.statusCode == 200) {
        prefs.setString('email', _emailController.text);  
        prefs.setString('name', _usernameController.text);
        prefs.setString('gender', selectedGender);

        Navigator.push(
            context, MaterialPageRoute(builder: (context) => Article21()));
      } else {
        _showSnackBar('Failed to create account');
      }
    } else {
      _showSnackBar('Failed to store private key');
    }
  }

  Future<bool> _checkDuplicateUsername(String email) async {
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
  }

  void _generateMnemonic() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    mnemonic = walletProvider.generateMnemonic();
    _verifyMnemonic();
  }

  void _verifyMnemonic() {
    if (mnemonic.trim() == mnemonic.trim()) {
      setState(() {
        isVerified = true;
      });
      _showSnackBar('Mnemonic verified successfully');
      _createAccount();
    } else {
      _showSnackBar('Mnemonic verification failed');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void navigateToHomePage() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => Home()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'LawRacle',
                style: TextStyle(
                    fontSize: 40.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007BFF)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32.0),
              if (!showMnemonicUI) ...[
                _buildTextField(_usernameController, 'Enter your name'),
                const SizedBox(height: 16.0),
                _buildTextField(_emailController, 'Enter your email'),
                const SizedBox(height: 16.0),
                _buildTextField(_passwordController, 'Enter your password',
                    obscureText: true),
                const SizedBox(height: 16.0),
                _buildTextField(_cnfPasswordController, 'Confirm your password',
                    obscureText: true),
                const SizedBox(height: 16.0),
                DropdownButton<String>(
                  value: selectedGender,
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
                  style: TextStyle(color: Colors.black),
                  dropdownColor: Colors.white,
                ),
                const SizedBox(height: 32.0),
                ElevatedButton(
                  onPressed: _confirmCredentials,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF007BFF),
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                  child: const Text(
                    'Confirm Credentials',
                    style: TextStyle(fontSize: 16.0, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText,
      {bool obscureText = false}) {
    return TextField(
      controller: mnemonic.isNotEmpty ? _mnemonicController : controller,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0),
      ),
      obscureText: obscureText,
      style: const TextStyle(color: Colors.black),
    );
  }
}
