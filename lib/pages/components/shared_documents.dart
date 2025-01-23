import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/ecc/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SharedDocuments extends StatefulWidget {
  @override
  _SharedDocumentsState createState() => _SharedDocumentsState();
}

class _SharedDocumentsState extends State<SharedDocuments> {
  late Future<List<Map<String, dynamic>>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _documentsFuture = loadSharedDocuments();
  }

  Future<List<Map<String, dynamic>>> loadSharedDocuments() async {
    // Load environment variables
    await dotenv.load();
    final apiUrl = dotenv.env['SERVER_URL'];

    // Retrieve email from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('email'); // Replace 'email' with your key

    if (email == null || email.isEmpty) {
      throw Exception('Email not found in SharedPreferences');
    }

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/files'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'email': email,
        }),
      );

      print('Response: ${response.body}');
      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body)['files'];
        print(jsonResponse);
        return List<Map<String, dynamic>>.from(jsonResponse);
      } else {
        throw Exception('Failed to load shared documents');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _documentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No shared documents available.'));
          } else {
            final documents = snapshot.data!;
            return ListView.builder(
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final document = documents[index];
                return ListTile(
                  leading: Icon(Icons.description),
                  title: Text(document['title'] ?? 'Untitled Document'),
                  subtitle: Text('Uploaded by: ${document['uploadedBy'] ?? 'Unknown'}'),
                  onTap: () {
                    // Document decryption logic
                    print('Opening document: ${document['title']}');

                    // decryptFileFromIPFS(document['ipfsHash'], document['encryptedAESKey'], document['iv']);
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}

// Future<void> decryptFileFromIPFS(ipfs_hash, encryptedAESKey, IV iv) async {

//   SharedPreferences prefs = await SharedPreferences.getInstance();
//   String privateKeyHex = prefs.getString('privateKey')!;

//   final privateKey = ECPrivateKey(BigInt.parse(privateKeyHex, radix: 16), ECDomainParameters('secp256k1'));

//   String outputPath = './';

//   await decryptFileFromIPFS(ipfs_hash, encryptedAESKeyBase64, ivBase64, privateKey, outputPath);

// }
