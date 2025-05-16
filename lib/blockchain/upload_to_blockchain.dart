import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

Future<String> uploadToBlockchain(BuildContext context, String ipfsHash, EthereumAddress receiverAddress) async {
  try {
    if (ipfsHash.isEmpty) {
      throw Exception('Invalid IPFS hash: Cannot be empty');
    }

    // Load private key from environment variable
    await dotenv.load();

    // Private key for the sender (for demonstration purposes)
    String privateKey = dotenv.env['MY_PERSONAL_PRIVAT_KEY']!;
    if (privateKey.isEmpty) {
      throw Exception('Private key not found in environment variables');
    }

    // Create credentials from private key
    final credentials = EthPrivateKey.fromHex(privateKey);

    const String abi = '''
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

    // Get contract instance - make sure contract name matches the actual deployed contract
    final contract = DeployedContract(
        ContractAbi.fromJson(abi, 'FileSharing'),
        EthereumAddress.fromHex(dotenv.env['CONTRACT_ADDRESS']!));

    // Get function from contract
    final shareFileFunction = contract.function('shareFile');

    // Create transaction with correct parameter order and gas parameters
    final transaction = Transaction.callContract(
        contract: contract,
        function: shareFileFunction,
        parameters: [
          receiverAddress,  // First parameter: receiver address
          ipfsHash          // Second parameter: IPFS hash
        ],
        // Add these gas parameters
        maxGas: 500000,     // Increase gas limit (adjust as needed)
        gasPrice: EtherAmount.inWei(BigInt.from(50000000000)), // 50 Gwei (adjust based on network conditions)
    );

    // Send transaction
    final client = Web3Client(dotenv.env['RPC_URL']!, Client());
    try {
      // Get current gas price from the network
      final currentGasPrice = await client.getGasPrice();
      
      // Use a higher gas price to ensure faster processing
      // Multiply by 1.2 to set it 20% higher than network average
      final recommendedGasPrice = EtherAmount.inWei(
        BigInt.from((currentGasPrice.getInWei * BigInt.from(12) / BigInt.from(10)).toInt())
      );
      
      final txHash = await client.sendTransaction(
          credentials, 
          transaction.copyWith(
            gasPrice: recommendedGasPrice, // Use recommended gas price
          ),
          chainId: 11155111,
      );

      // Display the transaction hash
      print('\n\nTransaction hash: $txHash\n\n');
      
      // Add transaction confirmation with timeout
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction submitted, waiting for confirmation...')),
      );
      
      // Wait for transaction to be mined with timeout
      TransactionReceipt? receipt;
      int attempts = 0;
      while (receipt == null && attempts < 20) {
        attempts++;
        await Future.delayed(Duration(seconds: 3));
        try {
          receipt = await client.getTransactionReceipt(txHash);
          if (receipt != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Transaction confirmed in block: ${receipt.blockNumber}')),
            );
          }
        } catch (e) {
          print('Waiting for confirmation... attempt $attempts');
        }
      }
      
      if (receipt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction submitted but not yet confirmed. Check later with hash: $txHash')),
        );
      }

      return txHash;
    } finally {
      await client.dispose();
    }
  } catch (e) {
    print('Error in uploadToBlockchain: $e');
    throw Exception('Transaction failed: $e');
  }
}