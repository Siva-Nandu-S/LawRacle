import 'package:article_21/article_21.dart';
import 'package:flutter/material.dart';
import 'package:article_21/providers/wallet_provider.dart';
import 'package:provider/provider.dart';

import '../home.dart';
import 'create_or_import.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);

    if (walletProvider.privateKey == null) {
      // If private key doesn't exist, load CreateOrImportPage
      return const CreateOrImportPage();
    } else {
      // If private key exists, load WalletPage
      return Article21();
    }
  }
}
