import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saarthi2025/pages/admin/screens/qs_screen.dart';
import 'package:saarthi2025/pages/student/screen/instruction.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    // 1. Validate input fields
    if (_idController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all fields.');
      return;
    }

    // This check ensures we don't call setState on a disposed widget.
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final String userId = _idController.text.trim();
    final String password = _passwordController.text.trim();

    try {
      // 2. Attempt to log in as an Admin first.
      DocumentSnapshot adminDoc =
          await _firestore.collection('smvec').doc('admin').get();

      if (adminDoc.exists) {
        final adminData = adminDoc.data() as Map<String, dynamic>;
        if (adminData['Name'] == userId && adminData['password'] == password) {
          // Admin login successful
          if (!mounted) return; // Check context validity before navigating
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => QsScreen(adminId: userId)),
          );
          // Stop execution here if admin login succeeds
          return;
        }
      }

      // 3. If not a successful admin, attempt to log in as a Student.
      DocumentSnapshot studentDoc = await _firestore
          .collection('smvec')
          .doc('student')
          .collection('student')
          .doc(userId)
          .get();

      if (studentDoc.exists) {
        final studentData = studentDoc.data() as Map<String, dynamic>;
        final storedPassword = studentData['password'];

        if (storedPassword == password) {
          // Student login successful
          if (!mounted) return; // Check context validity before navigating
          
          _showSuccessSnackBar('Welcome ${studentData['name'] ?? userId}!');
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => InstructionPage(registerNumber: userId)),
          );
          // Stop execution here
          return;
        }
      }

      // 4. If neither admin nor student login was successful, show a generic error.
      _showErrorSnackBar('Invalid credentials. Please try again.');
    } catch (e) {
      // Handle potential Firebase/network errors
      _showErrorSnackBar('An error occurred: ${e.toString()}');
    } finally {
      // This will always run, ensuring the loading indicator is turned off.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // HELPER METHOD: To avoid repeating SnackBar code for errors.
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // HELPER METHOD: For success messages.
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF34419A),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isDesktop = screenSize.width > 800; // Check if it's desktop/windows
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white, // More vibrant blue
              Colors.white,
              Colors.white, // Light blue
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: 
// Main Content
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 48.0 : 24.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // College Logo (Small version at top)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                      ),
                      child: Positioned(
              left: screenSize.width * 0.1,
              right: screenSize.width * 0.1,
              child:Image.asset(
                  'images/smvec_logo.png',
                  width: screenSize.width * 0.8,
                  height: screenSize.height * 0.15,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(); // Empty container if logo fails to load
                  },
                ),
              ),
            ),
                    
                    
                    const SizedBox(height: 10),
                    
                    Container(
  padding: EdgeInsets.symmetric(
    horizontal: isDesktop ? 32 : 16,
    vertical: 16,
  ),
  decoration: BoxDecoration(
    color: Color(0xFF34419A),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Colors.white.withOpacity(0.3),
      width: 1,
    ),
  ),
  child: Column(
    children: [
      Text(
        "Online Examination For",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isDesktop ? 18 : 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        "Student Ambassador for Academic Reforms in Transforming Higher Education in India (SAARTHI) - 2025",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isDesktop ? 16 : 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 8),
      Text(
                        "Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                        style: TextStyle(
          fontSize: isDesktop ? 16 : 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
                      ),
    ],
  ),
),
                    const SizedBox(height: 60),
                    
                    // Login Form Card
                    Container(
                      width: isDesktop ? 500 : double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 15,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isDesktop ? 32.0 : 28.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    "Student Login",
                                    style: TextStyle(
                                      fontSize: isDesktop ? 26 : 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF34419A),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Enter your credentials to continue",
                                    style: TextStyle(
                                      fontSize: isDesktop ? 16 : 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // ID Field
                            TextField(
                              controller: _idController,
                              decoration: InputDecoration(
                                labelText: 'Register Number / Admin ID',
                                labelStyle: TextStyle(color: Colors.grey[700]),
                                hintText: 'Enter your ID',
                                filled: true,
                                fillColor: Colors.grey[100],
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.transparent),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFF1976D2), width: 2),
                                ),
                                prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF1976D2)),
                                contentPadding: EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Password Field
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(color: Colors.grey[700]),
                                hintText: 'Enter your password',
                                filled: true,
                                fillColor: Colors.grey[100],
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.transparent),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFF1976D2), width: 2),
                                ),
                                prefixIcon: Icon(Icons.lock_outline_rounded, color: Color(0xFF1976D2)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                contentPadding: EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF34419A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Footer text
                    Padding(
                      padding: EdgeInsets.only(top: isDesktop ? 32.0 : 24.0),
                      child: Text(
                        "© 2025 SMVEC. All rights reserved.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isDesktop ? 14 : 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      );
  }
}