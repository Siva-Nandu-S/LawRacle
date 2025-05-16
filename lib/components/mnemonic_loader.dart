import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<File> get _localFile async {
  final path = await _localPath;
  return File('$path/user_data.json');
}

Future<File> writeUserData(Map<String, String> data) async {
  final file = await _localFile;
  return file.writeAsString(jsonEncode(data));
}

Future<Map<String, String>> readUserData() async {
  try {
    final file = await _localFile;
    String contents = await file.readAsString();
    return Map<String, String>.from(jsonDecode(contents));
  } catch (e) {
    return {};
  }
}
