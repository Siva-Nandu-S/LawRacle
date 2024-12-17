import 'package:article_21/pages/IPFS_TEST.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:article_21/providers/wallet_provider.dart';
import 'package:web3dart/web3dart.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String walletAddress = '';
  String pvKey = '';
  String query = '';

  @override
  void initState() {
    super.initState();
    loadWalletData();
  }

  Future<void> loadWalletData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? privateKey = prefs.getString('privateKey');
    if (privateKey != null) {
      final walletProvider = WalletProvider();
      await walletProvider.loadPrivateKey();
      EthereumAddress address = await walletProvider.getPublicKey(privateKey);
      setState(() {
        walletAddress = address.hex;
        pvKey = privateKey;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Column(
              children: <Widget>[
                const Text(
                  'Wallet Address: ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  walletAddress,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 50),
                ElevatedButton(onPressed: 
                  () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PinataUploadPage()));
                  }, 
                  child: const Text('IPFS File Upload')
                ),
              ],
            ),
            const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }
}
