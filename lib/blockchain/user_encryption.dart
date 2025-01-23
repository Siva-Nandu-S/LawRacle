import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'package:web3dart/crypto.dart';
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
  print('length of public key: ${uncompressedPublicKeyHex.length}');

  // Validate and remove the 0x04 prefix if present
  if (uncompressedPublicKeyHex.startsWith('04')) {
    uncompressedPublicKeyHex =
        uncompressedPublicKeyHex.substring(2); // Remove '04'
  }

  // Ensure the length is exactly 128 characters (64 bytes)
  if (uncompressedPublicKeyHex.length != 128) {
    throw FormatException(
        'Invalid public key length: ${uncompressedPublicKeyHex.length}');
  }

  // Convert the hex string to bytes
  Uint8List publicKeyBytes =
      Uint8List.fromList(_hexToBytes(uncompressedPublicKeyHex));

  // ASN.1 DER encoding header for uncompressed SECP256k1 public key
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

  print('PEM Public Key: $pemKey');

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

// Function to encrypt the file with AES and encrypt the AES key with the receiver's public key (ECC)
Future<Map<String, dynamic>> encryptFileWithAccessControl(
    File file, String lawyerPublicKeyHex) async {
  print("\n\n");
  print(lawyerPublicKeyHex);

  // 1. Read the file contents
  Uint8List fileBytes = await file.readAsBytes();

  // 2. Generate a random AES key and IV
  final aesKey = Key.fromSecureRandom(32); // 256-bit AES key
  final iv = IV.fromSecureRandom(16); // 16-byte IV

  final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc)); // CBC Mode

  // 3. Encrypt the file with AES
  final encryptedFile = encrypter.encryptBytes(fileBytes, iv: iv);

  // 4. Load the lawyer's public key (secp256k1) in hex
  final publicKeyBytes = _hexToBytes(lawyerPublicKeyHex);
  print(publicKeyBytes);
  final ecDomainParameters = ECCurve_secp256k1();
  print(ecDomainParameters);
  final pubKey = ecDomainParameters.curve
      .decodePoint(publicKeyBytes); // Decoding the secp256k1 public key
  print(pubKey);

// Convert ECPoint to ECPublicKey
  final ecParams = ECDomainParameters('secp256k1');
  final ecpubKey = ECPublicKey(pubKey!, ecParams);
  print(ecpubKey);

// Encrypt the AES key with the ECC public key
  final encryptedAESKey = _encryptAESKeyWithECC(aesKey.bytes, ecpubKey);

  // 7. Return encrypted data along with CID and IV for decryption later
  return {
    'encryptedFile': encryptedFile.base64, // Return as Base64 string
    'encryptedAESKey': encryptedAESKey, // Base64 or raw encrypted AES key
    'iv': iv, // Store IV for decryption
  };
}

// Encrypt the AES key using the secp256k1 public key (ECC)
String _encryptAESKeyWithECC(Uint8List aesKey, ECPublicKey publicKey) {
  // Get curve parameters for secp256k1
  final domainParams = ECDomainParameters('secp256k1');

  // Generate an ephemeral private key for ECDH
  final secureRandom = FortunaRandom();
  secureRandom
      .seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => i))));
  final privateKey =
      ECPrivateKey(BigInt.from(secureRandom.nextUint16()), domainParams);

  // Compute shared secret using ECDH
  final sharedSecret = (publicKey.Q! * privateKey.d!)!.getEncoded(false);

  // Derive key material using shared secret
  final derivedKey = sharedSecret.sublist(
      0, 32); // Use the first 32 bytes for AES key encryption

  // XOR the AES key with derived key (simple symmetric encryption for demonstration purposes)
  final encryptedAESKey =
      List<int>.generate(aesKey.length, (i) => aesKey[i] ^ derivedKey[i]);

  return base64.encode(encryptedAESKey); // Return Base64-encoded AES key
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
    String ipfsHash, String encryptedAESKey, String lawyerPublicKeyHex) async {
  try {
    // Load private key from SharedPreferences
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // String privateKey = prefs.getString('privateKey') ?? '';
    // if (privateKey.isEmpty) {
    //   throw Exception("Private key not found in SharedPreferences.");
    // }

    // Load private key from .env file
    await dotenv.load();
    print("Loaded .env file");

    // Private key for the sender (for demonstration purposes)
    String privateKey = dotenv.env['MY_PERSONAL_PRIVAT_KEY']!;
    print("Private Key: $privateKey");

    // Infura endpoint (Sepolia testnet)
    const String rpcUrl =
        'https://sepolia.infura.io/v3/fbf0b92dd7e948f392a2e226abba3d1e';

    // Deployed smart contract address
    final EthereumAddress contractAddress = EthereumAddress.fromHex(
        '0xb46a1c09dd18c3283a786c6fbffc10f30bc74fc8'); // Smart contract address

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
    print("Credentials: $credentials");

    // Parse the contract
    final contract = DeployedContract(
        ContractAbi.fromJson(abi, 'AccessControlIPFS'), contractAddress);

    // Get the uploadFile function
    final function = contract.function('uploadFile');

    // Convert lawyer's public key to Ethereum address
    String recipientAddress = deriveEthereumAddress(lawyerPublicKeyHex);
    print("Recipient Ethereum Address: $recipientAddress");

    // Estimate gas price
    final gasPrice = await client.getGasPrice();
    print('Estimated Gas Price: ${gasPrice.getInWei} wei');

    // Send the transaction
    final transactionHash = await client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: function,
        parameters: [
          ipfsHash,
          encryptedAESKey,
          EthereumAddress.fromHex(recipientAddress),
        ],
        maxGas: 1000000, // Max gas limit
      ),
      chainId: 11155111, // Sepolia testnet chain ID
    );

    print('Transaction hash: $transactionHash');

    await client.dispose();
  } catch (e) {
    print('Blockchain upload error: $e');
  }
}

// Function to derive Ethereum address from public key
String deriveEthereumAddress(String publicKeyHex) {
  Uint8List publicKeyBytes = Uint8List.fromList(hexDecode(publicKeyHex));
  Uint8List keccakHash = keccak256(publicKeyBytes.sublist(1)); // Remove the 0x04 prefix
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

