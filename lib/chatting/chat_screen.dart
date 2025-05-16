import 'dart:async';
import 'dart:convert';
import 'package:article_21/blockchain/upload_to_ipfs.dart';
import 'package:article_21/chatting/message_format.dart';
import 'package:article_21/chatting/socket_provider.dart';
import 'package:article_21/components/mnemonic_loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:web3dart/web3dart.dart';

class ChatScreen extends StatefulWidget {
  final String lawyerEmail;
  final String lawyerWalletAddress;
  final String lawyerName;

  ChatScreen({required this.lawyerEmail, required this.lawyerWalletAddress, required this.lawyerName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> messages = [];
  String email = '';
  String name = '';
  bool _isLoading = true;
  bool _isSending = false;

  Timer? _messagePollingTimer;
  static const int _pollingIntervalSeconds = 2; // Increased to reduce server load

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _startMessagePolling();
  }

  void _startMessagePolling() {
    _messagePollingTimer = Timer.periodic(
      Duration(seconds: _pollingIntervalSeconds),
      (_) => _fetchOldMessages(silent: true),
    );
  }

  @override
  void dispose() {
    _messagePollingTimer?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    await _fetchOldMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socketProvider =
          Provider.of<SocketProvider>(context, listen: false);
      socketProvider.connect();
      socketProvider.onMessageReceived((data) {
        final newMessage = ChatMessage.fromJson(data);
        setState(() {
          // Add the message and sort all messages
          messages.add(newMessage);
          _sortMessagesByTimestamp();
        });
        _scrollToBottom();
      });
    });

    await readUserData().then((value) {
      setState(() {
        name = value['name'] ?? '';
      });
    });
  }

  // Sort messages by timestamp to ensure correct order
  void _sortMessagesByTimestamp() {
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _scrollToBottom() {
    // Ensure the controller is attached to a scrollable before trying to scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _fetchOldMessages({bool silent = false}) async {
    if (!mounted) return;

    try {
      if (!silent) {
        setState(() {
          _isLoading = true;
        });
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        email = prefs.getString('email') ?? '';
      });

      await dotenv.load();
      String apiUrl = dotenv.env['SERVER_URL']!;

      final response = await http.get(
        Uri.parse('$apiUrl/reading-messages/$email/${widget.lawyerEmail}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse != null && jsonResponse['messages'] != null) {
          final List<dynamic> messagesList = jsonResponse['messages'] as List;
          final newMessages = messagesList.map((e) => ChatMessage.fromJson(e)).toList();
          
          // Sort messages by timestamp to ensure correct order
          newMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          
          // Check if messages have changed before updating state
          bool shouldUpdate = newMessages.length != messages.length;
          if (!shouldUpdate && newMessages.isNotEmpty && messages.isNotEmpty) {
            // Check if last messages are different
            shouldUpdate = newMessages.last.id != messages.last.id;
          }
          
          if (shouldUpdate) {
            setState(() {
              messages = newMessages;
              _isLoading = false;
            });
            _scrollToBottom();
          } else if (!silent) {
            setState(() {
              _isLoading = false;
            });
          }
        } else {
          if (!silent) {
            setState(() {
              messages = [];
              _isLoading = false;
            });
          }
        }
      } else {
        if (!silent) {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('Failed to load messages: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (!silent) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Error loading messages: ${e.toString()}');
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final socketProvider = Provider.of<SocketProvider>(context, listen: false);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email') ?? '';

      final timestamp = DateTime.now();
      
      await dotenv.load();
      String apiUrl = dotenv.env['SERVER_URL']!;

      await http.post(
        Uri.parse('$apiUrl/sending-message'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(<String, String>{
          'sender': email,
          'sender_name': prefs.getString('name') ?? '',
          'sender_wallet': prefs.getString('wallet_address') ?? '',
          'receiver': widget.lawyerEmail,
          'receiver_name': widget.lawyerName,
          'receiver_wallet': widget.lawyerWalletAddress,
          'message': message,
          'timestamp': timestamp.toIso8601String(),
        }),
      );

      socketProvider.sendMessage(email, widget.lawyerEmail, message);
      
      // Add the message locally for immediate feedback
      final newMessage = ChatMessage(
        id: timestamp.millisecondsSinceEpoch, // Temporary ID
        sender: email,
        receiver: widget.lawyerEmail,
        message: message,
        timestamp: timestamp,
      );
      
      setState(() {
        messages.add(newMessage);
        _sortMessagesByTimestamp(); // Ensure messages are sorted
        _isSending = false;
      });
      
      _messageController.clear();
      _scrollToBottom();
      
    } catch (e) {
      _showSnackBar('Failed to send message: ${e.toString()}');
      setState(() {
        _isSending = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: message.contains('Failed') || message.contains('Error') 
            ? Colors.red.shade800 
            : Colors.indigo.shade900,
      )
    );
  }

  void _handleSendDocument(String walletAddress, String email) {
    EthereumAddress ethAddress = EthereumAddress.fromHex(walletAddress);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinataUploadPage(lawyerWalletAddress: ethAddress, lawyerEmail: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 1,
        backgroundColor: Colors.indigo.shade900,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.indigo.shade700,
              child: Text(
                widget.lawyerName.isNotEmpty ? widget.lawyerName[0].toUpperCase() : 'L',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lawyerName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Online',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _fetchOldMessages(),
            tooltip: 'Refresh messages',
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // Show options menu
            },
            tooltip: 'More options',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          // Light pattern background for chat
          color: Colors.grey[100],
          image: DecorationImage(
            image: AssetImage('assets/images/pexels-photo-164005.jpeg'),
            repeat: ImageRepeat.repeat,
            opacity: 0.05,
          ),
        ),
        child: Column(
          children: [
            // Message loading indicator
            if (_isLoading)
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.indigo.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade900),
              ),
            
            // Chat messages area
            Expanded(
              child: messages.isEmpty && !_isLoading
                ? _buildEmptyChat()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isCurrentUser = message.sender == email;
                      
                      // Group messages by sender (show timestamp only for last message in group)
                      bool showTimeForMessage = true;
                      if (index < messages.length - 1) {
                        final nextMessage = messages[index + 1];
                        if (nextMessage.sender == message.sender &&
                            nextMessage.timestamp.difference(message.timestamp).inMinutes < 5) {
                          showTimeForMessage = false;
                        }
                      }
                      
                      return _buildMessageBubble(
                        message, 
                        isCurrentUser, 
                        showTimeForMessage
                      );
                    },
                  ),
            ),
            
            // Message input area
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.indigo.shade100,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        color: Colors.indigo.shade900,
                      ),
                      onPressed: () => _handleSendDocument(widget.lawyerWalletAddress, widget.lawyerEmail),
                      tooltip: 'Send document',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: Colors.indigo.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.indigo.shade900,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: Colors.white,
                            ),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
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
              size: 64,
              color: Colors.indigo.shade900,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Send a message to start the conversation',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _fetchOldMessages(),
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

  Widget _buildMessageBubble(ChatMessage message, bool isCurrentUser, bool showTime) {
    final bubbleColor = isCurrentUser 
        ? Colors.indigo.shade900
        : Colors.white;
    
    final textColor = isCurrentUser
        ? Colors.white
        : Colors.black87;

    // Format the date
    String formattedDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
        message.timestamp.year, message.timestamp.month, message.timestamp.day);
    
    if (messageDate == today) {
      formattedDate = DateFormat('h:mm a').format(message.timestamp.toLocal());
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      formattedDate = 'Yesterday, ${DateFormat('h:mm a').format(message.timestamp.toLocal())}';
    } else {
      formattedDate = DateFormat('MMM d, h:mm a').format(message.timestamp.toLocal());
    }

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4.0, top: 4.0),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(
                  isCurrentUser ? 16 : 0,
                ),
                bottomRight: Radius.circular(
                  isCurrentUser ? 0 : 16,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(
                left: 8.0, 
                right: 8.0, 
                bottom: 12.0
              ),
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }
}