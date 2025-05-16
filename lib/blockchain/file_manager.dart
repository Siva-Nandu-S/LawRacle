import 'dart:io';
import 'package:article_21/blockchain/file_decryption.dart';
import 'package:article_21/blockchain/retrieve_from_blockchain.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web3dart/web3dart.dart';

class FileManager {
  final BlockchainService _blockchainService;
  final FileRetrievalService _fileRetrievalService;
  
  FileManager({
    required BlockchainService blockchainService, 
    required FileRetrievalService fileRetrievalService
  }) : _blockchainService = blockchainService,
       _fileRetrievalService = fileRetrievalService;
  
  /// Get and decrypt shared files for the current user
  Future<List<Map<String, dynamic>>> getDecryptedSharedFiles({int page = 0}) async {
    try {
      // Step 1: Retrieve shared file hashes from blockchain
      final sharedFiles = await _blockchainService.getFiles(page);
      
      if (sharedFiles.isEmpty) {
        return [];
      }
      
      // Step 2: Process and decrypt all files
      final decryptedFiles = await _fileRetrievalService.processSharedFiles(sharedFiles);
      
      // Step 3: Save decrypted files if needed
      final savedFiles = await _saveDecryptedFiles(decryptedFiles);
      
      return savedFiles;
    } catch (e) {
      throw Exception('Failed to retrieve and decrypt files: $e');
    }
  }
  
  /// Save decrypted files to local storage
  Future<List<Map<String, dynamic>>> _saveDecryptedFiles(List<Map<String, dynamic>> decryptedFiles) async {
    final dir = await getApplicationDocumentsDirectory();
    final results = <Map<String, dynamic>>[];
    
    for (var file in decryptedFiles) {
      if (file['success']) {
        try {
          final fileName = '${dir.path}/file_${file['sequence']}_${DateTime.now().millisecondsSinceEpoch}.bin';
          
          // Save the file
          final savedPath = await _fileRetrievalService.saveDecryptedFile(
            file['decryptedContent'],
            fileName
          );
          
          results.add({
            ...file,
            'localPath': savedPath,
          });
        } catch (e) {
          results.add({
            ...file,
            'error': 'Failed to save file: $e',
            'success': false,
          });
        }
      } else {
        results.add(file); // Keep error information
      }
    }
    
    return results;
  }
  
  /// Factory method to create FileManager with necessary services
  static Future<FileManager> create({required Credentials credentials}) async {
    final userAddress = await credentials.extractAddress();
    
    final blockchainService = await BlockchainService.fromEnv(userAddress);
    
    final fileRetrievalService = FileRetrievalService(
      userCredentials: credentials,
      userAddress: userAddress,
    );
    
    return FileManager(
      blockchainService: blockchainService,
      fileRetrievalService: fileRetrievalService,
    );
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await _blockchainService.dispose();
  }
}