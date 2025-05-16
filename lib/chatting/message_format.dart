class ChatMessage {
  final int id;
  final String sender;
  final String receiver;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.message,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      sender: json['sender'] as String,
      receiver: json['receiver'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['created_at'] as String),
    );
  }
}