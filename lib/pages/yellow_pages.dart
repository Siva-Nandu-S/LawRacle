import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:article_21/blockchain/upload_to_ipfs.dart';

class YellowPages extends StatefulWidget {
  const YellowPages({Key? key}) : super(key: key);

  @override
  _YellowPagesState createState() => _YellowPagesState();
}

class _YellowPagesState extends State<YellowPages> {
  late Future<List<Map<String, dynamic>>> _lawyersFuture;

  @override
  void initState() {
    super.initState();
    _lawyersFuture = loadYellowPages();
  }

  Future<List<Map<String, dynamic>>> loadYellowPages() async {
    await dotenv.load();
    final apiUrl = dotenv.env['SERVER_URL'];

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/lawyers'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(jsonResponse);
      } else {
        throw Exception('Failed to load yellow pages');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  void _handleChat(String lawyerEmail) {
    // Implement your chat functionality here
    print('Starting chat with $lawyerEmail');
  }

  void _handleSendDocument(String publicKey) {
    // Implement your send document functionality here
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinataUploadPage(lawyerPublicKeyPem: publicKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _lawyersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No lawyers available.'));
          } else {
            final lawyers = snapshot.data!;
            return ListView.builder(
              itemCount: lawyers.length,
              itemBuilder: (context, index) {
                final lawyer = lawyers[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Name: ${lawyer['name']}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Email: ${lawyer['email']}'),
                        Text('Gender: ${lawyer['gender']}'),
                        Text('Speciality: ${lawyer['speciality']}'),
                        Text('Experience: ${lawyer['experience']} years'),
                        Text('Phone: ${lawyer['phone']}'),
                        Text('City: ${lawyer['city']}'),
                        Text('District: ${lawyer['district']}'),
                        Text('State: ${lawyer['state']}'),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () => _handleChat(lawyer['email']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              child: const Text('Chat'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => _handleSendDocument(lawyer['public_key']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text('Send Document'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
