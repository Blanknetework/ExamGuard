import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:examapp/screens/student/waiting_approval_screen.dart';

class JoinExamRoomScreen extends StatefulWidget {
  const JoinExamRoomScreen({super.key});

  @override
  State<JoinExamRoomScreen> createState() => _JoinExamRoomScreenState();
}

class _JoinExamRoomScreenState extends State<JoinExamRoomScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final TextEditingController _codeController = TextEditingController();
  String _examMode = 'googleForm'; // Add exam mode state

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutQuart),
          ),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 20,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF2F66D0),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Join Exam Room',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Balance the back button space
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: Center(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 1000));
                  if (mounted) setState(() {});
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Join Exam Room',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextField(
                            controller: _codeController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                            decoration: InputDecoration(
                              hintText: '[Enter Room Code]',
                              hintStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                                letterSpacing: 0,
                                color: Colors.grey.shade400,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2F66D0),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Mode Selection
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Exam Detail Mode',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _examMode = 'googleForm';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _examMode == 'googleForm' ? const Color(0xFF2F66D0).withValues(alpha: 0.1) : Colors.white,
                                      border: Border.all(
                                        color: _examMode == 'googleForm' ? const Color(0xFF2F66D0) : Colors.grey.shade300,
                                        width: _examMode == 'googleForm' ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Google Form\n(List View)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: _examMode == 'googleForm' ? FontWeight.bold : FontWeight.normal,
                                          color: _examMode == 'googleForm' ? const Color(0xFF2F66D0) : Colors.black87,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _examMode = 'wayground';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _examMode == 'wayground' ? const Color(0xFF2F66D0).withValues(alpha: 0.1) : Colors.white,
                                      border: Border.all(
                                        color: _examMode == 'wayground' ? const Color(0xFF2F66D0) : Colors.grey.shade300,
                                        width: _examMode == 'wayground' ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Wayground\n(Page View)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: _examMode == 'wayground' ? FontWeight.bold : FontWeight.normal,
                                          color: _examMode == 'wayground' ? const Color(0xFF2F66D0) : Colors.black87,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Join Room Button
                          SizedBox(
                            width: 160,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                final code = _codeController.text.trim();
                                if (code.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Please enter a room code.',
                                      ),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final roomDoc = await FirebaseFirestore.instance
                                    .collection('rooms')
                                    .doc(code)
                                    .get();
                                if (!context.mounted) return;

                                if (!roomDoc.exists) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Room not found! Check your code.',
                                      ),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null) {
                                  final userDoc = await FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .get();
                                  final name =
                                      userDoc.data()?['name'] ??
                                      'Unknown Student';
                                  await FirebaseFirestore.instance
                                      .collection('rooms')
                                      .doc(code)
                                      .collection('participants')
                                      .doc(user.uid)
                                      .set({
                                        'name': name,
                                        'uid': user.uid,
                                        'status': 'waiting',
                                        'joinedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                }

                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder:
                                        (
                                          context,
                                          animation,
                                          secondaryAnimation,
                                        ) => WaitingApprovalScreen(
                                          roomCode: code,
                                          examMode: _examMode,
                                        ),
                                    transitionsBuilder:
                                        (
                                          context,
                                          animation,
                                          secondaryAnimation,
                                          child,
                                        ) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: ScaleTransition(
                                              scale:
                                                  Tween<double>(
                                                    begin: 0.95,
                                                    end: 1.0,
                                                  ).animate(
                                                    CurvedAnimation(
                                                      parent: animation,
                                                      curve:
                                                          Curves.easeOutCubic,
                                                    ),
                                                  ),
                                              child: child,
                                            ),
                                          );
                                        },
                                    transitionDuration: const Duration(
                                      milliseconds: 500,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2F66D0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Join Room',
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
                ),
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
