import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SocketProvider with ChangeNotifier {
  late IO.Socket socket;

  void connect() {

    socket = IO.io('https://improved-bison-measured.ngrok-free.app', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
    });

    socket.onDisconnect((_) {
    });

    notifyListeners();
  }

  void sendMessage(String sender, String receiver, String message) {
    socket.emit('send_message', {
      'sender': sender,
      'receiver': receiver,
      'message': message,
    });
  }

  void onMessageReceived(Function(dynamic) callback) {
    socket.on('receive_message', callback);
  }
}
