import 'package:flutter/material.dart';
import 'package:saarthi2025/pages/student/screen/test_page.dart';

class InstructionPage extends StatefulWidget {
  final String registerNumber;
  
  const InstructionPage({Key? key, required this.registerNumber}) : super(key: key);

  @override
  _InstructionPageState createState() => _InstructionPageState();
}

class _InstructionPageState extends State<InstructionPage> {
  bool _hasReadInstructions = false;
  
  // Primary color
  static const Color primaryColor = Color(0xFF34419A);

  void _startExamination() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TestPage(registerNumber: widget.registerNumber),
      ),
    );
  }

  void _goBackToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isDesktop = screenSize.width > 800;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white,
              Colors.white,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48.0 : 24.0,
              ),
              child: Column(
                children: [
                  SizedBox(height: 20),
                  
                  // College Logo
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Image.asset(
                      'assets/images/smvec_logo.png',
                      width: screenSize.width * 0.8,
                      height: screenSize.height * 0.15,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(); // Empty container if logo fails to load
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Examination Header
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
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
                  
                  const SizedBox(height: 30),
                  
                  // Student Info Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_circle, color: primaryColor, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Register Number: ${widget.registerNumber}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Instructions Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: primaryColor, size: 28),
                              SizedBox(width: 12),
                              Text(
                                'Examination Instructions',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          _buildInstructionItem(
                            Icons.timer,
                            'Time Duration',
                            'You have 60 minutes (1 hour) to complete the examination.',
                          ),
                          
                          _buildInstructionItem(
                            Icons.quiz,
                            'Question Format',
                            'The test contains multiple choice, true/false, and text-based questions.',
                          ),
                          
                          _buildInstructionItem(
                            Icons.edit,
                            'Navigation',
                            'Use "Next" and "Previous" buttons to navigate between questions. You can change your answers before final submission.',
                          ),
                          
                          _buildInstructionItem(
                            Icons.warning,
                            'Tab Switching Policy',
                            'Do NOT switch tabs or minimize the browser. After 2 warnings, your test will be auto-submitted for malpractice.',
                          ),
                          
                          _buildInstructionItem(
                            Icons.task_alt,
                            'Submission',
                            'Click "Submit Test" when you finish. Once submitted, answers cannot be changed.',
                          ),
                          
                          _buildInstructionItem(
                            Icons.access_time,
                            'Auto-Submit',
                            'The test will automatically submit when time expires.',
                          ),
                          
                          _buildInstructionItem(
                            Icons.phone_disabled,
                            'Guidelines',
                            'Keep your device charged and ensure stable internet connection. No external help is allowed.',
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Important Note
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.priority_high, color: Colors.red, size: 24),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Important:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Only one submission is allowed per student. Make sure you are ready before starting the examination.',
                                        style: TextStyle(
                                          color: Colors.red.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Acknowledgment Checkbox
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _hasReadInstructions,
                          onChanged: (value) {
                            setState(() {
                              _hasReadInstructions = value ?? false;
                            });
                          },
                          activeColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'I have read and understood all the instructions mentioned above.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 54,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.arrow_back, size: 20),
                            label: Text(
                              'Back to Login',
                              style: TextStyle(fontSize: 16),
                            ),
                            onPressed: _goBackToLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(width: 16),
                      
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 54,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.play_arrow, size: 20),
                            label: Text(
                              'Start Examination',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _hasReadInstructions ? _startExamination : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hasReadInstructions ? primaryColor : Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: _hasReadInstructions ? 4 : 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Footer
                  Text(
                    "© 2025 SMVEC. All rights reserved.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isDesktop ? 14 : 12,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}