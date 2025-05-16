import 'package:article_21/chatting/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:article_21/blockchain/upload_to_ipfs.dart';
import 'package:web3dart/web3dart.dart';

class YellowPages extends StatefulWidget {
  const YellowPages({Key? key}) : super(key: key);

  @override
  _YellowPagesState createState() => _YellowPagesState();
}

class _YellowPagesState extends State<YellowPages> {
  late Future<List<Map<String, dynamic>>> _lawyersFuture;
  String _searchQuery = '';
  String _selectedSpeciality = 'All';
  List<String> _specialities = ['All'];

  @override
  void initState() {
    super.initState();
    _lawyersFuture = loadYellowPages();
  }

  Future<List<Map<String, dynamic>>> loadYellowPages() async {
    await dotenv.load();
    final apiUrl = dotenv.env['SERVER_URL'];

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/lawyers'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = jsonDecode(response.body);
        
        // Extract unique specialities for filter
        Set<String> specialitySet = {'All'};
        for (var lawyer in jsonResponse) {
          if (lawyer['speciality'] != null && lawyer['speciality'].toString().isNotEmpty) {
            specialitySet.add(lawyer['speciality']);
          }
        }
        _specialities = specialitySet.toList();
        
        return List<Map<String, dynamic>>.from(jsonResponse);
      } else {
        throw Exception('Failed to load yellow pages');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  void _handleChat(String lawyerEmail, String lawyerWalletAddress, String lawyerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          lawyerEmail: lawyerEmail, 
          lawyerWalletAddress: lawyerWalletAddress, 
          lawyerName: lawyerName,
        ),
      ),
    );
  }

  void _handleSendDocument(String walletAddress, String email) {
    EthereumAddress ethAddress = EthereumAddress.fromHex(walletAddress);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinataUploadPage(
          lawyerWalletAddress: ethAddress, 
          lawyerEmail: email
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterLawyers(List<Map<String, dynamic>> lawyers) {
    return lawyers.where((lawyer) {
      // Filter by search query
      final nameMatches = lawyer['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final specialityMatches = lawyer['speciality'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final cityMatches = lawyer['city'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Filter by speciality
      final specialityFilterMatches = _selectedSpeciality == 'All' || 
                                      lawyer['speciality'] == _selectedSpeciality;
      
      return (nameMatches || specialityMatches || cityMatches) && specialityFilterMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lawyer Directory',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _lawyersFuture = loadYellowPages();
                });
              },
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _lawyersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading lawyers directory...', 
                              style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                          SizedBox(height: 16),
                          Text('Error: ${snapshot.error}', 
                              style: TextStyle(color: Colors.grey[700])),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: Icon(Icons.refresh),
                            label: Text('Try Again'),
                            onPressed: () {
                              setState(() {
                                _lawyersFuture = loadYellowPages();
                              });
                            },
                          )
                        ],
                      )
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off, size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No lawyers available.', 
                              style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      )
                    );
                  } else {
                    final filteredLawyers = _filterLawyers(snapshot.data!);
                    
                    if (filteredLawyers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 60, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No lawyers match your search criteria.', 
                                style: TextStyle(fontSize: 16, color: Colors.grey)),
                          ],
                        )
                      );
                    }
                    
                    return ListView.builder(
                      padding: EdgeInsets.all(12),
                      itemCount: filteredLawyers.length,
                      itemBuilder: (context, index) {
                        return _buildLawyerCard(filteredLawyers[index]);
                      },
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Search field
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by name, speciality, or location',
              prefixIcon: Icon(Icons.search),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          SizedBox(height: 12),
          
          // Speciality filter dropdown
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedSpeciality,
                hint: Text('Filter by speciality'),
                icon: Icon(Icons.filter_list),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedSpeciality = newValue;
                    });
                  }
                },
                items: _specialities.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLawyerCard(Map<String, dynamic> lawyer) {
    // Generate random color for avatar based on lawyer's name
    final color = Colors.primaries[lawyer['name'].toString().length % Colors.primaries.length];
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header with avatar
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              color: color.withOpacity(0.1),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: color.withOpacity(0.8),
                  child: Text(
                    lawyer['name'].toString()[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lawyer['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        lawyer['speciality'] ?? 'General Practice',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${lawyer['experience'] ?? 0} years experience',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Body with details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.email, lawyer['email'] ?? 'Not provided'),
                _buildInfoRow(Icons.phone, lawyer['phone'] ?? 'Not provided'),
                _buildInfoRow(Icons.location_on, 
                    '${lawyer['city'] ?? ''}, ${lawyer['district'] ?? ''}, ${lawyer['state'] ?? ''}'),
                _buildInfoRow(Icons.person, 'Gender: ${lawyer['gender'] ?? 'Not specified'}'),
              ],
            ),
          ),
          
          // Actions
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.chat_bubble_outline),
                    label: Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Theme.of(context).primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _handleChat(
                      lawyer['email'], 
                      lawyer['public_key'], 
                      lawyer['name']
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.upload_file),
                    label: Text('Send Document', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _handleSendDocument(
                      lawyer['public_key'], 
                      lawyer['email']
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}