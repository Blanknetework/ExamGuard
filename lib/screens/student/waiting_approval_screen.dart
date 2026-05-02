import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:examapp/screens/student/student_test_screen.dart';

class WaitingApprovalScreen extends StatefulWidget {
  final String roomCode;
  final String examMode;

  const WaitingApprovalScreen({super.key, required this.roomCode, required this.examMode});

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  StreamSubscription? _participantSub;
  StreamSubscription? _roomSub;
  bool _isAccepted = false;
  bool _isRoomStarted = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _animController.forward();
    _setupListeners();
  }

  void _setupListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _participantSub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('participants')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data();
        if (data?['status'] == 'accepted') {
          setState(() {
            _isAccepted = true;
          });
          _checkRoomStatus();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your request to join was declined.')),
        );
        Navigator.pop(context);
      }
    });

    _roomSub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data()!;
        if (data['status'] == 'started') {
          setState(() {
            _isRoomStarted = true;
          });
          _checkAndNavigate(data);
        }
      }
    });
  }

  Future<void> _checkRoomStatus() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['status'] == 'started') {
          setState(() {
            _isRoomStarted = true;
          });
          _checkAndNavigate(data);
        }
      }
    } catch (e) {
      debugPrint('Error checking room status: $e');
    }
  }

  void _checkAndNavigate(Map<String, dynamic> roomData) {
    if (_isAccepted && _isRoomStarted) {
      _participantSub?.cancel();
      _roomSub?.cancel();

      final examTitle = roomData['examTitle'] ?? '';
      final examinerId = roomData['examinerId'] ?? '';
      final duration = roomData['durationMinutes'] ?? 60;
      final startedAtTs = roomData['startedAt'] as Timestamp?;
      final startedAt = startedAtTs?.toDate() ?? DateTime.now();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentTestScreen(
            roomCode: widget.roomCode,
            examTitle: examTitle,
            examinerId: examinerId,
            durationMinutes: duration,
            startedAt: startedAt,
            examMode: widget.examMode,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _participantSub?.cancel();
    _roomSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF2F66D0),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 1000));
                _checkRoomStatus();
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CupertinoActivityIndicator(
                            radius: 20,
                            color: Color(0xFF2F66D0),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            _isAccepted
                                ? 'Wait for Examiner to Start Exam'
                                : 'Waiting for Examiner Approval',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '[Room Name: ${widget.roomCode}]',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            _isAccepted
                                ? 'You have been accepted!\nWaiting for the exam to begin...'
                                : 'Please Wait for the Examiner\nTo approve your request',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: const SizedBox(
                              height: 6,
                              child: LinearProgressIndicator(
                                backgroundColor: Color(0xFFE0E0E0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2F66D0),
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
        ],
      ),
    );
  }
}
