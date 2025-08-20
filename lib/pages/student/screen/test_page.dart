// lib/pages/test_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math'; // Used for shuffling question options

import 'package:saarthi2025/pages/login_page.dart';

class TestPage extends StatefulWidget {
  final String registerNumber;
  const TestPage({super.key, required this.registerNumber});

  @override
  _TestPageState createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentQuestionIndex = 0;
  Map<int, dynamic> _userAnswers = {};
  final Map<int, TextEditingController> _textControllers = {};
  bool _testSubmitted = false;
  int _score = 0;

  // Timer variables
  Timer? _timer;
  int _timeLeft = 3600; // 1 hour in seconds
  bool _timerExpired = false;

  // Tab switching variables
  int _tabSwitchCount = 0;
  bool _isMalpractice = false;

  // Primary color
  static const Color primaryColor = Color(0xFF34419A);

  String _setName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchQuestions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Fetches the question set assigned to the specific student and randomizes question order.
Future<void> fetchQuestions() async {
  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    // 1. Check if the user has already submitted a test.
    bool hasSubmitted = await _checkIfUserAlreadySubmitted();
    if (hasSubmitted) {
      if (mounted) _showAlreadySubmittedDialog();
      return;
    }

    // 2. Fetch the student's document to find their assigned question set number.
    DocumentSnapshot studentDoc = await _firestore
        .collection('smvec')
        .doc('student')
        .collection('student')
        .doc(widget.registerNumber)
        .get();

    if (!studentDoc.exists) {
      setState(() {
        _errorMessage =
            "Your student profile (${widget.registerNumber}) could not be found. Please contact support.";
        _isLoading = false;
      });
      return;
    }

    final studentData = studentDoc.data() as Map<String, dynamic>;
    final setNumber = studentData['set'];

    if (setNumber == null) {
      setState(() {
        _errorMessage =
            "No question set has been assigned to you. Please contact the administrator.";
        _isLoading = false;
      });
      return;
    }

    // 3. Use the set number directly as string (e.g., "1", "2", "3")
    final String assignedSetId = setNumber.toString();
    _setName = "Set $setNumber";

    print("Fetching questions from set: $assignedSetId"); // Debug log

    // 4. Fetch questions from the assigned set's 'questions' subcollection.
    QuerySnapshot questionsSnapshot = await _firestore
        .collection('smvec/question_sets/sets')
        .doc(assignedSetId)
        .collection('questions')
        .orderBy('question_number') 
        .get();

    print("Found ${questionsSnapshot.docs.length} questions"); // Debug log

    // Check if questions were found
    if (questionsSnapshot.docs.isEmpty) {
      setState(() {
        _errorMessage =
            "The assigned question set (Set $setNumber) is empty or could not be found. Please contact the administrator.";
        _isLoading = false;
      });
      return;
    }

    // 5. Populate the questions list.
    final loadedQuestions = questionsSnapshot.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          print("Question data: $data"); // Debug log
          return data;
        })
        .toList();

    // 6. **NEW**: Create a deterministic but unique seed for each student
    // This ensures the same student always gets the same randomized order,
    // but different students get different orders
    final int seed = widget.registerNumber.hashCode;
    final Random studentSpecificRandom = Random(seed);
    
    // 7. **NEW**: Randomize the question order using the student-specific seed
    loadedQuestions.shuffle(studentSpecificRandom);
    
    // 8. Shuffle the options for each multiple-choice question to prevent copying.
    // Use a different random instance for option shuffling to ensure variety
    final Random optionRandom = Random();
    for (var question in loadedQuestions) {
      if (question.containsKey('option') && question['option'] is List) {
        (question['option'] as List).shuffle(optionRandom);
      }
    }

    print("Questions randomized for student: ${widget.registerNumber}"); // Debug log
    print("First question after randomization: ${loadedQuestions.isNotEmpty ? loadedQuestions[0]['qs'] : 'None'}"); // Debug log

    setState(() {
      _questions = loadedQuestions;
      _isLoading = false;
    });

    if (_questions.isNotEmpty) {
      _startTimer();
    }

  } catch (e) {
    print("Error fetching questions: $e"); // Debug log
    setState(() {
      _errorMessage = 'An error occurred while loading the test: $e';
      _isLoading = false;
    });
  }
}

  // --- No other changes are needed below this line ---

  Future<bool> _checkIfUserAlreadySubmitted() async {
    try {
      QuerySnapshot existingSubmissions = await _firestore
          .collection('smvec')
          .doc('test_submissions')
          .collection('submissions')
          .where('register_number', isEqualTo: widget.registerNumber)
          .limit(1)
          .get();
      return existingSubmissions.docs.isNotEmpty;
    } catch (e) {
      print('Error checking existing submissions: $e');
      return false;
    }
  }

  void _showAlreadySubmittedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.orange, size: 30),
            SizedBox(width: 10),
            Text('Already Submitted',
                style: TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'You have already submitted a test. Multiple submissions are not allowed.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (Route<dynamic> route) => false);
            },
            child:
                const Text('Back to Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timerExpired = true;
          _autoSubmitTest();
          timer.cancel();
        }
      });
    });
  }

  void _autoSubmitTest() {
    if (!_testSubmitted) {
      final detailedScore = _calculateDetailedScore();
      setState(() {
        _score = detailedScore['total_score'];
        _testSubmitted = true;
      });
      _submitAnswersToBackend(_userAnswers, detailedScore);
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _handleTabSwitch();
    }
  }

  void _handleTabSwitch() {
    if (_testSubmitted) return;
    _tabSwitchCount++;
    if (_tabSwitchCount >= 3) {
      setState(() {
        _isMalpractice = true;
      });
      _submitForMalpractice();
    } else {
      _showTabSwitchWarning();
    }
  }

  void _showTabSwitchWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 30),
            SizedBox(width: 10),
            Text('Warning!',
                style:
                    TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tab switching detected!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Warning $_tabSwitchCount/2\n\nOne more tab switch will result in automatic test submission and marking as malpractice.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _submitForMalpractice() {
    final detailedScore = _calculateDetailedScore();
    setState(() {
      _score = detailedScore['total_score'];
      _testSubmitted = true;
    });
    _submitAnswersToBackend(_userAnswers, detailedScore, isMalpractice: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('Test Submitted',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Your test has been automatically submitted due to malpractice (excessive tab switching).\n\nRedirecting to login page...',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _navigateToLogin();
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    if (_timeLeft > 1800) return Colors.green;
    if (_timeLeft > 600) return Colors.orange;
    return Colors.red;
  }

  void _handleNextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _showSubmitConfirmationDialog();
    }
  }

  void _handlePreviousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _handleAnswer(dynamic answer) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = answer;
    });
  }

  Map<String, dynamic> _calculateDetailedScore() {
    Map<String, dynamic> questionScores = {};
    int totalScore = 0;
    for (int i = 0; i < _questions.length; i++) {
      String questionKey = 'Q_${i + 1}';
      int questionScore = 0;
      if (_userAnswers.containsKey(i)) {
        final userAnswer = _userAnswers[i];
        final correctAnswer = _questions[i]['correct_ans'];
        if (correctAnswer != null) {
          String questionType = _questions[i]['type'] ?? 'multiple_choice';
          bool isCorrect = false;
          if (questionType == 'multiple_choice') {
            isCorrect = userAnswer == correctAnswer;
          } else if (questionType == 'text') {
            isCorrect = userAnswer.toString().toLowerCase() ==
                correctAnswer.toString().toLowerCase();
          } else if (questionType == 'boolean') {
            isCorrect = userAnswer == correctAnswer;
          }
          questionScore = isCorrect ? 2 : 0;
        }
      }
      questionScores[questionKey] = questionScore;
      totalScore += questionScore;
    }
    return {
      'question_scores': questionScores,
      'total_score': totalScore,
      'max_possible_score': _questions.length * 2,
    };
  }

  int _calculateScore() {
    int correctAnswers = 0;
    _questions.asMap().forEach((index, question) {
      if (!_userAnswers.containsKey(index)) return;
      final userAnswer = _userAnswers[index];
      final correctAnswer = question['correct_ans'];
      if (correctAnswer == null) return;
      String questionType = question['type'] ?? 'multiple_choice';
      if (questionType == 'multiple_choice') {
        if (userAnswer == correctAnswer) correctAnswers++;
      } else if (questionType == 'text') {
        if (userAnswer.toString().toLowerCase() ==
            correctAnswer.toString().toLowerCase()) {
          correctAnswers++;
        }
      } else if (questionType == 'boolean') {
        if (userAnswer == correctAnswer) correctAnswers++;
      }
    });
    return correctAnswers;
  }

  void _showSubmitConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.quiz, color: primaryColor, size: 30),
            SizedBox(width: 10),
            Text('Submit Test?',
                style: TextStyle(
                    color: primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, color: Colors.orange, size: 50),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to submit your test?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You have answered ${_userAnswers.length} out of ${_questions.length} questions.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Once submitted, you cannot make any changes.',
              style: TextStyle(
                  fontSize: 14, color: Colors.red, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            child:
                Text('Review Answers', style: TextStyle(color: Colors.grey[600])),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Navigator.pop(context);
              _submitTest();
            },
            child: const Text('Submit Test',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _submitTest() {
    final detailedScore = _calculateDetailedScore();
    setState(() {
      _score = detailedScore['total_score'];
      _testSubmitted = true;
    });
    _timer?.cancel();
    _submitAnswersToBackend(_userAnswers, detailedScore);
    _showSubmissionSuccessDialog();
  }

  void _showSubmissionSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(15))),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('Test Submitted Successfully',
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, color: Colors.green, size: 60),
            SizedBox(height: 16),
            Text(
              'Your test has been submitted successfully!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Thank you for participating.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if(mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _navigateToLogin();
      }
    });
  }

  Future<void> _submitAnswersToBackend(
      Map<int, dynamic> answers, dynamic scoreData,
      {bool isMalpractice = false}) async {
    try {
      bool hasSubmitted = await _checkIfUserAlreadySubmitted();
      if (hasSubmitted) {
        print('User has already submitted. Preventing duplicate submission.');
        return;
      }
      Map<String, dynamic> detailedScore;
      if (scoreData is Map<String, dynamic>) {
        detailedScore = scoreData;
      } else {
        detailedScore = _calculateDetailedScore();
      }
      Map<String, dynamic> questionWiseData = {};
      for (int i = 0; i < _questions.length; i++) {
        String questionKey = 'Q_${i + 1}';
        questionWiseData['${questionKey}_question'] = _questions[i]['qs'] ?? '';
        questionWiseData['${questionKey}_correct_answer'] =
            _questions[i]['correct_ans'] ?? '';
        questionWiseData['${questionKey}_user_answer'] =
            answers[i] ?? 'Not Attempted';
        questionWiseData['${questionKey}_score'] =
            detailedScore['question_scores'][questionKey] ?? 0;
        questionWiseData['${questionKey}_type'] =
            _questions[i]['type'] ?? 'multiple_choice';
        if (_questions[i]['option'] != null) {
          questionWiseData['${questionKey}_options'] = _questions[i]['option'];
        }
      }
      await _firestore
          .collection('smvec')
          .doc('test_submissions')
          .collection('submissions')
          .add({
        'register_number': widget.registerNumber,
        'set_name': _setName, // Added the set name to the submission
        'total_score': detailedScore['total_score'],
        'max_possible_score': detailedScore['max_possible_score'],
        'total_questions': _questions.length,
        'questions_attempted': _userAnswers.length,
        'questions_correct': _calculateScore(),
        'submitted_at': FieldValue.serverTimestamp(),
        'is_malpractice': isMalpractice,
        'tab_switch_count': _tabSwitchCount,
        'time_taken_seconds': 3600 - _timeLeft,
        'auto_submitted': _timerExpired || isMalpractice,
        ...questionWiseData,
        'question_scores': detailedScore['question_scores'],
      });
      print('Test submitted successfully for ${widget.registerNumber}');
    } catch (e) {
      print('Error submitting answers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to submit results: $e'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  TextEditingController? _getTextController(int index) {
    if (!_textControllers.containsKey(index)) {
      _textControllers[index] = TextEditingController(
        text: _userAnswers[index]?.toString() ?? '',
      );
    }
    return _textControllers[index];
  }

  Widget _buildQuestionView(Map<String, dynamic> question, int index) {
    final String questionText = question['qs'] ?? 'No question text';
    final List<dynamic> options = question['option'] ?? [];
    String questionType = question['type'] ?? 'multiple_choice';

    if (questionType == 'multiple_choice' || options.isNotEmpty) {
      return _buildMultipleChoiceQuestion(questionText, options, index);
    } else if (questionType == 'text') {
      return _buildTextQuestion(questionText, index);
    } else if (questionType == 'boolean') {
      return _buildBooleanQuestion(questionText, index);
    } else {
      return _buildMultipleChoiceQuestion(questionText, options, index);
    }
  }

  Widget _buildMultipleChoiceQuestion(
      String questionText, List<dynamic> options, int index) {
    final userAnswer = _userAnswers[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          questionText,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        ...options.asMap().entries.map((entry) {
          int optionIndex = entry.key;
          String option = entry.value.toString();
          bool isSelected = userAnswer == option;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected ? primaryColor.withOpacity(0.1) : Colors.white,
            ),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + optionIndex),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              value: option,
              groupValue: userAnswer,
              onChanged: _testSubmitted
                  ? null
                  : (value) {
                      _handleAnswer(value);
                    },
              activeColor: primaryColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTextQuestion(String questionText, int index) {
    final controller = _getTextController(index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          questionText,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Type your answer here...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
            style: const TextStyle(fontSize: 16),
            onChanged: (value) {
              _handleAnswer(value);
            },
            controller: controller,
            enabled: !_testSubmitted,
          ),
        ),
      ],
    );
  }

  Widget _buildBooleanQuestion(String questionText, int index) {
    final userAnswer = _userAnswers[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          questionText,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Container(
                height: 60,
                margin: const EdgeInsets.only(right: 8),
                child: ElevatedButton(
                  onPressed: _testSubmitted ? null : () => _handleAnswer(true),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor:
                        userAnswer == true ? primaryColor : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check, size: 24),
                      SizedBox(width: 8),
                      Text('True',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 60,
                margin: const EdgeInsets.only(left: 8),
                child: ElevatedButton(
                  onPressed: _testSubmitted ? null : () => _handleAnswer(false),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: userAnswer == false
                        ? primaryColor
                        : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close, size: 24),
                      SizedBox(width: 8),
                      Text('False',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopBar() {
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 35, 16, 10),
    decoration: BoxDecoration(
      color: primaryColor,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Student: ${widget.registerNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Image.asset("images/smvec_logo.png", height: 40),
                const Text(
                  'Online Examination - SAARTHI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getTimerColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(_timeLeft),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white24),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_testSubmitted) {
          _showExitWarningDialog();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Column(
          children: [
            _buildTopBar(),
            if (_isMalpractice)
              Container(
                width: double.infinity,
                color: Colors.red.shade100,
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'MALPRACTICE DETECTED - Test Auto-Submitted',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(primaryColor),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Loading Your Test...',
                            style: TextStyle(
                              fontSize: 18,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red, size: 64),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 18),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginPage()), (route) => false),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor),
                                child: const Text('Back to Login', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      : _questions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.quiz,
                                      color: Colors.grey, size: 64),
                                  const SizedBox(height: 16),
                                  const Text('No questions available',
                                      style: TextStyle(fontSize: 18)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor),
                                    child: const Text('Back to Login', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  padding: const EdgeInsets.all(16), 
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: primaryColor,
                                            ),
                                          ),
                                          Text(
                                            'Answered: ${_userAnswers.length}/${_questions.length}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: (_currentQuestionIndex + 1) /
                                            _questions.length,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                primaryColor),
                                        minHeight: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Card(
                                      elevation: 8,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15)),
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            color: Colors.white),
                                        child: SingleChildScrollView(
                                          child: _buildQuestionView(
                                              _questions[_currentQuestionIndex],
                                              _currentQuestionIndex),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 0,
                                        blurRadius: 4,
                                        offset: const Offset(0, -2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      SizedBox(
                                        height: 50,
                                        child: ElevatedButton.icon(
                                          icon: const Icon(
                                              Icons.arrow_back_ios,
                                              size: 20),
                                          label: const Text('Previous',
                                              style: TextStyle(fontSize: 16)),
                                          onPressed: _currentQuestionIndex > 0
                                              ? _handlePreviousQuestion
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.grey.shade600,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(25)),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 24),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 50,
                                        child: ElevatedButton.icon(
                                          icon: Icon(
                                            _currentQuestionIndex <
                                                    _questions.length - 1
                                                ? Icons.arrow_forward_ios
                                                : Icons.check_circle,
                                            size: 20,
                                          ),
                                          label: Text(
                                            _currentQuestionIndex <
                                                    _questions.length - 1
                                                ? 'Next'
                                                : 'Submit Test',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: _testSubmitted
                                              ? null
                                              : _handleNextQuestion,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(25)),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 24),
                                            elevation: 3,
                                          ),
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
    );
  }

  void _showExitWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 30),
            SizedBox(width: 10),
            Text('Exit Test?',
                style:
                    TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit the test? Your progress will be lost and you cannot retake it.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            child:
                Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}