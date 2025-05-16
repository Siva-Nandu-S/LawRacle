import 'dart:convert';
import 'dart:io';
import 'package:article_21/article_21.dart';
import 'package:article_21/blockchain/user_encryption.dart';
import 'package:article_21/pages/yellow_pages.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart'; // Import for clipboard
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/src/credentials/address.dart';
import 'package:article_21/blockchain/upload_to_blockchain.dart';

class PinataUploadPage extends StatefulWidget {
  final EthereumAddress lawyerWalletAddress;
  final String lawyerEmail;

  const PinataUploadPage(
      {key, required this.lawyerWalletAddress, required this.lawyerEmail})
      : super(key: key);

  @override
  _PinataUploadPageState createState() => _PinataUploadPageState();
}

class _PinataUploadPageState extends State<PinataUploadPage> {
  String? _uploadedFileUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadEnvironment();
  }

// New method for loading the environment asynchronously
  Future<void> _loadEnvironment() async {
    await dotenv.load();
  }

  // Replace with your Pinata JWT
  final String? _pinataJwt = dotenv
      .env['PINATA_JWT']; // Make sure to replace this with your actual JWT.

  final String? _serverUrl = dotenv.env['SERVER_URL'];

  Future<void> _pickFileAndUpload() async {
    // Request permission for external storage
    Map<Permission, PermissionStatus> statuses = await [
    Permission.storage,
    Permission.photos,
    Permission.videos,
  ].request();

  // Check if any of the permissions are granted
  bool hasPermission = statuses[Permission.storage] == PermissionStatus.granted || 
                       statuses[Permission.photos] == PermissionStatus.granted;

    if (hasPermission) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.single.path != null) {
          File file = File(result.files.single.path!);

          setState(() {
            _isUploading = true;
          });


          // String _PEMLawyerPublicKey =
          //     convertPublicKeyToPEM(widget.lawyerWalletAddress);

          Map<String, dynamic> encryptedData =
              await EncryptionService.encryptFileWithAccessControl(
            file,
            widget.lawyerWalletAddress,
          );

          String encryptedFile = encryptedData['encryptedFilePath'];


          String url = "https://api.pinata.cloud/pinning/pinFileToIPFS";
          var request = http.MultipartRequest('POST', Uri.parse(url));

          request.headers['Authorization'] = 'Bearer $_pinataJwt';

          request.files.add(
              await http.MultipartFile.fromPath('file', encryptedFile));

          var response = await request.send();
          var responseData = await http.Response.fromStream(response);

          if (response.statusCode == 200) {
            var jsonResponse = jsonDecode(responseData.body);

            if (jsonResponse.containsKey('IpfsHash')) {
              String ipfsHash = jsonResponse['IpfsHash'];


              // await serverCaching(
              //     widget.lawyerEmail, widget.lawyerWalletAddress as String, ipfsHash, _serverUrl!, encryptedAESKey, iv);

              await uploadToBlockchain(context, ipfsHash,
                  widget.lawyerWalletAddress);

              setState(() {
                _uploadedFileUrl = ipfsHash;
                _isUploading = false;
              });

              // Navigate to the YellowPages page
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => Article21()));
            }
          } else {
            setState(() {
              _isUploading = false;
            });
          }
        }
      } catch (e) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload to IPFS'),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _pickFileAndUpload,
              child: Text('Pick a file and upload to IPFS'),
            ),
            if (_isUploading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            if (_uploadedFileUrl != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Sended file URL: $_uploadedFileUrl'),
              ),
          ],
        ),
      ),
    );
  }
}

serverCaching(String lawyerEmail, String lawyerWalletAddress, String ipfsHash,
    String _serverUrl, String encryptedAESKey, IV iv) async {
  try {
    final response = await http.post(
      Uri.parse('$_serverUrl/cacheFiles'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'lawyerEmail': lawyerEmail,
        'lawyerPublicKey': lawyerWalletAddress,
        'ipfsHash': ipfsHash,
        'encryptedAESKey': encryptedAESKey,
        'iv': iv.base64,
      }),
    );

    if (response.statusCode == 200) {
    } else {
      throw Exception('Failed to cache data');
    }
  } catch (e) {
    throw Exception('Error: $e');
  }
}