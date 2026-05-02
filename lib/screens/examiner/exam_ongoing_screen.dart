import 'package:flutter/material.dart';
import 'dart:async';
import 'package:examapp/screens/examiner/room_participants_screen.dart';

class ExamOngoingScreen extends StatefulWidget {
  final String roomCode;
  final String examTitle;
  final int durationMinutes;
  final DateTime startedAt;

  const ExamOngoingScreen({
    super.key,
    required this.roomCode,
    required this.examTitle,
    required this.durationMinutes,
    required this.startedAt,
  });

  @override
  State<ExamOngoingScreen> createState() => _ExamOngoingScreenState();
}

class _ExamOngoingScreenState extends State<ExamOngoingScreen> {
  late Timer _timer;
  int _secondsRemaining = 0;
  int _totalSeconds = 0;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.durationMinutes * 60;
    _calculateRemainingTime();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _calculateRemainingTime();
    });
  }

  void _calculateRemainingTime() {
    final now = DateTime.now();
    final elapsed = now.difference(widget.startedAt).inSeconds;
    final remaining = _totalSeconds - elapsed;
    
    setState(() {
      if (remaining <= 0) {
        _secondsRemaining = 0;
        _timer.cancel();
      } else {
        _secondsRemaining = remaining;
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
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

  @override
  Widget build(BuildContext context) {
    final double progress = _totalSeconds > 0 
        ? (_totalSeconds - _secondsRemaining) / _totalSeconds 
        : 1.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Blue Background half
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              color: const Color(0xFF2F66D0),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Minimal header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Exam Ongoing',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // Floating Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Exam is Ongoing',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.examTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Clock Icon Circle
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black87,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.access_time_rounded,
                            size: 40,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        const Text(
                          'Time Remaining',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            key: ValueKey(_secondsRemaining),
                            _formatTime(_secondsRemaining),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _secondsRemaining <= 180 
                                  ? Colors.red.shade500 
                                  : const Color(0xFF2F66D0),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // View Participants Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RoomParticipantsScreen(
                                    roomCode: widget.roomCode,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F66D0),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'View Participants',
                              style: TextStyle(
                                fontSize: 16,
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
                
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
