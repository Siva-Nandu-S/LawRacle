import 'package:article_21/components/mnemonic_loader.dart';
import 'package:article_21/pages/Account/create_or_import.dart';
import 'package:article_21/pages/Account/lawyers_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String name = '';
  String email = '';
  String gender = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadWalletData();
  }

  Future<void> loadWalletData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await readUserData();
      setState(() {
        name = data['name'] ?? 'User';
        email = data['email'] ?? 'No email provided';
        gender = data['gender'] ?? '';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // App Bar with background and profile image
                SliverAppBar(
                  expandedHeight: 200.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: Theme.of(context).primaryColor,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Gradient background
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                Theme.of(context).primaryColor.withOpacity(0.8),
                                Theme.of(context).primaryColor,
                              ],
                            ),
                          ),
                        ),
                        // Pattern overlay
                        Opacity(
                          opacity: 0.1,
                          child: Image.asset(
                            'assets/images/pexels-photo-164005.jpeg', // Add a subtle pattern image
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Profile info overlay
                        Align(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 47,
                                  backgroundImage: AssetImage('assets/images/account.png'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Profile content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Contact Information
                        _buildSectionHeader('Contact Information'),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildInfoRow(Icons.email, 'Email', email),
                                if (gender.isNotEmpty)
                                  _buildInfoRow(Icons.person, 'Gender', gender),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        
                        // Account Actions
                        _buildSectionHeader('Account Settings'),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Column(
                            children: [
                              _buildActionButton(
                                'Edit Profile',
                                Icons.edit,
                                Colors.blue,
                                () {
                                  // Implement profile editing functionality
                                },
                              ),
                              Divider(height: 1),
                              _buildActionButton(
                                "Lawyer's Corner",
                                Icons.gavel,
                                Colors.green,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LawyersPage()
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        
                        // Security Section
                        _buildSectionHeader('Security'),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Column(
                            children: [
                              _buildActionButton(
                                'Change Password',
                                Icons.lock,
                                Colors.amber[700]!,
                                () {
                                  // Implement change password functionality
                                },
                              ),
                              Divider(height: 1),
                              _buildActionButton(
                                'Privacy Settings',
                                Icons.privacy_tip,
                                Colors.purple,
                                () {
                                  // Implement privacy settings functionality
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        
                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.logout),
                            label: Text('Logout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              // Confirm logout
                              final shouldLogout = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Confirm Logout'),
                                  content: Text('Are you sure you want to log out?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text('CANCEL'),
                                    ),
                                    TextButton(
                                      onPressed: () => _logout(context),
                                      child: Text('LOGOUT'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (shouldLogout == true) {
                                SharedPreferences prefs = await SharedPreferences.getInstance();
                                await prefs.remove('isLoggedIn');
                                await prefs.remove('privateKey');
                                await prefs.remove('email');
                                
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CreateOrImportPage()
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        SizedBox(height: 40),
                        
                        // App version
                        Center(
                          child: Text(
                            'App Version 1.0.0',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: color),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

Future<void> _logout(BuildContext context) async {

  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.remove('isLoggedIn');
  await prefs.remove('privateKey');
  await prefs.remove('email');
  
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => const CreateOrImportPage()
    ),
  );
}