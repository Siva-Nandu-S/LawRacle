import 'package:article_21/pages/AI%20BOT/ChatBot.dart';
import 'package:article_21/pages/components/AI_Chat_Bot.dart';
import 'package:article_21/pages/components/shared_documents.dart';
import 'package:flutter/material.dart';
import 'package:article_21/pages/home.dart';
import 'package:article_21/pages/profile.dart';
import 'package:article_21/pages/yellow_pages.dart';

class Article21 extends StatefulWidget {
  @override
  _Article21State createState() => _Article21State();
}

class _Article21State extends State<Article21> {
  int currentPageIndex = 0; // Initialize currentPageIndex
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeData();
  }

  Future<void> _initializeData() async {
    // Perform any asynchronous initialization here
    await Future.delayed(Duration(seconds: 2)); // Simulate a delay
  }

  Future<bool> _onWillPop() async {
    // Show a confirmation dialog when back button is pressed
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Exit'),
            content: Text('Are you sure you want to exit?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Yes'),
              ),
            ],
          ),
        ) ??
        false; // Return false if dialog is closed without action
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // Add the no-going-back logic here
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "LAWRacle",
            style: TextStyle(
              fontSize: 24,
              color: Color.fromRGBO(251, 251, 251, 0.906),
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.indigo,
        ),
        body: FutureBuilder<void>(
          future: _initializationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              return IndexedStack(
                index: currentPageIndex,
                children: [
                  const Home(),
                  const Profile(),
                  const YellowPages(),
                  AIChatBot(),
                  SharedDocuments()
                ],
              );
            }
          },
        ),
        bottomNavigationBar: MyBottomNavigationBar(
          currentPageIndex: currentPageIndex,
          onPageChanged: (index) {
            setState(() {
              currentPageIndex = index;
            });
          },
        ),
      ),
    );
  }
}

class MyBottomNavigationBar extends StatelessWidget {
  final int currentPageIndex;
  final ValueChanged<int> onPageChanged;

  const MyBottomNavigationBar({
    Key? key,
    required this.currentPageIndex,
    required this.onPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      backgroundColor: Colors.white,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      onDestinationSelected: onPageChanged,
      indicatorColor: Color.fromARGB(255, 164, 167, 165),
      selectedIndex: currentPageIndex,
      destinations: const <Widget>[
        NavigationDestination(
          icon: Image(image: AssetImage('assets/images/home.png'), width: 30),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Image(image: AssetImage('assets/images/profile.png'), width: 30),
          label: 'Profile',
        ),
        NavigationDestination(
          icon: Image(image: AssetImage('assets/images/pages.png'), width: 30),
          label: 'Yellow Pages',
        ),
        NavigationDestination(
          icon: Image(image: AssetImage('assets/images/ai.png'), width: 30),
          label: 'A I',
        ),
        NavigationDestination(
          icon: Image(image: AssetImage('assets/images/files.png'), width: 30),
          label: 'Files',
        ),
      ],
    );
  }
}
