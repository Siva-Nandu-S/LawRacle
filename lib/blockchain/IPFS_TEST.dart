import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart'; // Import for clipboard
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class PinataUploadPage extends StatefulWidget {
  @override
  _PinataUploadPageState createState() => _PinataUploadPageState();
}

class _PinataUploadPageState extends State<PinataUploadPage> {
  String? _uploadedFileUrl;
  bool _isUploading = false;

  // Replace with your Pinata JWT
  final String _pinataJwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySW5mb3JtYXRpb24iOnsiaWQiOiJlNTEyZWQ1NC0zYzRmLTQ1NmMtYTA2Mi03NzhmMjM4ZGE0MzEiLCJlbWFpbCI6InNpdmFuYW5kdXMyQGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJwaW5fcG9saWN5Ijp7InJlZ2lvbnMiOlt7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6IkZSQTEifSx7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6Ik5ZQzEifV0sInZlcnNpb24iOjF9LCJtZmFfZW5hYmxlZCI6ZmFsc2UsInN0YXR1cyI6IkFDVElWRSJ9LCJhdXRoZW50aWNhdGlvblR5cGUiOiJzY29wZWRLZXkiLCJzY29wZWRLZXlLZXkiOiJhYzA5ZTA1NWViZGQ3NjA2ZWE1OSIsInNjb3BlZEtleVNlY3JldCI6ImMwZTdlYTRlZTA2Mjg0NDEyMjhkZjcxNGYwOTJiN2NjOTYyMWZkMjA5YzRkZjgxMGNmNTgxNzBjOGFlOWU3NDIiLCJleHAiOjE3NjAwMTIzNTZ9.NSAIOnfKnefEt31hjh-MQgcrwH5SGM201qKTtIeKxyc"; // Make sure to replace this with your actual JWT.

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
              setState(() {
                _uploadedFileUrl = "https://gateway.pinata.cloud/ipfs/$ipfsHash"; // Construct URL
                _isUploading = false;
              });

              // Open the uploaded file in the browser
              _launchInBrowser(_uploadedFileUrl!);
            } else {
              setState(() {
                _isUploading = false;
              });
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
    } else {
      // Handle the case when permission is denied
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permission denied')));
    }
  }

  // Method to open the uploaded file in the browser
  Future<void> _launchInBrowser(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $url')));
    }
  }

  // Method to copy the file URL to the clipboard
  Future<void> _copyToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload File to IPFS'),
      ),
      body: Center(
        child: _isUploading
            ? CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _pickFileAndUpload,
                    child: Text('Pick File and Upload to IPFS'),
                  ),
                  if (_uploadedFileUrl != null) ...[
                    SizedBox(height: 20),
                    Text('Uploaded File URL:'),
                    InkWell(
                      onTap: () => _launchInBrowser(_uploadedFileUrl!),
                      child: Text(
                        _uploadedFileUrl!,
                        style: TextStyle(color: Colors.blue),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _copyToClipboard(_uploadedFileUrl!),
                      child: Text('Copy Link'),
                    ),
                  ]
                ],
              ),
      ),
    );
  }
}
