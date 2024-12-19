import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/api.dart' as crypto;
import 'package:pointycastle/asymmetric/api.dart' as rsa;
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:basic_utils/basic_utils.dart'; // For key conversion utilities
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';
import 'package:web3dart/web3dart.dart';

/// Derives the public key from the provided private key in hexadecimal format.
String derivePublicKeyFromPrivateKey(String privateKeyHex) {
  // Convert the private key hex string to bytes
  final privateKeyBytes = Uint8List.fromList(hex.decode(privateKeyHex));

  // Create an EC private key parameter
  final privateKey = ECPrivateKey(
      BigInt.parse(privateKeyHex, radix: 16), ECDomainParameters('secp256k1'));

  // Derive the public key point
  final publicKey = privateKey.parameters!.G * privateKey.d!;
  final publicKeyBytes = publicKey!
      .getEncoded(false); // Uncompressed public key (with 0x04 prefix)

  return hex.encode(publicKeyBytes);
}

/// Encrypts the provided data using the provided public key.

String convertPublicKeyToPEM(String uncompressedPublicKeyHex) {
  // Convert the hex string to bytes
  Uint8List publicKeyBytes =
      Uint8List.fromList(_hexToBytes(uncompressedPublicKeyHex));

  // ASN.1 DER encoding header for an uncompressed SECP256k1 public key
  List<int> asn1Header = [
    0x30, 0x56, // SEQUENCE
    0x30, 0x10, // SEQUENCE
    0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02,
    0x01, // OID: 1.2.840.10045.2.1 (EC Public Key)
    0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01,
    0x07, // OID: 1.2.840.10045.3.1.7 (secp256k1 curve)
    0x03, 0x42, 0x00 // BIT STRING (66 bytes)
  ];

  // Combine header and public key bytes
  Uint8List derKey = Uint8List.fromList([...asn1Header, ...publicKeyBytes]);

  // Base64 encode the DER-encoded key
  String base64Key = base64.encode(derKey);

  // Wrap with PEM delimiters
  String pemKey = '-----BEGIN PUBLIC KEY-----\n';
  pemKey += _chunkString(
      base64Key, 64); // Format with line breaks every 64 characters
  pemKey += '\n-----END PUBLIC KEY-----';

  return pemKey;
}

// Helper function to convert a hex string to a list of bytes
List<int> _hexToBytes(String hex) {
  List<int> bytes = [];
  for (int i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

// Helper function to split a string into chunks of specified size
String _chunkString(String str, int chunkSize) {
  RegExp exp = RegExp('.{1,$chunkSize}');
  return exp.allMatches(str).map((m) => m.group(0)).join('\n');
}

// Function to encrypt the file using AES and encrypt the AES key with RSA
Future<Map<String, dynamic>> encryptFileWithAccessControl(
    File file, String lawyerPublicKeyPem) async {
  // 1. Read the file contents
  Uint8List fileBytes = await file.readAsBytes();

  // 2. Generate a random AES key
  final aesKey = Key.fromSecureRandom(32); // 256-bit AES key
  final encrypter = Encrypter(AES(aesKey));

  // 3. Encrypt the file with AES
  final encryptedFile = encrypter.encryptBytes(fileBytes);

  // 4. Load the lawyer's public key (PEM)
  final parser = RSAKeyParser();
  final rsaPublicKey = parser.parse(lawyerPublicKeyPem) as RSAPublicKey;

  // 5. Encrypt the AES key with the lawyer's public key
  final rsaEncrypter = Encrypter(RSA(publicKey: rsaPublicKey));
  final encryptedAESKey = rsaEncrypter.encryptBytes(aesKey.bytes);

  return {
    'encryptedFile': encryptedFile.bytes,
    'encryptedAESKey': encryptedAESKey.base64,
  };
}

/// Encrypts the given data with the provided public key in PEM format.
Future<String> encryptWithPublicKey(String data, String publicKeyPem) async {
  try {
    // Parse the PEM formatted public key
    final publicKey = _parsePublicKeyFromPem(publicKeyPem);

    // Create an RSA Encrypter
    final encrypter = Encrypter(RSA(publicKey: publicKey));

    // Encrypt the data
    final encrypted = encrypter.encrypt(data);

    // Return the encrypted data in base64 format
    return encrypted.base64;
  } catch (e) {
    print('Encryption error: $e');
    rethrow;
  }
}

/// Helper function to parse a public key from PEM format
RSAPublicKey _parsePublicKeyFromPem(String pem) {
  final parser = RSAKeyParser();
  return parser.parse(pem) as RSAPublicKey;
}

/// Uploads the IPFS hash, encrypted AES key, and recipient's public key to the blockchain.

Future<void> uploadToBlockchain(
    String ipfsHash, String encryptedAESKey, String lawyerPublicKey) async {
  try {
    // Load private key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String privateKey = prefs.getString('privateKey') ?? '';

    // Infura endpoint (Sepolia testnet)
    const String rpcUrl = 'https://sepolia.infura.io/v3/fbf0b92dd7e948f392a2e226abba3d1e'; // Replace with your Infura URL

    // Deployed smart contract address
    final EthereumAddress contractAddress =
        EthereumAddress.fromHex('0xb46a1c09dd18c3283a786c6fbffc10f30bc74fc8'); // Replace with your contract address

    // Load ABI of the contract
    const String abi = '''
    [
      {
        "constant": false,
        "inputs": [
          { "name": "_ipfsHash", "type": "string" },
          { "name": "_encryptedAESKey", "type": "string" },
          { "name": "_recipient", "type": "address" }
        ],
        "name": "uploadFile",
        "outputs": [],
        "type": "function"
      }
    ]
    '''; // Ensure this ABI matches your contract's uploadFile function

    // Initialize Web3Client
    final client = Web3Client(rpcUrl, Client());

    // Load credentials
    final credentials = EthPrivateKey.fromHex(privateKey);

    // Parse the contract
    final contract =
        DeployedContract(ContractAbi.fromJson(abi, 'AccessControlIPFS'), contractAddress);

    // Get the uploadFile function
    final function = contract.function('uploadFile');

    // Send the transaction
    final transactionHash = await client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: function,
        parameters: [ipfsHash, encryptedAESKey, EthereumAddress.fromHex(lawyerPublicKey)],
      ),
      chainId: 11155111, // Sepolia testnet chain ID
    );

    print('Transaction hash: $transactionHash');

    await client.dispose();
  } catch (e) {
    print('Blockchain upload error: $e');
  }
}