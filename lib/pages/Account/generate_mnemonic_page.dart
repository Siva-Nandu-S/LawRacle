import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:article_21/providers/wallet_provider.dart';
import 'package:article_21/pages/Account/verify_mnemonic_page.dart';

class GenerateMnemonicPage extends StatefulWidget {
  const GenerateMnemonicPage({Key? key}) : super(key: key);

  @override
  _GenerateMnemonicPageState createState() => _GenerateMnemonicPageState();
}

class _GenerateMnemonicPageState extends State<GenerateMnemonicPage> {
  late String mnemonic;
  late List<String> mnemonicWords;

  @override
  void initState() {
    super.initState();
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    mnemonic = walletProvider.generateMnemonic();
    mnemonicWords = mnemonic.split(' ');
  }

  void copyToClipboard() {
    Clipboard.setData(ClipboardData(text: mnemonic));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mnemonic Copied to Clipboard')),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerifyMnemonicPage(mnemonic: mnemonic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Mnemonic'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Please store this mnemonic phrase safely:',
              style: TextStyle(fontSize: 18.0),
            ),
            const SizedBox(height: 24.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(
                mnemonicWords.length,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    '${index + 1}. ${mnemonicWords[index]}',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton.icon(
              onPressed: copyToClipboard,
              icon: const Icon(Icons.copy),
              label: const Text('Copy to Clipboard'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                textStyle: const TextStyle(fontSize: 20.0),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
