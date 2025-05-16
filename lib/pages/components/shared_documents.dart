import 'dart:convert';
import 'package:article_21/blockchain/file_decryption.dart';
import 'package:article_21/blockchain/file_manager.dart';
import 'package:article_21/blockchain/open_docuemnt_from_ipfs.dart';
import 'package:article_21/blockchain/retrieve_from_blockchain.dart';
import 'package:article_21/components/mnemonic_loader.dart';
import 'package:article_21/providers/wallet_provider.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/ecc/api.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3dart/web3dart.dart';
import 'package:intl/intl.dart';

class SharedDocuments extends StatefulWidget {
  @override
  _SharedDocumentsState createState() => _SharedDocumentsState();
}

class _SharedDocumentsState extends State<SharedDocuments> {
  late Future<List<Map<String, dynamic>>> _documentsFuture;

  @override
  void initState() {
    super.initState();

    _documentsFuture = loadSharedDocuments();
  }

  Future<List<Map<String, dynamic>>> loadSharedDocuments() async {
    try {
      // Get user credentials

      final userdata = await readUserData();
      final mnemonics = userdata['mnemonic'];

      if (mnemonics == null) {
        throw Exception('Mnemonic not found');
      }

      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      final privateKey = await walletProvider.getPrivateKey(mnemonics);

      // Create credentials from private key

      final credentials = EthPrivateKey.fromHex(privateKey);

      // Create file manager

      final fileManager = await FileManager.create(credentials: credentials);

      try {
        // Get decrypted files

        final decryptedFiles = await fileManager.getDecryptedSharedFiles();
        if (decryptedFiles.isEmpty) {
          return []; // Return empty list if no files found
        }
        // Sort files by sequence or date if available
        decryptedFiles.sort((a, b) {
          final seqA = a['sequence'] as int? ?? 0;
          final seqB = b['sequence'] as int? ?? 0;
          return seqB.compareTo(seqA); // Newest first
        });

        return decryptedFiles;
      } catch (e) {
        print("ERROR in fileManager.getDecryptedSharedFiles(): $e");

        rethrow; // Let the error bubble up
      } finally {
        // Always dispose the fileManager

        await fileManager.dispose();
      }
    } catch (e) {
      print("ERROR in loadSharedDocuments: $e");

      // Show error in UI instead of returning empty list

      return Future.error(e);
    }
  }

  void _refreshDocuments() {
    setState(() {
      _documentsFuture = loadSharedDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Shared Documents',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshDocuments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildDocumentsList(),
    );
  }

  Widget _buildDocumentsList() {
    return RefreshIndicator(
      onRefresh: () async {
        _refreshDocuments();
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _documentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading your documents...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          } else {
            List<Map<String, dynamic>> documents = snapshot.data!;

            if (documents.isEmpty) {
              return _buildEmptyState();
            }

            // Sort documents by sequence or date if available

            documents.sort((a, b) {
              final seqA = a['sequence'] as int? ?? 0;

              final seqB = b['sequence'] as int? ?? 0;

              return seqB.compareTo(seqA); // Newest first
            });

            return ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                return _buildDocumentCard(documents[index]);
              },
            );
          }
        },
      ),
    );
  }

  // Rest of the methods remain the same

  // _buildDocumentCard, _buildActionButton, _buildEmptyState, etc.

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    // Determine document type to show appropriate icon

    IconData documentIcon = Icons.description;

    Color cardColor = Colors.white;

    String fileType = document['fileType'] ?? '';

    if (fileType.contains('pdf')) {
      documentIcon = Icons.picture_as_pdf;

      cardColor = Colors.red.shade50;
    } else if (fileType.contains('image')) {
      documentIcon = Icons.image;

      cardColor = Colors.blue.shade50;
    } else if (fileType.contains('word') || fileType.contains('doc')) {
      documentIcon = Icons.article;

      cardColor = Colors.indigo.shade50;
    } else if (fileType.contains('excel') || fileType.contains('sheet')) {
      documentIcon = Icons.table_chart;

      cardColor = Colors.green.shade50;
    }

    // Format date if available

    String formattedDate = '';

    if (document['uploadedAt'] != null) {
      try {
        final uploadDate = DateTime.parse(document['uploadedAt']);

        formattedDate = DateFormat('MMM d, yyyy').format(uploadDate);
      } catch (e) {
        formattedDate = 'Unknown date';
      }
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDocument(document),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: cardColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(documentIcon,
                        color: Theme.of(context).primaryColor, size: 24),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document['title'] ??
                              'Document ${document['sequence'] ?? ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (document['uploadedBy'] != null) ...[
                          SizedBox(height: 4),
                          Text(
                            'Shared by: ${document['uploadedBy']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Date

                  Text(
                    formattedDate.isNotEmpty ? formattedDate : 'Unknown date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),

                  // Action buttons

                  Row(
                    children: [
                      _buildActionButton(
                        Icons.open_in_new,
                        'View',
                        () => _openDocument(document),
                      ),
                      SizedBox(width: 8),
                      _buildActionButton(
                        Icons.info_outline,
                        'Details',
                        () => _showDocumentDetails(document),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).primaryColor),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            'No shared documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Documents shared with you will appear here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[300],
          ),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Could not load your documents',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
            onPressed: _refreshDocuments,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _openDocument(Map<String, dynamic> document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OpenDocumentFromIpfs(
          ipfsHash: document['ipfsHash'],
        ),
      ),
    );
  }

  void _showDocumentDetails(Map<String, dynamic> document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Document Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Title', document['title'] ?? 'Unknown'),
              _buildDetailRow(
                  'Sequence', '${document['sequence'] ?? 'Unknown'}'),
              _buildDetailRow('Shared By', document['uploadedBy'] ?? 'Unknown'),
              _buildDetailRow('IPFS Hash', document['ipfsHash'] ?? 'Unknown'),
              _buildDetailRow('Type', document['fileType'] ?? 'Unknown'),
              if (document['uploadedAt'] != null)
                _buildDetailRow('Uploaded', document['uploadedAt']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              _openDocument(document);
            },
            child: Text('OPEN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
