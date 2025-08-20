// lib/pages/admin/screens/qs_screen.dart

import 'dart:convert'; // Required for JSON parsing
import 'dart:html' as html; // Required for web file download
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Helper class to manage the controllers for each set (Unchanged)
class QuestionSetControllers {
  final TextEditingController nameController;
  final TextEditingController jsonController;

  QuestionSetControllers()
      : nameController = TextEditingController(),
        jsonController = TextEditingController();

  void dispose() {
    nameController.dispose();
    jsonController.dispose();
  }
}

class QsScreen extends StatefulWidget {
  final String adminId;

  const QsScreen({Key? key, required this.adminId}) : super(key: key);

  @override
  _QsScreenState createState() => _QsScreenState();
}

class _QsScreenState extends State<QsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QuestionSetControllers> _setControllers = [];
  bool _isLoading = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    // Start with one empty set field
    _addSet();
  }

  void _addSet() {
    setState(() {
      _setControllers.add(QuestionSetControllers());
    });
  }

  void _removeSet(int index) {
    setState(() {
      _setControllers[index].dispose();
      _setControllers.removeAt(index);
    });
  }

  // CSV Download functionality
  Future<void> _downloadResultsCSV() async {
    setState(() => _isDownloading = true);
    
    try {
      // Fetch all students data
      QuerySnapshot studentsSnapshot = await _firestore
          .collection('smvec')
          .doc('student')
          .collection('student')
          .get();

      // Fetch all test submissions
      QuerySnapshot submissionsSnapshot = await _firestore
          .collection('smvec')
          .doc('test_submissions')
          .collection('submissions')
          .get();

      // Create a map for quick lookup of submissions by register number
      Map<String, Map<String, dynamic>> submissionsMap = {};
      for (var doc in submissionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        submissionsMap[data['register_number']] = data;
      }

      // Build CSV content
      List<String> csvRows = [];
      
      // CSV Header
      csvRows.add('SI NO,Name,RegisterNumber,Program,Gmail,Phone,Set Assigned,Test Status,Correct,Wrong,Not Attempted,Total Score,Percentage,Submitted At,Is Malpractice,Tab Switch Count');

      int siNo = 1;
      
      // Process each student
      for (var studentDoc in studentsSnapshot.docs) {
        final studentData = studentDoc.data() as Map<String, dynamic>;
        final registerNumber = studentDoc.id;
        final name = studentData['name'] ?? 'N/A';
        final program = studentData['program'] ?? 'N/A';
        final gmail = studentData['gmail'] ?? 'N/A';
        final phone = studentData['phone'] ?? 'N/A';
        final setAssigned = studentData['set']?.toString() ?? 'Not Assigned';
        
        // Check if student has submission
        final submission = submissionsMap[registerNumber];
        
        String testStatus = 'Not Attempted';
        String correct = '0';
        String wrong = '0';
        String notAttempted = '0';
        String totalScore = '0';
        String percentage = '0.0';
        String submittedAt = 'N/A';
        String isMalpractice = 'No';
        String tabSwitchCount = '0';
        
        if (submission != null) {
          testStatus = 'Submitted';
          
          final questionsCorrect = submission['questions_correct'] ?? 0;
          final totalQuestions = submission['total_questions'] ?? 0;
          final questionsAttempted = submission['questions_attempted'] ?? 0;
          
          correct = questionsCorrect.toString();
          wrong = (questionsAttempted - questionsCorrect).toString();
          notAttempted = (totalQuestions - questionsAttempted).toString();
          totalScore = submission['total_score']?.toString() ?? '0';
          percentage = submission['percentage']?.toString() ?? '0.0';
          
          // Format timestamp
          if (submission['submitted_at'] != null) {
            try {
              final timestamp = submission['submitted_at'] as Timestamp;
              final dateTime = timestamp.toDate();
              submittedAt = '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
            } catch (e) {
              submittedAt = 'Invalid Date';
            }
          }
          
          isMalpractice = (submission['is_malpractice'] == true) ? 'Yes' : 'No';
          tabSwitchCount = submission['tab_switch_count']?.toString() ?? '0';
        }
        
        // Create CSV row (escape commas in fields)
        final csvRow = [
          siNo.toString(),
          _escapeCsvField(name),
          _escapeCsvField(registerNumber),
          _escapeCsvField(program),
          _escapeCsvField(gmail),
          _escapeCsvField(phone),
          _escapeCsvField(setAssigned),
          _escapeCsvField(testStatus),
          correct,
          wrong,
          notAttempted,
          totalScore,
          percentage,
          _escapeCsvField(submittedAt),
          isMalpractice,
          tabSwitchCount
        ].join(',');
        
        csvRows.add(csvRow);
        siNo++;
      }
      
      // Join all rows
      final csvContent = csvRows.join('\n');
      
      // Create and download file
      final bytes = utf8.encode(csvContent);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = 'saarthi_test_results_${DateTime.now().millisecondsSinceEpoch}.csv';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
      
      _showSnackBar("CSV downloaded successfully!");
      
    } catch (e) {
      _showSnackBar("Error downloading CSV: $e", isError: true);
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  // Helper function to escape CSV fields containing commas
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  // MODIFIED UPLOAD LOGIC
  Future<void> _uploadQs() async {
    List<Map<String, dynamic>> parsedSets = [];

    // 1. VALIDATION LOOP: Pre-validate all inputs before touching Firestore
    for (int i = 0; i < _setControllers.length; i++) {
      final controllers = _setControllers[i];
      String setName = controllers.nameController.text.trim();
      String jsonString = controllers.jsonController.text.trim();

      if (setName.isEmpty) {
        _showSnackBar("Please provide a name for Set #${i + 1}", isError: true);
        return;
      }
      if (jsonString.isEmpty) {
        _showSnackBar("Please provide JSON for Set #${i + 1}", isError: true);
        return;
      }

      try {
        final decodedJson = jsonDecode(jsonString);

        if (decodedJson is! List) {
          _showSnackBar("JSON for Set '$setName' must be an array (starts with '[').", isError: true);
          return;
        }

        List<dynamic> questionsList = decodedJson;

        if (questionsList.isEmpty) {
          _showSnackBar("JSON for Set '$setName' cannot be empty.", isError: true);
          return;
        }

        for (var q in questionsList) {
          if (q is! Map<String, dynamic> || !q.containsKey('question_number')) {
            _showSnackBar(
              "Invalid question format in Set '$setName'. Each question must be an object with a 'question_number'.",
              isError: true,
            );
            return;
          }
        }
        parsedSets.add({'setName': setName, 'questions': questionsList});
      } catch (e) {
        _showSnackBar("Invalid JSON syntax in Set '$setName'. Please check your format.", isError: true);
        return;
      }
    }

    // If validation passes, proceed with upload
    setState(() => _isLoading = true);

    try {
      WriteBatch batch = _firestore.batch();

      // 2. UPLOAD LOOP: Iterate over validated data
      for (var setData in parsedSets) {
        String setName = setData['setName'];
        List<dynamic> questions = setData['questions'];

        DocumentReference setDoc = _firestore
            .collection('smvec')
            .doc('question_sets')
            .collection('sets')
            .doc(setName);

        // Create the main set document with metadata
        batch.set(setDoc, {
          'setName': setName,
          'admin_id': widget.adminId,
          'created_at': FieldValue.serverTimestamp(),
        });

        // Add each question as a document in a 'questions' subcollection
        for (var questionData in questions) {
          String questionId = questionData['question_number'].toString();
          DocumentReference questionDoc = setDoc.collection('questions').doc(questionId);
          batch.set(questionDoc, questionData as Map<String, dynamic>);
        }
      }

      await batch.commit();

      _showSnackBar("${parsedSets.length} set(s) uploaded successfully!");

      setState(() {
        for (var controller in _setControllers) {
          controller.dispose();
        }
        _setControllers = [];
        _addSet();
      });
    } catch (e) {
      _showSnackBar("Error during upload: ${e.toString()}", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _activateSet(String setName) async {
    try {
      await _firestore.collection('smvec').doc('active_test').set({
        'active_set_name': setName,
        'activated_at': FieldValue.serverTimestamp(),
        'activated_by': widget.adminId,
      });
      _showSnackBar("'$setName' is now the active test!");
    } catch (e) {
      _showSnackBar("Failed to activate test: $e", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ));
    }
  }

  @override
  void dispose() {
    for (var controller in _setControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage & Activate Tests',style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF34419A),
        actions: [
          // CSV Download Button in AppBar
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _isDownloading ? null : _downloadResultsCSV,
              icon: _isDownloading 
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download, color: Colors.white),
              label: Text(
                _isDownloading ? 'Downloading...' : 'Download CSV',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CSV Download Card at the top
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Download Test Results",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF34419A)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Download a comprehensive CSV report containing all student data with test performance metrics including correct answers, wrong answers, not attempted questions, and total scores.",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isDownloading ? null : _downloadResultsCSV,
                        icon: _isDownloading 
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.file_download, color: Colors.white),
                        label: Text(
                          _isDownloading ? 'Generating CSV...' : 'Download Results CSV',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildUploadCard(),
            const SizedBox(height: 24),
            _buildActivationPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Upload New Question Sets",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF34419A)),
            ),
            const SizedBox(height: 16),
            ..._buildSetInputFields(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text("Add Another Set"),
                  onPressed: _addSet,
                ),
                SizedBox(
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _uploadQs,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.0))
                        : const Text('Upload All Sets'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSetInputFields() {
    return List.generate(_setControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Set #${index + 1}",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                if (_setControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeSet(index),
                  )
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _setControllers[index].nameController,
              decoration: const InputDecoration(
                labelText: 'Set Name (must be unique)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _setControllers[index].jsonController,
              decoration: const InputDecoration(
                labelText: 'Paste Question JSON here',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
              ),
              maxLines: 5,
            ),
            const Divider(height: 24),
          ],
        ),
      );
    });
  }

  Widget _buildActivationPanel() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Activate a Test",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF34419A)),
            ),
            const SizedBox(height: 8),
            StreamBuilder<DocumentSnapshot>(
              stream:
                  _firestore.collection('smvec').doc('active_test').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  return Chip(
                    label: Text(
                        "Active Test: ${data['active_set_name'] ?? 'None'}"),
                    backgroundColor: Colors.green.shade100,
                    avatar: const Icon(Icons.check_circle, color: Colors.green),
                  );
                }
                return const Chip(label: Text("No active test set"));
              },
            ),
            const SizedBox(height: 16),
            const Text("Available Sets:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(
              height: 300, // Constrain height to make it scrollable
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('smvec/question_sets/sets')
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("No question sets uploaded yet."));
                  }
                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['setName']),
                        trailing: ElevatedButton(
                          onPressed: () => _activateSet(data['setName']),
                          child: const Text("Activate"),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}