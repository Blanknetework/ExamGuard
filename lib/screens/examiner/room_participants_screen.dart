import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  bool _isExporting = false;
  String _sortBy = 'Name (Ascending)';

  int _totalQuestions = 0;

  @override
  void initState() {
    super.initState();
    _fetchExamDetails();
  }

  Future<void> _fetchExamDetails() async {
    try {
      final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).get();
      if (!roomDoc.exists) return;
      final roomData = roomDoc.data() ?? {};
      final examTitle = roomData['examTitle'];
      final examinerId = roomData['examinerId'];

      if (examTitle != null && examinerId != null) {
        final examsQuery = await FirebaseFirestore.instance
            .collection('exams')
            .where('title', isEqualTo: examTitle)
            .where('examinerId', isEqualTo: examinerId)
            .limit(1)
            .get();

        if (examsQuery.docs.isNotEmpty) {
          final examData = examsQuery.docs.first.data();
          final qList = examData['questions'] as List?;
          if (qList != null && mounted) {
            setState(() {
              _totalQuestions = qList.length;
            });
          }
        }
      }
    } catch (_) {}
  }

  double _parseScorePercentage(dynamic scoreVal) {
    if (scoreVal == null) return 0.0;
    if (scoreVal is num) return scoreVal.toDouble();
    if (scoreVal is String) {
      if (scoreVal.contains('/')) {
        final parts = scoreVal.split('/');
        if (parts.length == 2) {
          final correct = double.tryParse(parts[0]) ?? 0.0;
          final total = double.tryParse(parts[1]) ?? 1.0;
          if (total > 0) return (correct / total) * 100;
        }
      }
    }
    return 0.0;
  }

  List<Map<String, dynamic>> _sortParticipants(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final aName = (a['name'] ?? '').toString().toLowerCase();
      final bName = (b['name'] ?? '').toString().toLowerCase();
      final aWarnings = a['warnings'] ?? 0;
      final bWarnings = b['warnings'] ?? 0;
      final aScore = _parseScorePercentage(a['score']);
      final bScore = _parseScorePercentage(b['score']);

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
    return list;
  }

  Future<void> _exportPDF(List<Map<String, dynamic>> participants) async {
    pw.Font? font;
    pw.Font? boldFont;

    try {
      font = await PdfGoogleFonts.notoSansRegular();
      boldFont = await PdfGoogleFonts.notoSansBold();
    } catch (e) {
      debugPrint('Failed to load Google Fonts: $e');
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: boldFont,
      ),
    );

    // Fetch room and examiner info
    final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).get();
    final roomData = roomDoc.data() ?? {};
    final examTitle = roomData['examTitle'] ?? 'Exam';
    final examinerId = roomData['examinerId'];
    
    String teacherName = 'Teacher';
    if (examinerId != null) {
      final examinerDoc = await FirebaseFirestore.instance.collection('users').doc(examinerId).get();
      teacherName = examinerDoc.data()?['name'] ?? 'Teacher';
    }

    // Sort specifically for PDF: highest score first
    final sortedForPdf = List<Map<String, dynamic>>.from(participants);
    sortedForPdf.sort((a, b) {
      return _parseScorePercentage(b['score']).compareTo(_parseScorePercentage(a['score']));
    });

    // Calculate Statistics
    double totalPercentage = 0.0;
    double highestPercentage = 0.0;
    double lowestPercentage = 100.0;
    int passCount = 0;
    int completedCount = 0;

    for (var p in sortedForPdf) {
      final status = (p['status'] ?? '').toString();
      if (status == 'finished' || status == 'completed') {
        completedCount++;
        final percentage = _parseScorePercentage(p['score']);
        totalPercentage += percentage;
        if (percentage > highestPercentage) highestPercentage = percentage;
        if (percentage < lowestPercentage) lowestPercentage = percentage;
        if (percentage >= 50.0) passCount++; // Assuming 50% is passing
      }
    }
    
    if (completedCount == 0) lowestPercentage = 0.0;
    final averageScore = completedCount > 0 ? (totalPercentage / completedCount) : 0.0;
    final passingRate = completedCount > 0 ? ((passCount / completedCount) * 100) : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ExamGuard', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2F66D0'))),
                pw.Text('Exam Results Report', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('Exam Name: $examTitle', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Teacher Name: $teacherName', style: pw.TextStyle(fontSize: 12)),
            pw.Text('Room Code: ${widget.roomCode}', style: pw.TextStyle(fontSize: 12)),
            pw.Text('Date Generated: ${DateTime.now().toString().substring(0, 16)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 16),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by ExamGuard App', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        build: (context) => [
          // Summary Section
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildPdfStatItem('Total Students', '${sortedForPdf.length}'),
                _buildPdfStatItem('Average Score', '${averageScore.toStringAsFixed(1)}%'),
                _buildPdfStatItem('Highest Score', '${highestPercentage.toStringAsFixed(1)}%'),
                _buildPdfStatItem('Lowest Score', '${lowestPercentage.toStringAsFixed(1)}%'),
                _buildPdfStatItem('Passing Rate', '${passingRate.toStringAsFixed(1)}%'),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Student Results', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          
          // Student Results Table
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
            cellStyle: pw.TextStyle(fontSize: 10),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#2F66D0')),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
            },
            headers: ['Rank', 'Student Name', 'Score', 'Percentage', 'Status', 'Pass/Fail'],
            data: List.generate(sortedForPdf.length, (i) {
              final p = sortedForPdf[i];
              final name = p['name'] ?? 'Unknown';
              final scoreRaw = p['score'];
              final percentage = _parseScorePercentage(scoreRaw);
              
              String rawScoreStr = '—';
              if (scoreRaw != null) {
                if (scoreRaw is String) {
                  rawScoreStr = scoreRaw;
                } else if (scoreRaw is num) {
                  if (_totalQuestions > 0) {
                    final correct = ((scoreRaw / 100) * _totalQuestions).round();
                    rawScoreStr = '$correct/$_totalQuestions';
                  } else {
                    rawScoreStr = '${scoreRaw.toStringAsFixed(1)}%';
                  }
                }
              }

              final status = (p['status'] ?? '').toString();
              final isFinished = status == 'finished' || status == 'completed';
              final autoSubmitted = p['autoSubmitted'] == true;
              
              String statusStr = 'In Progress';
              if (autoSubmitted) {
                statusStr = 'Auto-Submitted';
              } else if (isFinished) {
                statusStr = 'Completed';
              }
              
              final passed = percentage >= 50.0;
              final passFailIcon = isFinished ? (passed ? 'PASS' : 'FAIL') : '—';
              
              // Top 3 gets highlighted rank
              final rankStr = (i < 3) ? '#${i + 1}' : '${i + 1}';

              return [
                rankStr,
                name,
                rawScoreStr,
                isFinished ? '${percentage.toStringAsFixed(1)}%' : '—',
                statusStr,
                passFailIcon,
              ];
            }),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'ExamGuard_${examTitle.replaceAll(' ', '_')}_Results';
    
    try {
      await Printing.sharePdf(
        bytes: bytes,
        filename: '$fileName.pdf',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF downloaded successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfStatItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2F66D0'))),
        pw.SizedBox(height: 4),
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ],
    );
  }

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

                  // Convert to list of maps for sorting and PDF export
                  final participantDataList = activeParticipants.map((d) => d.data() as Map<String, dynamic>).toList();
                  _sortParticipants(participantDataList);

                  if (participantDataList.isEmpty) {
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
                    itemCount: participantDataList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final studentData = participantDataList[index];
                      final String name = studentData['name'] ?? 'Unknown Student';
                      final String statusStr = studentData['status'] ?? 'accepted';
                      
                      final bool isFinished = statusStr == 'finished' || statusStr == 'completed';
                      final bool autoSubmitted = studentData['autoSubmitted'] == true;
                      final int warnings = studentData['warnings'] ?? 0;
                      final score = studentData['score'];
                      String scoreStr = '';
                      if (score != null) {
                        if (score is num) {
                          scoreStr = '${score.toStringAsFixed(1)}%';
                        } else if (score is String) {
                          if (score.contains('/')) {
                            final percentage = _parseScorePercentage(score);
                            scoreStr = '$score (${percentage.toStringAsFixed(1)}%)';
                          } else {
                            scoreStr = score;
                          }
                        }
                      }

                      return Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: autoSubmitted ? Colors.red : (isFinished ? const Color(0xFF2F66D0) : Colors.black87),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              autoSubmitted ? Icons.gpp_bad_rounded : Icons.person_outline,
                              size: 32,
                              color: autoSubmitted ? Colors.red : Colors.black87,
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
                                    if (isFinished && scoreStr.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.green.shade300),
                                        ),
                                        child: Text(
                                          scoreStr,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Status badge
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: autoSubmitted
                                            ? Colors.red
                                            : (isFinished ? const Color(0xFF2F66D0) : Colors.grey.shade500),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        autoSubmitted
                                            ? 'Auto-Submitted'
                                            : (isFinished ? 'Done taking test' : 'In Exam Session'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Warning details
                                if (warnings > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      autoSubmitted
                                          ? '$warnings warning(s) — left the app (auto-submitted)'
                                          : '$warnings warning(s) — split screen / notification',
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
            
            // Bottom Buttons
            Container(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 24),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _isExporting ? null : () async {
                          setState(() => _isExporting = true);
                          try {
                            // Fetch latest data for PDF
                            final snap = await FirebaseFirestore.instance
                                .collection('rooms')
                                .doc(widget.roomCode)
                                .collection('participants')
                                .get();
                            final pList = snap.docs
                                .map((d) => d.data())
                                .where((d) {
                                  final s = d['status'] ?? '';
                                  return s == 'accepted' || s == 'in_progress' || s == 'finished' || s == 'completed';
                                })
                                .toList();
                            _sortParticipants(pList);
                            await _exportPDF(pList);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isExporting = false);
                          }
                        },
                        icon: _isExporting 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2F66D0)))
                          : const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2F66D0)),
                        label: Text(
                          _isExporting ? 'Exporting...' : 'Export PDF',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F66D0),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2F66D0), width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
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
          ],
        ),
      ),
    );
  }
}
