import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:web3dart/crypto.dart';
import 'package:crypto/crypto.dart';
import 'package:web3dart/web3dart.dart';

const String PERMANENT_KEY = "265f0d7bcce449c3";
const String PERMANENT_IV = "0bc9a684faa6a842";

class EncryptionService {
  static final _permanentKey = encrypt.Key.fromUtf8(PERMANENT_KEY);
  static final _permanentIv = encrypt.IV.fromUtf8(PERMANENT_IV);
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_permanentKey));

  // Encrypt wallet address
  static String encryptWalletAddress(EthereumAddress address) {
    return _encrypter.encrypt(address.hex, iv: _permanentIv).base64;
  }

  // Decrypt wallet address
  static String decryptWalletAddress(String encryptedAddress) {
    return _encrypter.decrypt64(encryptedAddress, iv: _permanentIv);
  }

  static Future<Map<String, dynamic>> encryptFileWithAccessControl(
      File file, EthereumAddress lawyerWalletAddress) async {
    try {
      // Read file as bytes and convert to base64
      final Uint8List fileBytes = await file.readAsBytes();
      final String fileBase64 = base64.encode(fileBytes);

      // Use permanent key and IV instead of generating random ones
      final encrypter =
          _encrypter; // Using the class-level encrypter with permanent key
      final iv = _permanentIv; // Using the permanent IV

      // Encrypt file content (base64 string)
      final encrypt.Encrypted encryptedContent =
          encrypter.encrypt(fileBase64, iv: iv);

      // Create a temporary file to store the encrypted content
      // final directory = await getTemporaryDirectory();
      final directory = await getApplicationDocumentsDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'encrypted_${timestamp}.txt';
      final File encryptedFile = File('${directory.path}/$fileName');

      // Write the encrypted content to the file
      await encryptedFile.writeAsString(encryptedContent.base64);

      // Encrypt wallet address for access control verification
      final encryptedAddress = encryptWalletAddress(lawyerWalletAddress);

      return {
        'encryptedFile': encryptedFile,
        'encryptedFilePath': encryptedFile.path,
        'encryptedFileContent': encryptedContent.base64,
        'iv': base64.encode(_permanentIv.bytes), // Using permanent IV
        'encryptedRecipientAddress': encryptedAddress,
      };
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  // Decrypt a file that was encrypted with encryptFileWithAccessControl
  static Future<Uint8List> decryptFileWithAccessControl(
      File encryptedFile) async {
    try {
      // Use permanent key and IV
      final encrypter = _encrypter;
      final iv = _permanentIv;

      // Read the encrypted content from the file
      final String encryptedContent = await encryptedFile.readAsString();
      final encrypt.Encrypted encryptedData =
          encrypt.Encrypted.fromBase64(encryptedContent);

      // Decrypt to get the original base64 string
      final String decryptedBase64 = encrypter.decrypt(encryptedData, iv: iv);

      // Convert base64 back to bytes
      final Uint8List fileBytes = base64.decode(decryptedBase64);

      return fileBytes;
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  // Alternative decryption method that takes a base64 string directly
  static Future<Uint8List> decryptBase64WithAccessControl(
      String encryptedBase64) async {
    try {
      // Use permanent key and IV
      final encrypter = _encrypter;
      final iv = _permanentIv;

      // Create encrypted object from base64
      final encrypt.Encrypted encryptedData =
          encrypt.Encrypted.fromBase64(encryptedBase64);

      // Decrypt to get the original base64 string
      final String decryptedBase64 = encrypter.decrypt(encryptedData, iv: iv);

      // Convert base64 back to bytes
      final Uint8List fileBytes = base64.decode(decryptedBase64);

      return fileBytes;
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  // Helper method to save decrypted bytes to a file
  static Future<File> saveDecryptedFile(
      Uint8List decryptedBytes, String outputPath) async {
    try {
      final file = File(outputPath);
      return await file.writeAsBytes(decryptedBytes);
    } catch (e) {
      throw Exception('Failed to save decrypted file: $e');
    }
  }
}

Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<String> decryptFile(
    String encryptedFileBase64, String lawyerWalletAddressHex) async {
  try {
    // Convert wallet address string to EthereumAddress
    final lawyerWalletAddress = EthereumAddress.fromHex(lawyerWalletAddressHex);

    final outputFilePath = await _localPath;

    // Decrypt the file - use decryptBase64WithAccessControl instead since we have a base64 string
    final decryptedBytes =
        await EncryptionService.decryptBase64WithAccessControl(
            encryptedFileBase64);

    // Save the decrypted file
    await EncryptionService.saveDecryptedFile(decryptedBytes, outputFilePath);

    return outputFilePath;
  } catch (e) {
    rethrow;
  }
}

/// Encrypts the given data with the provided public key in PEM format.
Future<String> encryptWithPublicKey(String data, String publicKeyPem) async {
  try {
    // Parse the PEM formatted public key
    final publicKey = _parsePublicKeyFromPem(publicKeyPem);

    // Create an RSA Encrypter
    final encrypter = encrypt.Encrypter(encrypt.RSA(publicKey: publicKey));

    // Encrypt the data
    final encrypted = encrypter.encrypt(data);

    // Return the encrypted data in base64 format
    return encrypted.base64;
  } catch (e) {
    rethrow;
  }
}

/// Helper function to parse a public key from PEM format
RSAPublicKey _parsePublicKeyFromPem(String pem) {
  final parser = encrypt.RSAKeyParser();
  return parser.parse(pem) as RSAPublicKey;
}

/// Uploads the IPFS hash, encrypted AES key, and recipient's public key to the blockchain.

// Function to derive Ethereum address from public key
String deriveEthereumAddress(String publicKeyHex) {
  Uint8List publicKeyBytes = Uint8List.fromList(hexDecode(publicKeyHex));
  Uint8List keccakHash =
      keccak256(publicKeyBytes.sublist(1)); // Remove the 0x04 prefix
  Uint8List addressBytes = keccakHash.sublist(keccakHash.length - 20);
  return '0x${hexEncode(addressBytes)}';
}

Uint8List hexDecode(String hex) {
  hex = hex.startsWith('0x') ? hex.substring(2) : hex;
  return Uint8List.fromList(List.generate(hex.length ~/ 2,
      (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
}

String hexEncode(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}