import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf_text;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:translator/translator.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class AIChatBot extends StatefulWidget {
  const AIChatBot({Key? key}) : super(key: key);

  @override
  _AIChatBotState createState() => _AIChatBotState();
}

class _AIChatBotState extends State<AIChatBot> {
  final TextEditingController _prompt = TextEditingController();
  List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isProcessingFile = false;
  static const String _storageKey = 'ai_chat_messages';
  
  // File handling variables
  String? _uploadedFileName;
  String? _uploadedFileContent;
  bool _isUsingFileContext = false;

  // Translation variables
  final translator = GoogleTranslator();
  String _selectedLanguage = 'English';
  String _selectedLanguageCode = 'en';
  bool _isTranslating = false;
  static const String _languageStorageKey = 'selected_language';

  // List of supported languages with their codes
  final List<Map<String, String>> _languages = [
    {'name': 'English', 'code': 'en'},
    {'name': 'Hindi', 'code': 'hi'},
    {'name': 'Tamil', 'code': 'ta'},
    {'name': 'Telugu', 'code': 'te'},
    {'name': 'Malayalam', 'code': 'ml'},
    {'name': 'Kannada', 'code': 'kn'},
    {'name': 'Bengali', 'code': 'bn'},
    {'name': 'Marathi', 'code': 'mr'},
    {'name': 'Gujarati', 'code': 'gu'},
    {'name': 'Punjabi', 'code': 'pa'},
    {'name': 'Urdu', 'code': 'ur'},
    {'name': 'Odia', 'code': 'or'},
    {'name': 'Assamese', 'code': 'as'},
    {'name': 'Spanish', 'code': 'es'},
    {'name': 'French', 'code': 'fr'},
    {'name': 'German', 'code': 'de'},
    {'name': 'Chinese', 'code': 'zh-cn'},
    {'name': 'Japanese', 'code': 'ja'},
    {'name': 'Korean', 'code': 'ko'},
    {'name': 'Russian', 'code': 'ru'},
    {'name': 'Arabic', 'code': 'ar'},
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadSelectedLanguage();
  }

  // Load selected language from shared preferences
  Future<void> _loadSelectedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageData = prefs.getString(_languageStorageKey);
      if (languageData != null) {
        final Map<String, dynamic> data = jsonDecode(languageData);
        setState(() {
          _selectedLanguage = data['name'];
          _selectedLanguageCode = data['code'];
        });
      }
    } catch (e) {
      // Default to English if there's an error
    }
  }

  // Save selected language to shared preferences
  Future<void> _saveSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'name': _selectedLanguage,
      'code': _selectedLanguageCode,
    };
    await prefs.setString(_languageStorageKey, jsonEncode(data));
  }

  // Load messages from shared preferences
  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getString(_storageKey);
      if (messagesJson != null) {
        final List<dynamic> decoded = jsonDecode(messagesJson);
        setState(() {
          _messages = decoded.map((item) => ChatMessage.fromJson(item)).toList();
        });
      }
    } catch (e) {
    }
  }

  // Method to save messages to shared preferences
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = jsonEncode(_messages.map((msg) => msg.toJson()).toList());
    await prefs.setString(_storageKey, messagesJson);
  }

  // Translate text to English
  Future<String> _translateToEnglish(String text) async {
    if (_selectedLanguageCode == 'en') return text;
    
    try {
      var translation = await translator.translate(text, from: _selectedLanguageCode, to: 'en');
      return translation.text;
    } catch (e) {
      print('Translation error: $e');
      return text; // Return original text if translation fails
    }
  }

  // Translate text from English to selected language
  Future<String> _translateFromEnglish(String text) async {
    if (_selectedLanguageCode == 'en') return text;
    
    try {
      var translation = await translator.translate(text, from: 'en', to: _selectedLanguageCode);
      return translation.text;
    } catch (e) {
      print('Translation error: $e');
      return text; // Return original text if translation fails
    }
  }

  // Method to handle sending messages
  void _sendMessage() async {
    if (_prompt.text.trim().isEmpty) return;

    final userMessage = _prompt.text.trim();
    final originalMessage = userMessage; // Store original message in user's language
    
    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        originalText: originalMessage,
      ));
      _isLoading = true;
      _isTranslating = _selectedLanguageCode != 'en';
      _prompt.clear();
    });

    _scrollToBottom();
    await _saveMessages();

    // Translate to English if needed
    String translatedQuery = userMessage;
    if (_selectedLanguageCode != 'en') {
      translatedQuery = await _translateToEnglish(userMessage);
    }

    // Get AI response
    final response = await getResponse(translatedQuery);
    
    // Translate response back to selected language if needed
    String translatedResponse = response;
    if (_selectedLanguageCode != 'en') {
      translatedResponse = await _translateFromEnglish(response);
    }
    
    setState(() {
      _messages.add(ChatMessage(
        text: translatedResponse,
        isUser: false,
        originalText: response, // Store original English response
      ));
      _isLoading = false;
      _isTranslating = false;
    });

    _scrollToBottom();
    await _saveMessages();
  }

  Future<String> getResponse(String message) async {
    try {
      await dotenv.load();
      const apiUrl = 'https://8bdf-35-230-6-201.ngrok-free.app/';
      
      final Map<String, dynamic> requestBody = {
        'query': message,
      };
      
      // Add file context to request if available
      if (_isUsingFileContext && _uploadedFileContent != null) {
        requestBody['context'] = _uploadedFileContent;
      }
      
      final response = await http.post(
        Uri.parse('$apiUrl/query'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(requestBody),
      );
        
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null || data['response'] == null) {
          return 'Error: Received null response from server';
        }
        return data['response'];
      } else {
        return 'Server error (${response.statusCode}): ${response.body}';
      }
    } catch (e) {
      return 'Sorry, an error occurred: $e';
    }
  }
  
  // Helper method to truncate long text
  String _truncateTextIfNeeded(String text) {
    const maxChars = 50000; // 50K characters max
    if (text.length > maxChars) {
      return text.substring(0, maxChars) + 
        '\n\n[Note: Document was truncated due to size limitations. Only the first 50,000 characters are being used for context.]';
    }
    return text;
  }

  // Method to pick and read file with PDF support
  Future<void> _pickAndReadFile() async {
    try {
      setState(() {
        _isProcessingFile = true;
      });
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final fileName = path.basename(file.path);
        final fileSize = await file.length();
        
        // Check file size (10MB limit for PDFs, 5MB for TXT)
        final maxSize = path.extension(fileName).toLowerCase() == '.pdf' ? 10 * 1024 * 1024 : 5 * 1024 * 1024;
        
        if (fileSize > maxSize) { 
          _showErrorSnackBar('File is too large. Maximum size is ${maxSize == 10 * 1024 * 1024 ? "10MB" : "5MB"}.');
          setState(() {
            _isProcessingFile = false;
          });
          return;
        }

        String content = '';
        String fileType = '';
        
        // Extract content based on file extension
        final fileExt = path.extension(fileName).toLowerCase();
        
        if (fileExt == '.txt') {
          fileType = 'Text';
          content = await file.readAsString();
          content = _truncateTextIfNeeded(content);
        } else if (fileExt == '.pdf') {
          fileType = 'PDF';
          // Extract text from PDF
          try {
            final pdfBytes = await file.readAsBytes();
            final pdfDoc = pdf_text.PdfDocument(inputBytes: pdfBytes);
            pdf_text.PdfTextExtractor textExtractor = pdf_text.PdfTextExtractor(pdfDoc);
            content = textExtractor.extractText();
            content = _truncateTextIfNeeded(content);
            
            // If PDF has no extractable text or is too short, show an error
            if (content.trim().isEmpty || content.length < 20) {
              _showErrorSnackBar('Could not extract meaningful text from this PDF. It might be scanned or contain only images.');
              setState(() {
                _isProcessingFile = false;
              });
              return;
            }
          } catch (e) {
            _showErrorSnackBar('Could not parse this PDF file. It may be damaged or encrypted.');
            setState(() {
              _isProcessingFile = false;
            });
            return;
          }
        } else {
          _showErrorSnackBar('Only .txt and .pdf files are supported currently.');
          setState(() {
            _isProcessingFile = false;
          });
          return;
        }

        setState(() {
          _uploadedFileName = fileName;
          _uploadedFileContent = content;
          _isUsingFileContext = true;
          _isProcessingFile = false;
        });
        
        // Add a system message about the uploaded file
        String message = "📄 File uploaded: $_uploadedFileName ($fileType)\n\nI'll use information from this document to answer your questions.";
        
        // Translate the system message if needed
        if (_selectedLanguageCode != 'en') {
          message = await _translateFromEnglish(message);
        }
        
        _messages.add(ChatMessage(
          text: message,
          isUser: false,
          isSystemMessage: true,
          timestamp: DateTime.now(),
        ));
        
        await _saveMessages();
        _scrollToBottom();
        
        // Display file info in snackbar
        int contentLength = content.length;
        String sizeInfo = contentLength > 1000 
            ? '${(contentLength/1000).toStringAsFixed(1)}K characters' 
            : '$contentLength characters';
            
        _showSuccessSnackBar('$fileType file uploaded: $sizeInfo extracted');
      } else {
        setState(() {
          _isProcessingFile = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error reading file: ${e.toString().split('\n')[0]}');
      setState(() {
        _isProcessingFile = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearFileContext() {
    setState(() {
      _uploadedFileName = null;
      _uploadedFileContent = null;
      _isUsingFileContext = false;
    });
    _showSuccessSnackBar('File context cleared.');
  }
  
  void _clearChat() {
    setState(() {
      _messages = [];
    });
    _saveMessages();
    _showSuccessSnackBar('Chat cleared.');
  }

  // Method to scroll to the bottom of the chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showFileInfoDialog() {
    final fileExt = _uploadedFileName != null 
        ? path.extension(_uploadedFileName!).toLowerCase() 
        : '';
    final fileType = fileExt == '.pdf' ? 'PDF Document' : 'Text Document';
    final fileIcon = fileExt == '.pdf' ? Icons.picture_as_pdf : Icons.description;
    final contentLength = _uploadedFileContent?.length ?? 0;
    final contentPreview = _uploadedFileContent != null && _uploadedFileContent!.isNotEmpty
        ? _uploadedFileContent!.substring(0, _uploadedFileContent!.length > 200 ? 200 : _uploadedFileContent!.length)
        : '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('File Context'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Currently using context from:'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(fileIcon, color: Colors.indigo),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _uploadedFileName ?? 'Unknown file',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$fileType • ${(contentLength/1000).toStringAsFixed(1)}K characters',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Content Preview:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              height: 100,
              child: SingleChildScrollView(
                child: Text(
                  contentPreview + (contentLength > 200 ? '...' : ''),
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'The AI will use information from this document to provide more accurate responses.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearFileContext();
            },
            child: Text('REMOVE FILE CONTEXT', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Handle language change
  void _onLanguageChanged(Map<String, String> language) {
    setState(() {
      _selectedLanguage = language['name']!;
      _selectedLanguageCode = language['code']!;
    });
    _saveSelectedLanguage();
    
    // Show a snackbar to inform the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Language changed to ${language['name']}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Toggle between original and translated text
  void _toggleTranslation(int index) async {
    if (_selectedLanguageCode == 'en' || 
        _messages[index].originalText == null || 
        _messages[index].originalText!.isEmpty) {
      return; // No need to toggle if language is English or no original text
    }
    
    setState(() {
      _messages[index].showOriginal = !_messages[index].showOriginal;
    });
  }

  Widget _buildMessageBubble(ChatMessage message, bool showTime, int index) {
    // Special styling for system messages
    if (message.isSystemMessage) {
      return Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8.0),
            padding: EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.indigo, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'System Message',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                Divider(height: 16, color: Colors.indigo.withOpacity(0.3)),
                Text(
                  message.text,
                  style: TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
          if (showTime)
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // Regular message bubble styling
    final bubbleColor = message.isUser 
        ? Colors.indigo
        : Colors.grey[100];
    
    final textColor = message.isUser
        ? Colors.white
        : Colors.black87;

    // Format the date
    String formattedTime = '';
    if (showTime) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(
          message.timestamp.year, message.timestamp.month, message.timestamp.day);
      
      if (messageDate == today) {
        formattedTime = DateFormat('HH:mm').format(message.timestamp);
      } else if (messageDate == today.subtract(Duration(days: 1))) {
        formattedTime = 'Yesterday, ${DateFormat('HH:mm').format(message.timestamp)}';
      } else {
        formattedTime = DateFormat('MMM d, HH:mm').format(message.timestamp);
      }
    }

    // Determine if translation toggle should be shown
    bool canToggleTranslation = _selectedLanguageCode != 'en' && 
                              message.originalText != null && 
                              message.originalText!.isNotEmpty;

    return Column(
      children: [
        Align(
          alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: canToggleTranslation ? () => _toggleTranslation(index) : null,
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
              padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.showOriginal && message.originalText != null 
                        ? message.originalText! 
                        : message.text,
                    style: TextStyle(color: textColor, fontSize: 16),
                  ),
                  if (canToggleTranslation)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate,
                            size: 14,
                            color: message.isUser ? Colors.white70 : Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Text(
                            message.showOriginal ? 'Showing original English' : 'Translated to $_selectedLanguage',
                            style: TextStyle(
                              fontSize: 11,
                              color: message.isUser ? Colors.white70 : Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showTime)
          Align(
            alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: message.isUser ? 0 : 16,
                right: message.isUser ? 16 : 0,
                bottom: 8,
              ),
              child: Text(
                formattedTime,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show time only for the first message or if the previous message was sent on a different day
    List<bool> showTimeList = [];
    for (int i = 0; i < _messages.length; i++) {
      if (i == 0) {
        showTimeList.add(true);
      } else {
        final previousDate = DateTime(
          _messages[i - 1].timestamp.year,
          _messages[i - 1].timestamp.month,
          _messages[i - 1].timestamp.day,
        );
        final currentDate = DateTime(
          _messages[i].timestamp.year,
          _messages[i].timestamp.month,
          _messages[i].timestamp.day,
        );
        
        // Show time if date changed or messages are from different users
        showTimeList.add(
          previousDate != currentDate || 
          _messages[i].isUser != _messages[i - 1].isUser ||
          i == _messages.length - 1  // Always show time for the last message
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 14,
              child: Text('AI', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 10)),
            ),
            SizedBox(width: 8),
            Text('LawRacle AI'),
          ],
        ),
        backgroundColor: Colors.indigo,
        actions: [
          // Language selector
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton2(
                customButton: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.translate, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        _selectedLanguage,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                    ],
                  ),
                ),
                dropdownStyleData: DropdownStyleData(
                  width: 180,
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  elevation: 8,
                  offset: const Offset(0, 8),
                ),
                items: _languages
                    .map((item) => DropdownMenuItem<Map<String, String>>(
                          value: item,
                          child: Row(
                            children: [
                              item['code'] == _selectedLanguageCode
                                  ? Icon(Icons.check, color: Colors.indigo, size: 16)
                                  : SizedBox(width: 16),
                              SizedBox(width: 8),
                              Text(
                                item['name']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: item['code'] == _selectedLanguageCode
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: item['code'] == _selectedLanguageCode
                                      ? Colors.indigo
                                      : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _onLanguageChanged(value);
                  }
                },
              ),
            ),
          ),
          // File upload button with loading indicator
          _isProcessingFile ? 
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ) :
            IconButton(
              icon: Icon(Icons.attach_file),
              onPressed: _pickAndReadFile,
              tooltip: 'Upload document (PDF or TXT)',
            ),
          // Show file context indicator if a file is loaded
          if (_isUsingFileContext)
            IconButton(
              icon: Icon(Icons.description, color: Colors.greenAccent),
              onPressed: () => _showFileInfoDialog(),
              tooltip: 'Using file context',
            ),
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: _messages.isEmpty ? null : _clearChat,
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 56,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        _selectedLanguageCode == 'en' 
                            ? 'Ask me anything about law'
                            : 'Ask me anything about law in $_selectedLanguage',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_isUsingFileContext)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Using context from: $_uploadedFileName',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.indigo,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(_messages[index], showTimeList[index], index);
                  },
                ),
          ),

          // Typing indicator when loading
          if (_isLoading)
            Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    _isTranslating 
                        ? 'Translating and processing...' 
                        : 'AI is typing...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Input box
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _prompt,
                    decoration: InputDecoration(
                      hintText: _selectedLanguageCode == 'en' 
                          ? 'Type your question...' 
                          : 'Type in $_selectedLanguage...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isLoading,
                  ),
                ),
                SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  backgroundColor: Colors.indigo,
                  elevation: 0,
                  mini: true,
                  tooltip: 'Send message',
                  child: Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isSystemMessage;
  final String? originalText; // Store original text (before/after translation)
  bool showOriginal; // Toggle between original and translated text

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.isSystemMessage = false,
    this.originalText,
    this.showOriginal = false,
  }) : this.timestamp = timestamp ?? DateTime.now();

  // Convert to JSON 
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isSystemMessage': isSystemMessage,
      'originalText': originalText,
      'showOriginal': showOriginal,
    };
  }

  // Create from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
      isSystemMessage: json['isSystemMessage'] ?? false,
      originalText: json['originalText'],
      showOriginal: json['showOriginal'] ?? false,
    );
  }
}