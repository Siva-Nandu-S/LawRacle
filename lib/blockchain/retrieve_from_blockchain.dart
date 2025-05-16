import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class SharedFile {
  final String ipfsHash;
  final EthereumAddress sender;
  final int sequence;

  SharedFile({
    required this.ipfsHash,
    required this.sender,
    required this.sequence,
  });

  factory SharedFile.fromList(List<dynamic> data) {
    return SharedFile(
      ipfsHash: data[0] as String,
      sender: data[1] as EthereumAddress,
      sequence: (data[2] as BigInt).toInt(),
    );
  }
}

class BlockchainService {
  static const String _abi = '''
[
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "sender",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "receiver",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "string",
        "name": "ipfsHash",
        "type": "string"
      },
      {
        "indexed": true,
        "internalType": "uint256",
        "name": "fileId",
        "type": "uint256"
      }
    ],
    "name": "FileShared",
    "type": "event"
  },
  {
    "inputs": [],
    "name": "getFileCount",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "page",
        "type": "uint256"
      }
    ],
    "name": "getFiles",
    "outputs": [
      {
        "components": [
          {
            "internalType": "string",
            "name": "ipfsHash",
            "type": "string"
          },
          {
            "internalType": "address",
            "name": "sender",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "sequence",
            "type": "uint256"
          }
        ],
        "internalType": "struct FileSharing.File[]",
        "name": "files",
        "type": "tuple[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "receiver",
        "type": "address"
      },
      {
        "internalType": "string",
        "name": "ipfsHash",
        "type": "string"
      }
    ],
    "name": "shareFile",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
''';

  final Web3Client _client;
  final EthereumAddress _contractAddress;
  final DeployedContract _contract;
  final EthereumAddress _userAddress;

  BlockchainService({required String rpcUrl, required String contractAddress, required EthereumAddress userAddress})
      : _client = Web3Client(rpcUrl, Client()),
        _contractAddress = EthereumAddress.fromHex(contractAddress),
        _userAddress = userAddress,
        _contract = DeployedContract(
          ContractAbi.fromJson(_abi, 'FileSharing'),
          EthereumAddress.fromHex(contractAddress),
        );

  /// Get the total number of files shared with the user
  Future<int> getFileCount() async {
    try {
      final function = _contract.function('getFileCount');
      final result = await _client.call(
        contract: _contract,
        function: function, 
        params: [],
        sender: _userAddress,
      );

      return (result[0] as BigInt).toInt();
    } catch (e) {
      throw Exception('Failed to get file count: $e');
    }
  }

  /// Get files shared with the user, paginated
  Future<List<SharedFile>> getFiles(int page) async {
    try {
      final function = _contract.function('getFiles');
      final result = await _client.call(
        contract: _contract,
        function: function,
        params: [BigInt.from(page)],
        sender: _userAddress,
      );

      final filesList = result[0] as List<dynamic>;
      return filesList.map((fileData) {
        final data = fileData as List<dynamic>;
        return SharedFile.fromList(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to retrieve files: $e');
    }
  }

  /// Listen for new files shared with the user
  // Stream<SharedFile> listenForNewFiles() {
  //   final event = _contract.event('FileShared');
  //   final receiverFilter = [
  //     [null],
  //     [_userAddress.hex], // Filter for receiver == user address
  //     null,
  //   ];

  //   return _client.events(FilterOptions.events(
  //     contract: _contract,
  //     event: event,
  //     topics: receiverFilter,
  //   )).map((event) {
  //     final decoded = _contract.event('FileShared').decodeResults(event.topics!, event.data!);
  //     final ipfsHash = decoded[2] as String;
  //     final sender = decoded[0] as EthereumAddress;
  //     final fileId = (decoded[3] as BigInt).toInt();
      
  //     return SharedFile(
  //       ipfsHash: ipfsHash,
  //       sender: sender,
  //       sequence: fileId,
  //     );
  //   });
  // }

  /// Close the client connection
  Future<void> dispose() async {
    await _client.dispose();
  }

  /// Helper to create from environment
  static Future<BlockchainService> fromEnv(EthereumAddress userAddress) async {
    await dotenv.load();
    final rpcUrl = dotenv.env['RPC_URL']!;
    final contractAddress = dotenv.env['CONTRACT_ADDRESS']!;
    
    return BlockchainService(
      rpcUrl: rpcUrl,
      contractAddress: contractAddress,
      userAddress: userAddress,
    );
  }
}