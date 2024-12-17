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

    await dotenv.load();
    final apiUrl = dotenv.env['SERVER_URL'];

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('email');

    final response = await http.post(
        Uri.parse('$apiUrl/lawyers/data'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(<String, String>{
          'email': email!,
          'speciality': _specialityController.text,
          'experience': _experienceController.text,
          'phone': _phoneController.text,
          'city': _cityController.text,
          'district': _districtController.text,
          'state': _stateController.text,
        }),
      );
    
    if (response.statusCode == 200) {
      SnackBar snackBar = SnackBar(content: Text('Data entered successfully'));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      Navigator.pop(context);
    }else{
      SnackBar snackBar = SnackBar(content: Text('Failed to enter data'));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lawyers Page"),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(_specialityController, "Speciality"),
              _buildTextField(_experienceController, "Experience (in years)"),
              _buildTextField(_phoneController, "Phone Number"),
              _buildTextField(_cityController, "City"),
              _buildTextField(_districtController, "District"),
              _buildTextField(_stateController, "State"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text("Submit"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to create a TextField with a label
  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        keyboardType: label == "Phone Number" || label == "Experience (in years)"
            ? TextInputType.number
            : TextInputType.text,
      ),
    );
  }

  // Method to handle form submission
  void _submitForm() {
    // Collecting the form data
    String speciality = _specialityController.text;
    String experience = _experienceController.text;
    String phone = _phoneController.text;
    String city = _cityController.text;
    String district = _districtController.text;
    String state = _stateController.text;

    // Displaying the collected data (You can replace this with your backend logic)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Form Data"),
        content: Text(
          "Speciality: $speciality\n"
          "Experience: $experience\n"
          "Phone: $phone\n"
          "City: $city\n"
          "District: $district\n"
          "State: $state",
        ),
        actions: [
          TextButton(
            onPressed: initiateDataEntry,
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
