import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/api.dart' as crypto;
import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:basic_utils/basic_utils.dart'; // For key conversion utilities

Future<String> encryptFile(String ipfsHash, String lawyerPublicKeyPem) async {
  try {
    // Retrieve the private key from shared preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userPrivateKeyPem = prefs.getString('privateKey');

    if (userPrivateKeyPem == null) {
      throw Exception('Private key not found in shared preferences');
    }

    // Parse the user's private key
    final rsaPrivateKey = encrypt.RSAKeyParser().parse(userPrivateKeyPem) as rsa.RSAPrivateKey;

    // Derive the public key from the private key
    final rsaPublicKey = rsa.RSAPublicKey(rsaPrivateKey.modulus!, rsaPrivateKey.publicExponent!);

    // Convert the public key to PEM format
    String userPublicKeyPem = CryptoUtils.encodeRSAPublicKeyToPem(rsaPublicKey);
    print('User Public Key in PEM Format:\n$userPublicKeyPem');

    // Encrypt the IPFS hash using the lawyer's public key
    final lawyerPublicKey = encrypt.RSAKeyParser().parse(lawyerPublicKeyPem) as rsa.RSAPublicKey;
    final encrypter = encrypt.Encrypter(encrypt.RSA(publicKey: lawyerPublicKey));
    final encrypted = encrypter.encrypt(ipfsHash);

    // Return the encrypted IPFS hash as a Base64 string
    print('Encrypting file...');
    return encrypted.base64;
  } catch (e) {
    print('Error during encryption: $e');
    rethrow;
  }
}
