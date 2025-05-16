import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as Math;

import 'package:article_21/blockchain/user_encryption.dart';
import 'package:article_21/components/mnemonic_loader.dart';
import 'package:article_21/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class OpenDocumentFromIpfs extends StatefulWidget {
  final String ipfsHash;

  const OpenDocumentFromIpfs({Key? key, required this.ipfsHash})
      : super(key: key);

  @override
  _OpenDocumentFromIpfsState createState() => _OpenDocumentFromIpfsState();
}

class _OpenDocumentFromIpfsState extends State<OpenDocumentFromIpfs> {
  String? _decryptedFilePath;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
  }

  Future<void> openDocument(String ipfsHash) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Fetch the file content from IPFS
      final ipfsContent = await fetchFromIPFS(ipfsHash);

      // Decrypt the base64 content
      final decryptedFilePath = await decryptAndSaveFile(ipfsContent);

      // Show success message
      _showSnackBar('Document decrypted and saved successfully');

      // Update the state to display the file
      setState(() {
        _decryptedFilePath = decryptedFilePath;
        _isLoading = false;
      });

      // Open the file using the system default app
      await openFileWithSystemApp(decryptedFilePath);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      _showSnackBar('Error: $e');
    }
  }

  Future<String> decryptAndSaveFile(String encryptedBase64Content) async {
  // Create a unique output file path
  final tempDir = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final outputFilePath = '${tempDir.path}/decrypted_document_$timestamp.pdf';

  try {
    debugPrint('Received content length: ${encryptedBase64Content.length}');
    debugPrint('Content prefix: ${encryptedBase64Content.substring(0, Math.min(20, encryptedBase64Content.length))}...');

    // Fix potential base64 padding issues
    String paddedContent = encryptedBase64Content;
    while (paddedContent.length % 4 != 0) {
      paddedContent += '=';
    }

    // Decode the base64 content
    final encryptedBytes = base64Decode(paddedContent);
    debugPrint('Successfully decoded base64 content to bytes: ${encryptedBytes.length} bytes');

    // Decrypt the content
    final decryptedBytes = await EncryptionService.decryptBase64WithAccessControl(base64Encode(encryptedBytes));
    debugPrint('Successfully decrypted content: ${decryptedBytes.length} bytes');

    // Try to directly save the decrypted bytes first instead of assuming it's base64-encoded
    try {
      // Save the decrypted bytes directly to a file
      final file = File(outputFilePath);
      await file.writeAsBytes(decryptedBytes);
      debugPrint('Saved decrypted bytes directly to file');
      return outputFilePath;
    } catch (directSaveError) {
      debugPrint('Failed to save decrypted bytes directly: $directSaveError');
      
      // If direct save fails, try the original approach assuming base64 encoding
      // Convert decrypted bytes to a string
      final decryptedString = utf8.decode(decryptedBytes);
      debugPrint('Decoded bytes to string length: ${decryptedString.length}');

      // Check if the decrypted string is base64
      if (!_isValidBase64(decryptedString)) {
        debugPrint('Decrypted content is not valid base64, trying to save as raw content');
        // Try to save it as raw content
        final file = File(outputFilePath);
        await file.writeAsString(decryptedString);
        return outputFilePath;
      }

      // If it's base64, decode it to get the original file bytes
      final originalFileBytes = base64Decode(decryptedString);
      debugPrint('Successfully decoded inner base64 content: ${originalFileBytes.length} bytes');

      // Save the original file bytes to a file
      final file = File(outputFilePath);
      await file.writeAsBytes(originalFileBytes);
      debugPrint('Saved decoded file content successfully');
      return outputFilePath;
    }
  } catch (e) {
    debugPrint('Error in decryptAndSaveFile: $e');
    if (e is FormatException) {
      debugPrint('Base64 decode error at offset: ${e.offset}');
      // Try alternative approach for encryption/decryption
      return await _tryAlternativeDecryption(encryptedBase64Content, outputFilePath);
    }
    throw e;  // Re-throw the exception if it's not a FormatException
  }
}

// More robust base64 validation
bool _isValidBase64(String str) {
  try {
    // More lenient regex that accounts for potential whitespace and line breaks
    final cleanedStr = str.replaceAll(RegExp(r'[\s\r\n]'), '');
    final base64Regex = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
    if (!base64Regex.hasMatch(cleanedStr) || cleanedStr.length % 4 != 0) {
      return false;
    }
    
    // Try decoding to validate
    base64Decode(cleanedStr);
    return true;
  } catch (e) {
    return false;
  }
}

// Alternative decryption approach
Future<String> _tryAlternativeDecryption(String encryptedContent, String outputFilePath) async {
  try {
    debugPrint('Trying alternative decryption approach');
    // Use the decryptFileWithProperFormat method instead
    final decodedBytes = base64Decode(encryptedContent);
    
    // Create a temporary file
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFilePath = '${tempDir.path}/encrypted_temp_$timestamp';
    final encryptedFile = File(tempFilePath);
    await encryptedFile.writeAsBytes(decodedBytes);
    
    // Use the alternative method
    final result = await decryptFileWithProperFormat(
      encryptedContent,
      '', // ivBase64 (not used in your implementation)
      EthereumAddress.fromHex('0x0000000000000000000000000000000000000000') // placeholder
    );
    
    debugPrint('Alternative decryption successful');
    return result;
  } catch (e) {
    debugPrint('Alternative decryption also failed: $e');
    throw FormatException('Failed to decrypt file content: $e');
  }
}

  Future<void> openFileWithSystemApp(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        _showSnackBar('Could not open file: ${result.message}');
      }
    } catch (e) {
      _showSnackBar('Error opening file: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: message.contains('Error')
            ? Colors.red.shade800
            : Colors.indigo.shade900,
      ),
    );
  }

  Future<String> fetchFromIPFS(String ipfsHash) async {
    final gateways = [
      'https://gateway.pinata.cloud/ipfs/',
      'https://ipfs.io/ipfs/',
      'https://cloudflare-ipfs.com/ipfs/',
      'https://dweb.link/ipfs/'
    ];

    Exception? lastError;

    for (final gateway in gateways) {
      try {
        final response = await http.get(
          Uri.parse('$gateway$ipfsHash'),
          headers: {'Accept': '*/*'},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final content = response.body;

          // Log the content for debugging
          debugPrint('Fetched content: $content');

          // Validate if the content is base64
          if (!isBase64(content)) {
            throw FormatException('Fetched content is not valid base64');
          }

          return content;
        }
      } catch (e) {
        lastError = Exception('Failed to fetch from $gateway: $e');
      }
    }

    throw lastError ?? Exception('All IPFS gateways failed');
  }

  bool isBase64(String str) {
    final base64Regex = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
    return base64Regex.hasMatch(str) && (str.length % 4 == 0);
  }

  Future<String> decryptFileWithProperFormat(String encryptedFileBase64,
      String ivBase64, EthereumAddress encryptedWalletAddress) async {
    // Create a unique output file path
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputFilePath = '${tempDir.path}/decrypted_document_$timestamp.pdf';

    // Create a temporary file from the decoded bytes
    final decodedBytes = base64Decode(encryptedFileBase64);
    final tempFilePath = '${tempDir.path}/encrypted_temp_$timestamp';
    final encryptedFile = File(tempFilePath);
    await encryptedFile.writeAsBytes(decodedBytes);

    // Decrypt the file with proper format
    final decryptedBytes =
        await EncryptionService.decryptFileWithAccessControl(encryptedFile);

    // Note: If you need to pass IV and wallet address, update the EncryptionService method
    // to accept these parameters or use a different method that accepts them

    // Save the decrypted file
    await EncryptionService.saveDecryptedFile(
        Uint8List.fromList(decryptedBytes), outputFilePath);

    // Clean up the temporary file
    await encryptedFile.delete();

    return outputFilePath;
  }

  Future<String> saveRawFileContent(String content) async {
    // Create a unique output file path
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputFilePath = '${tempDir.path}/document_$timestamp.pdf';

    // Save the raw file content
    final file = File(outputFilePath);
    await file.writeAsBytes(content.codeUnits);

    return outputFilePath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Document Viewer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.indigo.shade900,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.indigo.shade900),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Processing document...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Fetching from IPFS and decrypting',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 70,
                          color: Colors.red.shade400,
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Failed to open document',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => openDocument(widget.ipfsHash),
                          icon: Icon(Icons.refresh),
                          label: Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade900,
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _decryptedFilePath != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 70,
                            color: Colors.green,
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Document processed successfully',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'The file has been saved to your device and opened with the default app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () =>
                                openFileWithSystemApp(_decryptedFilePath!),
                            icon: Icon(Icons.open_in_new),
                            label: Text('Open Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade900,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.description_outlined,
                              size: 70,
                              color: Colors.indigo.shade900,
                            ),
                          ),
                          SizedBox(height: 32),
                          Text(
                            'Ready to view document',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 16),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Click the button below to fetch and decrypt your document from IPFS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () => openDocument(widget.ipfsHash),
                            icon: Icon(Icons.file_open),
                            label: Text('Open Document'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade900,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
