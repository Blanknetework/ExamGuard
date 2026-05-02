import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:examapp/screens/student/student_exam_result_screen.dart';

class StudentTestScreen extends StatefulWidget {
  final String roomCode;
  final String examTitle;
  final String examinerId;
  final int durationMinutes;
  final DateTime startedAt;
  final String examMode;

  const StudentTestScreen({
    super.key,
    required this.roomCode,
    required this.examTitle,
    required this.examinerId,
    required this.durationMinutes,
    required this.startedAt,
    required this.examMode,
  });

  @override
  State<StudentTestScreen> createState() => _StudentTestScreenState();
}

class _StudentTestScreenState extends State<StudentTestScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  List<Map<String, dynamic>> _questions = [];
  final Map<int, String> _selectedAnswers = {};

  late Timer _timer;
  int _secondsRemaining = 0;
  int _totalSeconds = 0;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _totalSeconds = widget.durationMinutes * 60;
    _calculateRemainingTime();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _calculateRemainingTime();
      if (_secondsRemaining <= 0) {
        _timer.cancel();
        _submitExamAutomatically();
      }
    });

    _fetchExamQuestions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _recordWarningAndSubmit();
    }
  }

  Future<void> _recordWarningAndSubmit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomCode)
            .collection('participants')
            .doc(user.uid);
        await docRef.update({
          'warnings': FieldValue.increment(1),
        });

        // Anti-Cheat: Instantly submit the test if the user leaves the app
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('ANTI-CHEAT TRIGGERED: Exam auto-submitted because you left the app!'),
               backgroundColor: Colors.red,
               duration: Duration(seconds: 5),
             ),
           );
           _submitExam();
        }
      } catch (e) {
        // Ignore if document not found or permissions issue
      }
    }
  }

  void _calculateRemainingTime() {
    final now = DateTime.now();
    final elapsed = now.difference(widget.startedAt).inSeconds;
    final remaining = _totalSeconds - elapsed;

    setState(() {
      if (remaining <= 0) {
        _secondsRemaining = 0;
      } else {
        _secondsRemaining = remaining;
      }
    });
  }

  Future<void> _fetchExamQuestions() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('exams')
          .where('examinerId', isEqualTo: widget.examinerId)
          .where('title', isEqualTo: widget.examTitle)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        if (data['questions'] is List) {
          final qList = (data['questions'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          setState(() {
            _questions = qList;
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _submitExamAutomatically() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Time is up! Submitting exam automatically.'),
      ),
    );
    await _submitExam();
  }

  Future<void> _submitExam() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String finalScoreString = '0/0';
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        int correctCount = 0;
        for (int i = 0; i < _questions.length; i++) {
          final q = _questions[i];
          final correct = (q['correct_answer'] ?? '').toString().trim();
          if (_selectedAnswers[i] == correct) {
            correctCount++;
          }
        }

        final score = _questions.isEmpty
            ? 0.0
            : (correctCount / _questions.length) * 100;
        finalScoreString = '$correctCount/${_questions.length}';

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('examHistory')
            .doc(widget.roomCode)
            .set({
              'examTitle': widget.examTitle,
              'score': finalScoreString,
              'submittedAt': FieldValue.serverTimestamp(),
            });

        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomCode)
            .collection('participants')
            .doc(user.uid)
            .update({
              'status': 'completed',
              'score': score,
              'answers': _selectedAnswers.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
              'submittedAt': FieldValue.serverTimestamp(),
            });
      }

      if (!mounted) return;
      Navigator.pop(context); // pop loading dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentExamResultScreen(score: finalScoreString),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting exam: $e')));
    }
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Exam?'),
        content: const Text(
          'Are you sure you want to completely submit your exam? You cannot change answers after this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitExam();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F66D0),
            ),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent(int index) {
    final q = _questions[index];
    final questionText = (q['question'] ?? '').toString();
    final options = (q['options'] is List)
        ? (q['options'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.examMode == 'googleForm')
          Text(
            'Question ${index + 1}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
        if (widget.examMode == 'googleForm') const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            questionText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...options.map((opt) {
          final isSelected = _selectedAnswers[index] == opt;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedAnswers[index] = opt;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2F66D0).withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2F66D0)
                      : Colors.grey.shade300,
                  width: isSelected ? 2 : 1.5,
                ),
                boxShadow: isSelected
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2F66D0)
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                      color: isSelected
                          ? const Color(0xFF2F66D0)
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.circle,
                            size: 10,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 16,
                        color: isSelected
                            ? const Color(0xFF2F66D0)
                            : const Color(0xFF334155),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2F66D0)),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2F66D0),
          title: const Text('Error', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(child: Text('No questions found for this exam.')),
      );
    }

    final double progress = _totalSeconds > 0
        ? (_totalSeconds - _secondsRemaining) / _totalSeconds
        : 1.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot leave the exam until it is submitted!'),
            backgroundColor: Colors.red,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 12,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF2F66D0),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.examTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(_secondsRemaining),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _secondsRemaining <= 120
                        ? Colors.red.shade400
                        : Colors.greenAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Question Progress
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.examMode == 'googleForm'
                      ? 'All Questions'
                      : 'Question ${_currentPage + 1} of ${_questions.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Unanswered: ${_questions.length - _selectedAnswers.length}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          Expanded(
            child: widget.examMode == 'googleForm'
                ? ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _questions.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _questions.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32),
                          child: ElevatedButton(
                            onPressed: _showSubmitDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Submit Exam',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                        child: _buildQuestionContent(index),
                      );
                    },
                  )
                : PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      return RefreshIndicator(
                        onRefresh: _fetchExamQuestions,
                        color: const Color(0xFF2F66D0),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildQuestionContent(index),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Actions
          if (widget.examMode == 'wayground')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFF2F66D0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Previous',
                            style: TextStyle(
                              color: Color(0xFF2F66D0),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 16),
                    if (_currentPage < _questions.length - 1)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F66D0),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showSubmitDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Submit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }
}
