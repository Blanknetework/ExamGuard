import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:examapp/screens/examiner/upload_exam_document_screen.dart';
import 'package:examapp/screens/examiner/import_google_form_screen.dart';
import 'package:examapp/screens/examiner/manual_exam_builder_screen.dart';
import 'package:examapp/screens/examiner/review_questions_screen.dart';
import 'package:examapp/screens/examiner/room_waiting_screen.dart';
import 'package:examapp/screens/examiner/exam_ongoing_screen.dart';
import 'package:examapp/screens/examiner/room_participants_screen.dart';
import 'package:examapp/screens/auth/login_screen.dart';
import 'dart:math';
import 'dart:async';

class ExaminerDashboard extends StatefulWidget {
  const ExaminerDashboard({super.key});

  @override
  State<ExaminerDashboard> createState() => _ExaminerDashboardState();
}

class _ExaminerDashboardState extends State<ExaminerDashboard> {
  String _currentSection = 'manage_exams';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
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
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentSection = 'manage_exams';
                    });
                  },
                  child: Image.asset(
                    'Images/app_icon.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.contain,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Examiner Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text(
                          'Log Out',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: const Text(
                          'Are you sure you want to log out?',
                          style: TextStyle(fontSize: 15),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Log Out',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    }
                  },
                  child: const Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(milliseconds: 1000));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom: 100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Three Action Cards
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionCard('Manage\nExams', Icons.laptop_mac, () {
                          setState(() {
                            _currentSection = 'manage_exams';
                          });
                        }),
                        _buildActionCard('Manage\nRooms', Icons.groups, () {
                          setState(() {
                            _currentSection = 'manage_rooms';
                          });
                        }),
                        _buildActionCard(
                          'Examiner\nProfile',
                          Icons.person_outline,
                          () {
                            setState(() {
                              _currentSection = 'examiner_profile';
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    _buildDynamicContent(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          onPressed: _showCreateExamOptions,
          backgroundColor: const Color(0xFF2F66D0),
          shape: const CircleBorder(),
          elevation: 2,
          child: const Icon(Icons.add, color: Colors.white, size: 40),
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2F66D0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(icon, color: Colors.white, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateExamOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create New Exam',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildCreateOption(
                  icon: Icons.auto_awesome,
                  title: 'Upload Document (AI Parse)',
                  subtitle:
                      'Upload a PDF or TXT to automatically extract questions.',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UploadExamDocumentScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildCreateOption(
                  icon: Icons.link,
                  title: 'Import Google Form',
                  subtitle:
                      'Paste a Google Form link to securely link questions.',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ImportGoogleFormScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildCreateOption(
                  icon: Icons.edit_document,
                  title: 'Manual Entry',
                  subtitle: 'Build your exam questions one by one manually.',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManualExamBuilderScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2F66D0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF2F66D0), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicContent() {
    if (_currentSection == 'manage_exams') {
      final user = FirebaseAuth.instance.currentUser;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Manage Exams',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (user == null)
            const Text(
              'Please sign in to manage exams.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            )
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('exams')
                  .where('examinerId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text(
                    'Failed to load exams: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  );
                }

                final docs =
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                      snapshot.data?.docs ?? const [],
                    )..sort((a, b) {
                      final aTs = a.data()['createdAt'];
                      final bTs = b.data()['createdAt'];
                      final aMillis = aTs is Timestamp
                          ? aTs.millisecondsSinceEpoch
                          : 0;
                      final bMillis = bTs is Timestamp
                          ? bTs.millisecondsSinceEpoch
                          : 0;
                      return bMillis.compareTo(aMillis);
                    });

                if (docs.isEmpty) {
                  return Text(
                    'No exams to manage yet.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final title =
                        (data['title'] ?? '').toString().trim().isNotEmpty
                        ? data['title'].toString().trim()
                        : 'Untitled Exam';
                    final questionCount = (data['questions'] is List)
                        ? (data['questions'] as List).length
                        : 0;


                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (data['status'] == 'completed')
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          'Done',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$questionCount questions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _ExamProgressBar(
                                  title: title,
                                  examinerId: user.uid,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'view') {
                                final questions = (data['questions'] is List)
                                    ? List<Map<String, dynamic>>.from(
                                        (data['questions'] as List).map(
                                          (e) => Map<String, dynamic>.from(
                                            e as Map,
                                          ),
                                        ),
                                      )
                                    : <Map<String, dynamic>>[];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _ExamViewerScreen(
                                      examTitle: title,
                                      questions: questions,
                                    ),
                                  ),
                                );
                              } else if (value == 'edit') {
                                final questions = (data['questions'] is List)
                                    ? List<Map<String, dynamic>>.from(
                                        (data['questions'] as List).map(
                                          (e) => Map<String, dynamic>.from(
                                            e as Map,
                                          ),
                                        ),
                                      )
                                    : <Map<String, dynamic>>[];
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReviewQuestionsScreen(
                                      extractedQuestions: questions,
                                      initialExamTitle: title,
                                      existingExamId: doc.id,
                                    ),
                                  ),
                                );
                              } else if (value == 'delete') {
                                await _deleteExam(doc.id, title);
                              } else if (value == 'done') {
                                await FirebaseFirestore.instance
                                    .collection('exams')
                                    .doc(doc.id)
                                    .update({'status': 'completed'});
                              } else if (value == 'ongoing') {
                                await FirebaseFirestore.instance
                                    .collection('exams')
                                    .doc(doc.id)
                                    .update({'status': 'ongoing'});
                              }
                            },
                            itemBuilder: (context) {
                              final isDone = data['status'] == 'completed';
                              return [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Text('View'),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: isDone ? 'ongoing' : 'done',
                                  child: Text(
                                    isDone ? 'Mark as Ongoing' : 'Mark as Done',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      );
    } else if (_currentSection == 'manage_rooms') {
      final user = FirebaseAuth.instance.currentUser;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Manage Rooms',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (user == null)
            const Text(
              'Please sign in to manage rooms.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            )
          else ...[
            // Ongoing Rooms and Available Exams combined StreamBuilder
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .where('examinerId', isEqualTo: user.uid)
                  .where('status', whereIn: ['waiting', 'started'])
                  .snapshots(),
              builder: (context, roomSnapshot) {
                if (roomSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final activeRooms = roomSnapshot.data?.docs ?? [];
                final activeExamTitles = activeRooms
                    .map((d) => (d.data()['examTitle'] ?? '').toString().trim())
                    .toSet();

                final ongoingRooms = activeRooms
                    .where((d) => d.data()['status'] == 'started')
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Exams for Rooms',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('exams')
                          .where('examinerId', isEqualTo: user.uid)
                          .snapshots(),
                      builder: (context, examSnapshot) {
                        if (examSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (examSnapshot.hasError) {
                          return Text(
                            'Failed to load exams: ${examSnapshot.error}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          );
                        }

                        final allDocs =
                            List<
                                QueryDocumentSnapshot<Map<String, dynamic>>
                              >.from(examSnapshot.data?.docs ?? const [])
                              ..sort((a, b) {
                                final aTs = a.data()['createdAt'];
                                final bTs = b.data()['createdAt'];
                                final aMillis = aTs is Timestamp
                                    ? aTs.millisecondsSinceEpoch
                                    : 0;
                                final bMillis = bTs is Timestamp
                                    ? bTs.millisecondsSinceEpoch
                                    : 0;
                                return bMillis.compareTo(aMillis);
                              });

                        final availableDocs = allDocs.where((doc) {
                          final data = doc.data();
                          final title = (data['title'] ?? '').toString().trim();
                          final status = (data['status'] ?? '').toString();
                          return title.isNotEmpty &&
                              status != 'completed' &&
                              !activeExamTitles.contains(title);
                        }).toList();

                        if (availableDocs.isEmpty) {
                          return Text(
                            'No available exams. Any uploaded exams are already active or none have been uploaded yet.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          );
                        }

                        return Column(
                          children: availableDocs.map((doc) {
                            final data = doc.data();
                            final title = (data['title'] ?? '')
                                .toString()
                                .trim();
                            final questionCount = (data['questions'] is List)
                                ? (data['questions'] as List).length
                                : 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$questionCount questions',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _showRoomCodeDialog(context, title),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2F66D0),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                    child: const Text(
                                      'Create Room',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    if (ongoingRooms.isNotEmpty) ...[
                      const Text(
                        'Active Rooms',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...ongoingRooms.map((doc) {
                        final data = doc.data();
                        final examTitle = data['examTitle'] ?? 'Untitled Exam';
                        final roomCode = doc.id;
                        final durationMinutesRaw =
                            data['durationMinutes'] ?? 60;
                        final durationMinutes = durationMinutesRaw is num
                            ? durationMinutesRaw.toInt()
                            : int.tryParse(durationMinutesRaw.toString()) ?? 60;
                        final startedAtTs = data['startedAt'] as Timestamp?;
                        final startedAt =
                            startedAtTs?.toDate() ?? DateTime.now();

                        final endTime = startedAt.add(
                          Duration(minutes: durationMinutes),
                        );
                        final hasEnded = DateTime.now().isAfter(endTime);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: hasEnded
                                ? Colors.grey.shade100
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: hasEnded
                                  ? Colors.grey.shade400
                                  : Colors.green.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      examTitle,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: hasEnded
                                            ? Colors.grey.shade600
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Room: $roomCode',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: hasEnded
                                            ? Colors.grey.shade600
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _deleteRoom(roomCode, examTitle),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    onPressed: hasEnded
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ExamOngoingScreen(
                                                      roomCode: roomCode,
                                                      examTitle: examTitle,
                                                      durationMinutes:
                                                          durationMinutes,
                                                      startedAt: startedAt,
                                                    ),
                                              ),
                                            );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hasEnded
                                          ? Colors.grey
                                          : Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                    child: Text(
                                      hasEnded ? 'Ended' : 'Monitor',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      );
    } else if (_currentSection == 'examiner_profile') {
      return _buildExaminerProfile();
    }

    // Default: 'dashboard'
    return const SizedBox.shrink();
  }

  Widget _buildExaminerProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Text(
        'Please sign in to view your profile.',
        style: TextStyle(color: Colors.black54, fontSize: 14),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Examiner Profile',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFF2F66D0),
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                user.displayName != null && user.displayName!.isNotEmpty
                    ? user.displayName!
                    : 'Examiner',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email ?? 'No email provided',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProfileStatCard('Total\nExams', Icons.laptop_mac),
                  _buildProfileStatCard('Active\nRooms', Icons.meeting_room),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Rooms & Results',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .where('examinerId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error loading rooms: ${snapshot.error}');
            }

            final docs = List<QueryDocumentSnapshot>.from(
              snapshot.data?.docs ?? const [],
            );
            docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;
              final aMillis = aTime?.millisecondsSinceEpoch ?? 0;
              final bMillis = bTime?.millisecondsSinceEpoch ?? 0;
              return bMillis.compareTo(aMillis); // descending
            });

            if (docs.isEmpty) {
              return const Text('You have not created any rooms yet.');
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final roomData = docs[index].data() as Map<String, dynamic>;
                final roomCode = docs[index].id;
                final examTitle = roomData['examTitle'] ?? 'Unknown Exam';
                final section = (roomData['section'] ?? '').toString();
                final sectionDisplay = section.isNotEmpty
                    ? section
                    : 'No Section';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // View Result Button on the left as requested
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RoomParticipantsScreen(roomCode: roomCode),
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics_outlined, size: 18),
                        label: const Text(
                          'View Result',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F66D0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              examTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      sectionDisplay,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Room: $roomCode',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileStatCard(String title, IconData icon) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(title.contains('Exams') ? 'exams' : 'rooms')
          .where(
            'examinerId',
            isEqualTo: FirebaseAuth.instance.currentUser?.uid,
          )
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2F66D0).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF2F66D0), size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteExam(String docId, String title) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Exam'),
          content: Text(
            'Are you sure you want to permanently delete "$title"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await FirebaseFirestore.instance.collection('exams').doc(docId).delete();

      final roomsQuery = await FirebaseFirestore.instance
          .collection('rooms')
          .where('examTitle', isEqualTo: title)
          .get();
      for (var doc in roomsQuery.docs) {
        await doc.reference.delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Exam deleted.'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete exam: $e'),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _deleteRoom(String roomId, String examTitle) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Room'),
          content: Text(
            'Are you sure you want to end and delete the room for "$examTitle"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await FirebaseFirestore.instance.collection('rooms').doc(roomId).delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Room deleted.'),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        7,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  void _showRoomCodeDialog(BuildContext context, String examTitle) {
    final roomCode = _generateRoomCode();
    final sectionController = TextEditingController();
    final maxStudentsController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F66D0).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.meeting_room_rounded,
                      size: 36,
                      color: Color(0xFF2F66D0),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Room Code Generated',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          roomCode,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            color: Color(0xFF2F66D0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    examTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sectionController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Section *',
                      hintText: 'e.g. SBIT-3Q',
                      prefixIcon: const Icon(
                        Icons.class_rounded,
                        color: Color(0xFF2F66D0),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2F66D0),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxStudentsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Max Students *',
                      hintText: 'e.g. 40',
                      prefixIcon: const Icon(
                        Icons.groups_rounded,
                        color: Color(0xFF2F66D0),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2F66D0),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Only students with the matching section can join.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final section = sectionController.text
                                .trim()
                                .toUpperCase();
                            final maxText = maxStudentsController.text.trim();

                            if (section.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a section.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            if (maxText.isEmpty ||
                                int.tryParse(maxText) == null ||
                                int.parse(maxText) <= 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter a valid number of max students.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance
                                  .collection('rooms')
                                  .doc(roomCode)
                                  .set({
                                    'examTitle': examTitle,
                                    'examinerId': user.uid,
                                    'status': 'waiting',
                                    'section': section,
                                    'maxStudents': int.parse(maxText),
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                            }

                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RoomWaitingScreen(
                                  roomCode: roomCode,
                                  examTitle: examTitle,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F66D0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExamViewerScreen extends StatelessWidget {
  final String examTitle;
  final List<Map<String, dynamic>> questions;

  const _ExamViewerScreen({required this.examTitle, required this.questions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F66D0),
        foregroundColor: Colors.white,
        title: const Text(
          'Viewing Exam',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD1D5DB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                examTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: questions.isEmpty
                    ? const Center(
                        child: Text(
                          'No questions found for this exam.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.separated(
                        itemCount: questions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final q = questions[index];
                          final questionText = (q['question'] ?? '')
                              .toString()
                              .trim();
                          final options = (q['options'] is List)
                              ? (q['options'] as List)
                                    .map((e) => e.toString())
                                    .toList()
                              : <String>[];
                          final correct = (q['correct_answer'] ?? '')
                              .toString()
                              .trim();

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Question ${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  questionText.isEmpty
                                      ? 'No question text.'
                                      : questionText,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...options.map((opt) {
                                  final isCorrect = opt == correct;
                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCorrect
                                          ? const Color(0xFFEAF2FF)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isCorrect
                                            ? const Color(0xFF2F66D0)
                                            : const Color(0xFFD1D5DB),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          isCorrect
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          size: 18,
                                          color: isCorrect
                                              ? const Color(0xFF2F66D0)
                                              : const Color(0xFF6B7280),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            opt,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isCorrect
                                                  ? const Color(0xFF2F66D0)
                                                  : const Color(0xFF374151),
                                              fontWeight: isCorrect
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamProgressBar extends StatelessWidget {
  final String title;
  final String examinerId;

  const _ExamProgressBar({required this.title, required this.examinerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .where('examinerId', isEqualTo: examinerId)
          .snapshots(),
      builder: (context, roomSnap) {
        if (!roomSnap.hasData) {
          return _buildBar(0.0, 'Loading...');
        }

        // Filter locally to avoid composite index
        final activeRooms = roomSnap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final docTitle = (data['examTitle'] ?? '').toString().trim();
          final status = (data['status'] ?? '').toString();
          return docTitle == title && status == 'started';
        }).toList();

        if (activeRooms.isEmpty) {
          return _buildBar(0.0, 'No active session');
        }

        final roomDoc = activeRooms.first;
        final data = roomDoc.data() as Map<String, dynamic>? ?? {};
        final maxStudentsRaw = data['maxStudents'];
        int maxStudents = 0;
        if (maxStudentsRaw is int) maxStudents = maxStudentsRaw;
        if (maxStudentsRaw is String) {
          maxStudents = int.tryParse(maxStudentsRaw) ?? 0;
        }

        if (maxStudents == 0) return _buildBar(0.0, '0 / 0 submitted');

        return StreamBuilder<QuerySnapshot>(
          stream: roomDoc.reference.collection('participants').snapshots(),
          builder: (context, partSnap) {
            if (!partSnap.hasData) return _buildBar(0.0, 'Loading...');

            int submittedCount = 0;
            for (var doc in partSnap.data!.docs) {
              final pData = doc.data() as Map<String, dynamic>? ?? {};
              final status = pData['status'] ?? '';
              if (status == 'finished' || status == 'completed') {
                submittedCount++;
              }
            }

            double progress = maxStudents > 0
                ? (submittedCount / maxStudents).clamp(0.0, 1.0)
                : 0.0;
            return _buildBar(
              progress,
              '$submittedCount / $maxStudents submitted',
            );
          },
        );
      },
    );
  }

  Widget _buildBar(double progress, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF2F66D0)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
