// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
// import 'package:encrypt/encrypt.dart';
// import 'package:pointycastle/api.dart' as crypto;
// import 'package:pointycastle/asymmetric/api.dart' as ecc;
// import 'package:pointycastle/asymmetric/ec_key_generator.dart';
// import 'package:pointycastle/asymmetric/ec_private_key.dart';
// import 'package:pointycastle/asymmetric/ec_public_key.dart';
// import 'package:pointycastle/random/fortuna_random.dart';
// import 'package:pointycastle/export.dart';
// import 'package:convert/convert.dart';
// import 'dart:io';

// // Function to decrypt the AES key using ECC
// Uint8List decryptAESKeyWithECC(Uint8List encryptedAESKey, ECPrivateKey privateKey) {
//   // Compute shared secret using ECDH
//   final sharedSecret = (privateKey.parameters!.G * privateKey.d!)!.getEncoded(false);

//   // Derive key material using shared secret
//   final derivedKey = sharedSecret.sublist(0, 32); // Use the first 32 bytes for AES key decryption

//   // XOR the encrypted AES key with derived key (simple symmetric decryption for demonstration purposes)
//   final decryptedAESKey = List<int>.generate(encryptedAESKey.length, (i) => encryptedAESKey[i] ^ derivedKey[i]);

//   return Uint8List.fromList(decryptedAESKey);
// }

// // Function to decrypt the file
// Future<void> decryptFileFromIPFS(String ipfsHash, String encryptedAESKeyBase64, String ivBase64, ECPrivateKey privateKey, String outputPath) async {
//   // Retrieve the encrypted file from IPFS
//   final response = await http.get(Uri.parse('https://gateway.pinata.cloud/ipfs/$ipfsHash'));
//   if (response.statusCode != 200) {
//     throw Exception('Failed to retrieve file from IPFS');
//   }
//   Uint8List encryptedFileBytes = response.bodyBytes;

//   // Decode the encrypted AES key and IV from Base64
//   Uint8List encryptedAESKey = base64Decode(encryptedAESKeyBase64);
//   IV iv = IV.fromBase64(ivBase64);

//   // Decrypt the AES key using ECC
//   Uint8List decryptedAESKeyBytes = decryptAESKeyWithECC(encryptedAESKey, privateKey);
//   final aesKey = Key(decryptedAESKeyBytes);

//   // Decrypt the file using AES
//   final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc));
//   final decryptedFileBytes = encrypter.decryptBytes(Encrypted(encryptedFileBytes), iv: iv);

//   // Save the decrypted file
//   await File(outputPath).writeAsBytes(decryptedFileBytes);

//   print('Decrypted file saved at: $outputPath');
// }

// // Example usage
// void main() async {
//   // Example IPFS hash
//   String ipfsHash = 'Qm...';

//   // Example encrypted AES key and IV (Base64 encoded)
//   String encryptedAESKeyBase64 = 'your_encrypted_aes_key_base64';
//   String ivBase64 = 'your_iv_base64';

//   // Example ECC private key (replace with actual private key)
//   final privateKeyHex = 'your_private_key_hex';
//   final privateKey = ECPrivateKey(BigInt.parse(privateKeyHex, radix: 16), ECDomainParameters('secp256k1'));

//   // Output path for the decrypted file
//   String outputPath = './';

//   // Decrypt the file from IPFS
//   await decryptFileFromIPFS(ipfsHash, encryptedAESKeyBase64, ivBase64, privateKey, outputPath);
// }