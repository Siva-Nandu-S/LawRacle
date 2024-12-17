// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:google_generative_ai/google_generative_ai.dart';

// class ChatBot extends StatefulWidget {
//   const ChatBot({super.key});

//   @override
//   _ChatBotState createState() => _ChatBotState();
// }

// class _ChatBotState extends State<ChatBot> {
//   late Future<void> _initializationFuture;
//   late GenerativeModel model;

//   final textController = TextEditingController();
//   String _response = '';
//   bool _isLoading = false;

//   late String _prompt = '';
//   final String _template =
//       'You are a lawyer and the clients legal partner, but at the end of your response make sure to add the clause that one should always approach a lwyer before getting into any legal processes. Find the relevant laws in detail from both Bharathiya Njyaya Sanhitha and the Indian Penal Code which related to the situation given below along with the punishments that might follow if any and generate a response that contains the laws from BNS, the Indian Constitution, an explanation of how these laws are relevant to the situation, and an example of a case that has a similar situation that happened in the past with what the situation then was and how it correlates to the current situation and what was the final decision then and a response a lawyer would give the client if they approach a lawyer with such a situation and also give the legal moves. The format is \n\n-Bharathiya Njyaya Sanhitha\n\nIndian Penal Code\n\nPunishments\n\nConstitutional Rights Impacted\n\nExplanation\n\nLegal Moves\n\nSimilar Case\n\nWord From Lawyer\n\nSituation: ';

//   @override
//   void initState() {
//     super.initState();
//     _initializationFuture = _initializeModel();
//   }

//   Future<void> _initializeModel() async {
//     await dotenv.load();
//     String apiKey = dotenv.env['GEMINI_API_KEY']!;

//     if (apiKey == null) {
//       stderr.writeln(r'No $GEMINI_API_KEY environment variable');
//       exit(1);
//     }

//     const modelUsed = 'gemini-1.5-flash';
//     // const modelUsed = 'tunedModels/situationswithbns-vqs0adx5mqx1';

//     model = GenerativeModel(
//       model: modelUsed,
//       apiKey: apiKey,
//       safetySettings: [
//         SafetySetting(HarmCategory.sexuallyExplicit , HarmBlockThreshold.none),
//         SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
//         SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
//         SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
//       ],
//       generationConfig: GenerationConfig(
//         temperature: 0,
//         topK: 64,
//         topP: 0.95,
//         maxOutputTokens: 8192,
        
//         responseMimeType: 'text/plain',
//       ),
//     );
//   }

//   Future<void> _generateText() async {
//     setState(() {
//       _isLoading = true;
//       _response = '';
//     });

//     _prompt = _template + textController.text;
//     final content = [Content.text(_prompt)];
//     final response = await model.generateContent(content);

//     setState(() {
//       _response = response.text!;
//       _isLoading = false;
//     });
//   }

//   List<TextSpan> _formatResponse(String response) {
//     // This method formats the response text for better readability.
//     final sections = response.split('\n\n');
//     return sections.map((section) {
//       if (section.startsWith('-')) {
//         return TextSpan(
//           text: '\n${section.substring(1)}\n',
//           style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 18,
//           ),
//         );
//       } else if (section.contains(':')) {
//         return TextSpan(
//           text: '\n$section\n',
//           style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//           ),
//         );
//       } else {
//         return TextSpan(
//           text: '\n$section\n',
//           style: const TextStyle(fontSize: 16),
//         );
//       }
//     }).toList();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<void>(
//       future: _initializationFuture,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         } else if (snapshot.hasError) {
//           return Center(child: Text('Error: ${snapshot.error}'));
//         } else {
//           return Scaffold(
//             body: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 children: [
//                   TextField(
//                     controller: textController,
//                     decoration: InputDecoration(
//                       hintText: 'Enter your situation here...',
//                       hintStyle: TextStyle(color: Colors.grey[600]),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey[100],
//                       contentPadding: const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 12),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   ElevatedButton(
//                     onPressed: _generateText,
//                     style: ElevatedButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 24, vertical: 12),
//                       backgroundColor: Colors.indigo,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                     child: const Text('Generate Response',
//                         style: TextStyle(fontSize: 16, color: Colors.white)),
//                   ),
//                   if (_isLoading)
//                     const SizedBox(height: 24),
//                   if (_isLoading)
//                     const CircularProgressIndicator(
//                       valueColor:
//                           AlwaysStoppedAnimation<Color>(Colors.indigo),
//                       strokeCap: StrokeCap.round,
//                     ),
//                   if (!_isLoading && _response.isNotEmpty) ...[
//                     const SizedBox(height: 24),
//                     Expanded(
//                       child: Container(
//                         padding: const EdgeInsets.all(16.0),
//                         decoration: BoxDecoration(
//                           color: Colors.grey[100],
//                           borderRadius: BorderRadius.circular(12),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.grey.withOpacity(0.3),
//                               spreadRadius: 5,
//                               blurRadius: 10,
//                               offset: const Offset(0, 3),
//                             ),
//                           ],
//                         ),
//                         child: SingleChildScrollView(
//                           child: RichText(
//                             text: TextSpan(
//                               children: _formatResponse(_response),
//                               style: const TextStyle(color: Colors.black87),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//             backgroundColor: Colors.white,
//           );
//         }
//       },
//     );
//   }
// }
