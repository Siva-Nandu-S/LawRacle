import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter/foundation.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:hex/hex.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class WalletAddressService {
  String generateMnemonic();
  Future<String> getPrivateKey(String mnemonic);
  Future<EthereumAddress> getPublicKey(String privateKey);
}

class WalletProvider extends ChangeNotifier implements WalletAddressService {
  // Variable to store the private key
  String? privateKey;
  EthereumAddress? _walletAddress;

  // Load the private key from the shared preferences
  // Future<void> loadPrivateKey() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   privateKey = prefs.getString('privateKey');
  // }

  // set the private key in the shared preferences
  Future<void> loadPrivateKey() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/user_data.json');
      String contents = await file.readAsString();
      Map<String, dynamic> userData = jsonDecode(contents);
      
      if (userData.containsKey('mnemonic')) {
        String mnemonic = userData['mnemonic'];
        final seed = bip39.mnemonicToSeed(mnemonic);
        final master = await ED25519_HD_KEY.getMasterKeyFromSeed(seed);
        privateKey = HEX.encode(master.key);
        
        // Generate wallet address from private key
        final private = EthPrivateKey.fromHex(privateKey!);
        _walletAddress = private.address;
        
        notifyListeners();
      }
    } catch (e) {
    }
  }

  Credentials? get credentials {
    if (privateKey == null) return null;
    return EthPrivateKey.fromHex(privateKey!);
  }

  @override
  String generateMnemonic() {
    return bip39.generateMnemonic();
  }

  EthereumAddress? get walletAddress => _walletAddress;

  @override
  Future<String> getPrivateKey(String mnemonic) async {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final master = await ED25519_HD_KEY.getMasterKeyFromSeed(seed);
    privateKey = HEX.encode(master.key);
    
    // Generate and store wallet address
    final private = EthPrivateKey.fromHex(privateKey!);
    _walletAddress = private.address;
    
    notifyListeners();
    return privateKey!;
  }

  Future<EthereumAddress> getPublicKey(String privateKeyHex) async {
    final private = EthPrivateKey.fromHex(privateKeyHex);
    return private.address;
  }
}
