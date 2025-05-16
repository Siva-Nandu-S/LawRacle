import 'package:article_21/chatting/socket_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/wallet_provider.dart';
import 'package:article_21/utils/routes.dart';
import 'package:article_21/pages/Account/login_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the private key
  WalletProvider walletProvider = WalletProvider();
  await walletProvider.loadPrivateKey();

  await dotenv.load(fileName: ".env");

  runApp(
    ChangeNotifierProvider<WalletProvider>.value(
      value: walletProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SocketProvider()),
        // Add other providers here
      ],
      child: MaterialApp(
      initialRoute: MyRoutes.loginRoute,
      routes: {
        MyRoutes.loginRoute: (context) => const LoginPage(),
      },
      debugShowCheckedModeBanner: false,
    )
    );
  }
}
