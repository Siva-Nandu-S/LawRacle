import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LawyersPage extends StatefulWidget {
  const LawyersPage({Key? key}) : super(key: key);

  @override
  _LawyersPageState createState() => _LawyersPageState();
}

class _LawyersPageState extends State<LawyersPage> {
  // Controllers for each TextField
  final TextEditingController _specialityController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // Loading state
  bool _isLoading = false;

  // Dispose controllers to avoid memory leaks
  @override
  void dispose() {
    _specialityController.dispose();
    _experienceController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> initiateDataEntry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      await dotenv.load();
      final apiUrl = dotenv.env['SERVER_URL'];

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? email = prefs.getString('email');

      if (email == null) {
        throw Exception('Email not found in local storage');
      }

      final response = await http.post(
        Uri.parse('$apiUrl/lawyers/data'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(<String, String>{
          'email': email,
          'speciality': _specialityController.text,
          'experience': _experienceController.text,
          'phone': _phoneController.text,
          'city': _cityController.text,
          'district': _districtController.text,
          'state': _stateController.text,
        }),
      );
      
      setState(() {
        _isLoading = false;
      });
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          )
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${response.statusCode}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lawyer Profile"),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background decoration
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              color: Theme.of(context).primaryColor,
            ),
          ),
          
          // Form content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.gavel,
                                  size: 48,
                                  color: Theme.of(context).primaryColor,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Complete Your Lawyer Profile",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Please provide your professional details",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 30),
                          
                          // Form fields
                          _buildSectionHeader("Professional Information"),
                          _buildValidatedTextField(
                            _specialityController, 
                            "Speciality",
                            "E.g., Criminal Law, Family Law",
                            Icons.work_outline,
                            (value) => value == null || value.isEmpty 
                              ? 'Please enter your speciality' 
                              : null,
                          ),
                          _buildValidatedTextField(
                            _experienceController, 
                            "Experience (in years)",
                            "E.g., 5",
                            Icons.timeline,
                            (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your years of experience';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                            keyboardType: TextInputType.number,
                          ),
                          SizedBox(height: 24),
                          
                          _buildSectionHeader("Contact Information"),
                          _buildValidatedTextField(
                            _phoneController, 
                            "Phone Number",
                            "E.g., 9876543210",
                            Icons.phone_outlined,
                            (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (value.length < 10) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                            keyboardType: TextInputType.phone,
                          ),
                          SizedBox(height: 24),
                          
                          _buildSectionHeader("Location"),
                          _buildValidatedTextField(
                            _cityController, 
                            "City",
                            "E.g., Mumbai",
                            Icons.location_city_outlined,
                            (value) => value == null || value.isEmpty 
                              ? 'Please enter your city' 
                              : null,
                          ),
                          _buildValidatedTextField(
                            _districtController, 
                            "District",
                            "E.g., Mumbai Suburban",
                            Icons.map_outlined,
                            (value) => value == null || value.isEmpty 
                              ? 'Please enter your district' 
                              : null,
                          ),
                          _buildValidatedTextField(
                            _stateController, 
                            "State",
                            "E.g., Maharashtra",
                            Icons.place_outlined,
                            (value) => value == null || value.isEmpty 
                              ? 'Please enter your state' 
                              : null,
                          ),
                          SizedBox(height: 30),
                          
                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () => _submitForm(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
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
                                      Text("Saving..."),
                                    ],
                                  )
                                : Text(
                                    "Save Profile",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  // Enhanced TextField with validation and icons
  Widget _buildValidatedTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
    String? Function(String?)? validator, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }

  // Method to handle form submission with confirmation
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Show confirmation dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Confirm Information"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Please verify your information before submitting:"),
                SizedBox(height: 16),
                _buildInfoRow("Speciality", _specialityController.text),
                _buildInfoRow("Experience", "${_experienceController.text} years"),
                _buildInfoRow("Phone", _phoneController.text),
                _buildInfoRow("City", _cityController.text),
                _buildInfoRow("District", _districtController.text),
                _buildInfoRow("State", _stateController.text),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[800],
              ),
              child: const Text("EDIT"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                initiateDataEntry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: const Text("CONFIRM"),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}