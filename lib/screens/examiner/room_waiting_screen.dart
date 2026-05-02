import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:examapp/screens/examiner/exam_ongoing_screen.dart';

class RoomWaitingScreen extends StatefulWidget {
  final String roomCode;
  final String examTitle;

  const RoomWaitingScreen({
    super.key,
    required this.roomCode,
    required this.examTitle,
  });

  @override
  State<RoomWaitingScreen> createState() => _RoomWaitingScreenState();
}

class _RoomWaitingScreenState extends State<RoomWaitingScreen> {
  void _acceptStudent(String studentDocId) {
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('participants')
        .doc(studentDocId)
        .update({'status': 'accepted'});
  }

  void _rejectStudent(String studentDocId) {
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('participants')
        .doc(studentDocId)
        .delete();
  }

  void _showSetDurationDialog() {
    int selectedMinutes = 60; // Default 1 hour
    final TextEditingController timeController = TextEditingController(text: selectedMinutes.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            
            void updateTime(int newTime) {
              if (newTime >= 1 && newTime <= 300) {
                setStateBuilder(() {
                  selectedMinutes = newTime;
                  timeController.text = newTime.toString();
                });
              }
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 48,
                      color: Color(0xFF2F66D0),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Exam Duration',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set the time limit for this exam session.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => updateTime(selectedMinutes - 15),
                          icon: const Icon(Icons.remove_circle_outline, size: 32),
                          color: const Color(0xFF2F66D0),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: timeController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed > 0) {
                                selectedMinutes = parsed;
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'MINS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => updateTime(selectedMinutes + 15),
                          icon: const Icon(Icons.add_circle_outline, size: 32),
                          color: const Color(0xFF2F66D0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Update room status
                              await FirebaseFirestore.instance
                                  .collection('rooms')
                                  .doc(widget.roomCode)
                                  .update({
                                'status': 'started',
                                'durationMinutes': selectedMinutes,
                                'startedAt': FieldValue.serverTimestamp(),
                              });

                              if (!ctx.mounted) return;
                              Navigator.pop(ctx); // Close dialog

                              // Go to Ongoing Screen
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExamOngoingScreen(
                                    roomCode: widget.roomCode,
                                    examTitle: widget.examTitle,
                                    durationMinutes: selectedMinutes,
                                    startedAt: DateTime.now(), // Pass local time for accuracy
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F66D0),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Start',
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 8,
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
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Waiting Room',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Room Code: ${widget.roomCode}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                    Text(
                      widget.examTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F66D0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.roomCode,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: Color(0xFF2F66D0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share this code with your students to join.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // STREAM BUILDER INJECTED HERE
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(widget.roomCode)
                      .collection('participants')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Error loading participants.'),
                      );
                    }

                    final allParticipants = snapshot.data?.docs ?? [];
                    final waitingStudents = allParticipants.where((d) {
                      final data = d.data() as Map<String, dynamic>?;
                      return data != null && data['status'] == 'waiting';
                    }).toList();

                    final acceptedStudents = allParticipants.where((d) {
                      final data = d.data() as Map<String, dynamic>?;
                      return data != null && data['status'] == 'accepted';
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Waiting for Approval',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Waiting Students List
                        Expanded(
                          child: waitingStudents.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.group_outlined,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No students waiting.',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: waitingStudents.length,
                                  itemBuilder: (context, index) {
                                    final doc = waitingStudents[index];
                                    final student =
                                        doc.data() as Map<String, dynamic>;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: const Color(
                                                0xFF2F66D0,
                                              ).withValues(alpha: 0.1),
                                              child: const Icon(
                                                Icons.person,
                                                color: Color(0xFF2F66D0),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    student['name'] ??
                                                        'Unknown',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.close),
                                                  color: Colors.red,
                                                  onPressed: () =>
                                                      _rejectStudent(doc.id),
                                                  tooltip: 'Reject',
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.check),
                                                  color: Colors.green,
                                                  onPressed: () =>
                                                      _acceptStudent(doc.id),
                                                  tooltip: 'Accept',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // Accepted Students Horizon List
                        if (acceptedStudents.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Accepted Students (${acceptedStudents.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: acceptedStudents.length,
                              itemBuilder: (context, index) {
                                final doc = acceptedStudents[index];
                                final student =
                                    doc.data() as Map<String, dynamic>;
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  child: Chip(
                                    avatar: const CircleAvatar(
                                      backgroundColor: Colors.white,
                                      child: Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                    ),
                                    label: Text(student['name'] ?? 'Unknown'),
                                    backgroundColor: Colors.green.withValues(
                                      alpha: 0.1,
                                    ),
                                    side: const BorderSide(color: Colors.green),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _showSetDurationDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F66D0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Start Exam',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
