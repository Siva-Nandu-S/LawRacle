import 'dart:convert';
import 'dart:io';
import 'package:article_21/blockchain/user_encryption.dart';
import 'package:article_21/pages/yellow_pages.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart'; // Import for clipboard
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class PinataUploadPage extends StatefulWidget {
  final String lawyerPublicKeyPem;

  const PinataUploadPage({Key? key, required this.lawyerPublicKeyPem}): super(key: key);

  @override
  _PinataUploadPageState createState() => _PinataUploadPageState();
}

class _PinataUploadPageState extends State<PinataUploadPage> {
  String? _uploadedFileUrl;
  bool _isUploading = false;

  void initState() async{
    super.initState();
    await dotenv.load();
  }

  // Replace with your Pinata JWT
  final String? _pinataJwt = dotenv.env['PINATA_JWT']; // Make sure to replace this with your actual JWT.

  Future<void> _pickFileAndUpload() async {
    // Request permission for external storage
    var status = await Permission.storage.request();

    if (status.isGranted) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.single.path != null) {
          File file = File(result.files.single.path!);

          setState(() {
            _isUploading = true;
          });

          String url = "https://api.pinata.cloud/pinning/pinFileToIPFS";
          var request = http.MultipartRequest('POST', Uri.parse(url));

          // Adding headers
          request.headers['Authorization'] = 'Bearer $_pinataJwt';

          // Adding the file to the request
          request.files.add(await http.MultipartFile.fromPath('file', file.path));

          var response = await request.send();
          var responseData = await http.Response.fromStream(response);

          // Check if the response is successful
          if (response.statusCode == 200) {
            var jsonResponse = jsonDecode(responseData.body);

            // Check if the IpfsHash exists in the response
            if (jsonResponse.containsKey('IpfsHash')) {
              String ipfsHash = jsonResponse['IpfsHash'];
              encryptFile(ipfsHash, widget.lawyerPublicKeyPem!).then((encryptedIpfsHash) {
                print('Encrypted IPFS Hash: $encryptedIpfsHash');
                setState(() {
                  _uploadedFileUrl = ipfsHash;
                  _isUploading = false;
                });
              });
              Navigator.push(context, MaterialPageRoute(builder: (context) => YellowPages()));
            }
          }
        }
      } catch (e) {
        print('Error: $e');
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