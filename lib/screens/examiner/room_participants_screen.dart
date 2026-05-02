import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomParticipantsScreen extends StatefulWidget {
  final String roomCode;

  const RoomParticipantsScreen({
    super.key,
    required this.roomCode,
  });

  @override
  State<RoomParticipantsScreen> createState() => _RoomParticipantsScreenState();
}

class _RoomParticipantsScreenState extends State<RoomParticipantsScreen> {
  String _sortBy = 'Name (Ascending)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Row(
                      children: [
                         Text(
                          'Participants',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Exam is Ongoing',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Viewing the participants',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (val) => setState(() => _sortBy = val),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Text(_sortBy, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          const Icon(Icons.sort, size: 20),
                        ],
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem<String>(
                        enabled: false,
                        child: Text('SORT BY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'Warnings', child: Text('Warnings')),
                      const PopupMenuItem(value: 'Name (Ascending)', child: Text('Name (Ascending)')),
                      const PopupMenuItem(value: 'Name (Descending)', child: Text('Name (Descending)')),
                      const PopupMenuItem(value: 'Score (Lowest)', child: Text('Score (Lowest)')),
                      const PopupMenuItem(value: 'Score (Highest)', child: Text('Score (Highest)')),
                    ],
                  ),
                ],
              ),
            ),
            
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
                    return const Center(child: Text('Error loading participants.'));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  
                  // Only show participants that are accepted, in_progress, or finished
                  var activeParticipants = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final status = data['status'] ?? '';
                    return status == 'accepted' || status == 'in_progress' || status == 'finished' || status == 'completed';
                  }).toList();

                  activeParticipants.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aName = (aData['name'] ?? '').toString().toLowerCase();
                    final bName = (bData['name'] ?? '').toString().toLowerCase();
                    final aWarnings = aData['warnings'] ?? 0;
                    final bWarnings = bData['warnings'] ?? 0;
                    final aScore = aData['score'] is num ? (aData['score'] as num).toDouble() : 0.0;
                    final bScore = bData['score'] is num ? (bData['score'] as num).toDouble() : 0.0;

                    switch (_sortBy) {
                      case 'Warnings':
                        return bWarnings.compareTo(aWarnings);
                      case 'Name (Descending)':
                        return bName.compareTo(aName);
                      case 'Score (Lowest)':
                        return aScore.compareTo(bScore);
                      case 'Score (Highest)':
                        return bScore.compareTo(aScore);
                      case 'Name (Ascending)':
                      default:
                        return aName.compareTo(bName);
                    }
                  });

                  if (activeParticipants.isEmpty) {
                    return Center(
                      child: Text(
                        'No ongoing participants yet.',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 1000));
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: activeParticipants.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final studentDoc = activeParticipants[index];
                      final studentData = studentDoc.data() as Map<String, dynamic>;
                      final String name = studentData['name'] ?? 'Unknown Student';
                      final String statusStr = studentData['status'] ?? 'accepted';
                      
                      final bool isFinished = statusStr == 'finished' || statusStr == 'completed';

                      final int warnings = studentData['warnings'] ?? 0;

                      return Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black87,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              size: 32,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (warnings > 0) ...[
                                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isFinished ? const Color(0xFF2F66D0) : Colors.grey.shade500,
                                    borderRadius: BorderRadius.circular(16),
                                    border: isFinished 
                                        ? Border.all(color: const Color(0xFF2F66D0), width: 1.5)
                                        : null,
                                  ),
                                  child: Text(
                                    isFinished ? 'Done taking test' : 'In Exam Session',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (warnings > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      '$warnings warning(s) for leaving app',
                                      style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  );
                },
              ),
            ),
            
            // Fixed Bottom Container
            Container(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    // Pop everything and go home (e.g., pop until dashboard)
                    Navigator.of(context).popUntil((route) => route.isFirst);
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
                    'Home',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
