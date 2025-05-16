import 'dart:convert';
import 'dart:io';

import 'package:article_21/chatting/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Map<String, dynamic>> recentChats = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchRecentChats();
  }

  // Create a custom HTTP client that allows self-signed certificates
  HttpClient _createHttpClient() {
    return HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }

  Future<void> fetchRecentChats() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email') ?? '';
      
      if (email.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not logged in. Please login first.';
        });
        return;
      }

      await dotenv.load();
      String apiUrl = dotenv.env['SERVER_URL']!;

      // Create a client that accepts any certificate
      final client = http.Client();
      
      try {
        final response = await client.get(
          Uri.parse('$apiUrl/recent-chats/$email'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        
        if (response.statusCode == 200) {
          final List<dynamic> jsonResponse = jsonDecode(response.body);
          setState(() {
            recentChats = List<Map<String, dynamic>>.from(jsonResponse);
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to load chats: ${response.statusCode}\n${response.body}';
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Network error: ${e.toString()}';
        });
      } finally {
        client.close();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error connecting to server: ${e.toString()}';
        recentChats = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          'Recent Conversations',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchRecentChats,
            tooltip: 'Refresh',
          ),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.indigo.shade900,
        onRefresh: fetchRecentChats,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "ai_chat_bot_fab",
        onPressed: () {
          // Start a new conversation
          // You can implement this functionality later
          _showDebugInfo();
        },
        backgroundColor: Colors.indigo.shade900,
        child: Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  void _showDebugInfo() {
    // Show an alert dialog with debug information
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('API URL: ${dotenv.env['SERVER_URL']}'),
              SizedBox(height: 8),
              FutureBuilder<SharedPreferences>(
                future: SharedPreferences.getInstance(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text('Loading preferences...');
                  }
                  final prefs = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: ${prefs.getString('email') ?? 'Not set'}'),
                      Text('Name: ${prefs.getString('name') ?? 'Not set'}'),
                      Text('Is Logged In: ${prefs.getBool('isLoggedIn') ?? 'Not set'}'),
                      Text('Wallet Address: ${prefs.getString('wallet_address')?.substring(0, 10) ?? 'Not set'}...'),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade900),
              strokeWidth: 3,
            ),
            SizedBox(height: 24),
            Text(
              'Loading your conversations...',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 70, color: Colors.red[400]),
              SizedBox(height: 16),
              Text(
                'We encountered a problem',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: fetchRecentChats,
                icon: Icon(Icons.refresh),
                label: Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade900,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (recentChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 70,
                color: Colors.indigo.shade900,
              ),
            ),
            SizedBox(height: 32),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Your recent conversations will appear here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: fetchRecentChats,
              icon: Icon(Icons.refresh),
              label: Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade900,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      itemCount: recentChats.length,
      itemBuilder: (context, index) {
        final chat = recentChats[index];
        final lastMessageTime = chat['last_message_time'] != null 
            ? DateTime.parse(chat['last_message_time']) 
            : DateTime.now();
            
        // Format normal time (e.g., "10:30 AM" or "Jun 12" if not today)
        String formattedTime;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final messageDate = DateTime(lastMessageTime.year, lastMessageTime.month, lastMessageTime.day);
        
        if (messageDate == today) {
          // If message is from today, show time
          formattedTime = DateFormat('h:mm a').format(lastMessageTime);
        } else if (messageDate == today.subtract(Duration(days: 1))) {
          // If message is from yesterday
          formattedTime = 'Yesterday';
        } else if (now.difference(lastMessageTime).inDays < 7) {
          // If message is from this week
          formattedTime = DateFormat('EEEE').format(lastMessageTime); // Day name
        } else {
          // Otherwise show date
          formattedTime = DateFormat('MMM d').format(lastMessageTime);
        }
        
        return Card(
          elevation: 0,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    lawyerEmail: chat['chat_with'] ?? '',
                    lawyerWalletAddress: chat['wallet'] ?? '',
                    lawyerName: chat['name'] ?? 'Unknown',
                  ),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildAvatar(chat),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                chat['name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.grey[850],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          chat['last_message'] ?? 'No messages yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(Map<String, dynamic> chat) {
    final name = chat['name'] ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _getAvatarColor(name),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    // Generate a consistent color based on the name
    final colors = [
      Colors.indigo.shade700,
      Colors.blue.shade700,
      Colors.teal.shade700,
      Colors.green.shade700,
      Colors.purple.shade700,
      Colors.deepPurple.shade700,
      Colors.orange.shade800,
      Colors.pink.shade700,
    ];

    final index = name.isNotEmpty 
        ? name.codeUnitAt(0) % colors.length 
        : 0;

    return colors[index];
  }
}