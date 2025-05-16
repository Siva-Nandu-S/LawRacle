import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:article_21/blockchain/retrieve_from_blockchain.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import './user_encryption.dart';

class FileRetrievalService {
  final String ipfsGateway;
  final Credentials userCredentials;
  final EthereumAddress userAddress;

  FileRetrievalService({
    required this.userCredentials,
    required this.userAddress,
    this.ipfsGateway = 'https://gateway.pinata.cloud/ipfs',
  });

  /// Fetch content from IPFS using the hash
  Future<Map<String, dynamic>> fetchFromIPFS(String ipfsHash) async {
    try {
      final response = await http.get(Uri.parse('$ipfsGateway$ipfsHash'));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch file from IPFS: ${response.statusCode}');
      }
      
      // Parse the JSON content that contains encrypted file data
      return json.decode(response.body);
    } catch (e) {
      throw Exception('Error fetching from IPFS: $e');
    }
  }

  /// Decrypt file content from IPFS
  Future<Uint8List> decryptFileFromIPFS(String ipfsHash) async {
    try {
      // Step 1: Fetch the encrypted data from IPFS
      final encryptedData = await fetchFromIPFS(ipfsHash);
      
      // Step 2: Check if this file is intended for this user
      final encryptedRecipientAddress = encryptedData['encryptedRecipientAddress'];
      final decryptedAddress = EncryptionService.decryptWalletAddress(encryptedRecipientAddress);
      
      // Compare with current user's address
      if (decryptedAddress.toLowerCase() != userAddress.hex.toLowerCase()) {
        throw Exception('This file was not shared with you');
      }
      
      // Step 3: Generate the decryption key from wallet address
      final walletBytes = userAddress.addressBytes;
      final hash = sha256.convert(walletBytes);
      final keyBytes = hash.bytes.sublist(0, 32);
      final key = encrypt.Key(Uint8List.fromList(keyBytes));
      
      // Step 4: Get the IV
      final ivBytes = base64.decode(encryptedData['iv']);
      final iv = encrypt.IV(Uint8List.fromList(ivBytes));
      
      // Step 5: Set up the decrypter
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      
      // Step 6: Decrypt the file
      final encryptedContent = encrypt.Encrypted.fromBase64(encryptedData['encryptedFile']);
      final decryptedBytes = encrypter.decryptBytes(encryptedContent, iv: iv);
      
      return Uint8List.fromList(decryptedBytes);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  /// Process and decrypt a list of shared files
  Future<List<Map<String, dynamic>>> processSharedFiles(List<SharedFile> sharedFiles) async {
    List<Map<String, dynamic>> processedFiles = [];
    
    for (var file in sharedFiles) {
      try {
        final decryptedBytes = await decryptFileFromIPFS(file.ipfsHash);
        
        // You can determine the file type from the content or metadata
        // For simplicity, we're just returning the bytes and some metadata
        processedFiles.add({
          'sender': file.sender,
          'sequence': file.sequence,
          'ipfsHash': file.ipfsHash,
          'decryptedContent': decryptedBytes,
          'success': true
        });
      } catch (e) {
        // Include failed decryption attempts with error message
        processedFiles.add({
          'sender': file.sender,
          'sequence': file.sequence,
          'ipfsHash': file.ipfsHash,
          'error': e.toString(),
          'success': false
        });
      }
    }
    
    return processedFiles;
  }
  
  /// Helper function to save decrypted content to a file
  Future<String> saveDecryptedFile(Uint8List decryptedBytes, String fileName) async {
    try {
      final file = File(fileName);
      await file.writeAsBytes(decryptedBytes);
      return file.path;
    } catch (e) {
      throw Exception('Failed to save decrypted file: $e');
    }
  }
}