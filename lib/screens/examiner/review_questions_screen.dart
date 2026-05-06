import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewQuestionsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> extractedQuestions;
  final String? initialExamTitle;
  final String? existingExamId;
  final bool isManualMode;
  final bool isGoogleFormMode;

  const ReviewQuestionsScreen({
    super.key,
    required this.extractedQuestions,
    this.initialExamTitle,
    this.existingExamId,
    this.isManualMode = false,
    this.isGoogleFormMode = false,
  });

  @override
  State<ReviewQuestionsScreen> createState() => _ReviewQuestionsScreenState();
}

class _ReviewQuestionsScreenState extends State<ReviewQuestionsScreen> {
  late List<Map<String, dynamic>> _questions;
  late TextEditingController _examTitleController;
  String? _newlyCreatedExamId;
  bool _isSaving = false;

  bool get _showManualHeader {
    if (widget.isManualMode) return true;
    return widget.extractedQuestions.isEmpty &&
        (widget.existingExamId == null || widget.existingExamId!.isEmpty);
  }

  bool get _isManageEditMode {
    return widget.existingExamId != null && widget.existingExamId!.isNotEmpty;
  }

  bool get _showAddButtonAboveSave {
    return _showManualHeader || _isManageEditMode;
  }

  @override
  void initState() {
    super.initState();
    // Deep copy the list so we can freely edit it natively
    _questions = List.from(
      widget.extractedQuestions.map((q) => Map<String, dynamic>.from(q)),
    );
    _examTitleController = TextEditingController(
      text: (widget.initialExamTitle?.trim().isNotEmpty == true)
          ? widget.initialExamTitle!.trim()
          : 'AI Generated Exam',
    );
  }

  @override
  void dispose() {
    _examTitleController.dispose();
    super.dispose();
  }

  void _saveExamToDatabase() async {
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please add at least one question before saving.',
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final examTitle = _examTitleController.text.trim().isNotEmpty
            ? _examTitleController.text.trim()
            : 'AI Generated Exam';
        // Build the exam document
        final examData = {
          'examinerId': user.uid,
          'title': examTitle,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'ongoing',
          'progress': 0.0,
          'questions': _questions,
        };

        if ((widget.existingExamId != null && widget.existingExamId!.trim().isNotEmpty) || _newlyCreatedExamId != null) {
          final idToUpdate = (widget.existingExamId != null && widget.existingExamId!.trim().isNotEmpty) ? widget.existingExamId! : _newlyCreatedExamId!;
          await FirebaseFirestore.instance
              .collection('exams')
              .doc(idToUpdate)
              .update({
                'title': examTitle,
                'questions': _questions,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        } else {
          final existingQuery = await FirebaseFirestore.instance
              .collection('exams')
              .where('examinerId', isEqualTo: user.uid)
              .get();

          final existingDocs = existingQuery.docs.where((doc) {
            return (doc.data()['title'] ?? '').toString().trim() == examTitle;
          }).toList();

          if (existingDocs.isNotEmpty) {
            final docRef = existingDocs.first.reference;
            await docRef.update({
              'questions': _questions,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            _newlyCreatedExamId = docRef.id;
          } else {
            final docRef = await FirebaseFirestore.instance.collection('exams').add(examData);
            _newlyCreatedExamId = docRef.id;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Exam successfully saved!'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          // Pop back to Examiner Dashboard
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Opens editor so the examiner can change the question, choices, and correct answer.
  Future<void> _openEditQuestionDialog(int index) async {
    final initial = Map<String, dynamic>.from(_questions[index]);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _EditQuestionDialog(initial: initial, isNewQuestion: false),
    );
    if (result != null && mounted) {
      setState(() {
        _questions[index] = result;
      });
    }
  }

  Future<void> _addNewQuestion() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditQuestionDialog(
        initial: const {
          'question': '',
          'options': <String>[],
          'correct_answer': '',
        },
        isNewQuestion: true,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _questions.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const pageBackground = Color(0xFFF5F7FB);
    return Scaffold(
      backgroundColor: pageBackground,
      extendBody: true,
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
                    Text(
                      _showManualHeader
                          ? 'Manual Exam Creator'
                          : (widget.isGoogleFormMode
                                ? 'Review Google Form'
                                : (_isManageEditMode
                                      ? 'Edit Exam'
                                      : 'Review AI Generated Exam')),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _showManualHeader
                          ? '${_questions.length} Questions created'
                          : (widget.isGoogleFormMode
                                ? '${_questions.length} Questions imported'
                                : (_isManageEditMode
                                      ? '${_questions.length} Questions loaded'
                                      : '${_questions.length} Questions extracted')),
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
        child: Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 170),
              itemCount: _questions.isEmpty ? 2 : _questions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _examTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Exam title',
                        hintText: 'e.g. Midterm Exam For SBIT-3Q',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  );
                }

                if (_questions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Column(
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No questions yet. Tap + to add one manually.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final questionIndex = index - 1;
                final q = _questions[questionIndex];
                final options = List<String>.from(q['options'] ?? []);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2F66D0,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${questionIndex + 1}',
                                style: const TextStyle(
                                  color: Color(0xFF2F66D0),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                q['question'] ?? 'Missing Question',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit question',
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () =>
                                  _openEditQuestionDialog(questionIndex),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(options.length, (i) {
                          final isCorrect = options[i] == q['correct_answer'];
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCorrect
                                    ? Colors.green
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isCorrect
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: isCorrect
                                      ? Colors.green
                                      : Colors.grey.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    options[i],
                                    style: TextStyle(
                                      color: isCorrect
                                          ? Colors.green.shade700
                                          : Colors.black87,
                                      fontWeight: isCorrect
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom + 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showAddButtonAboveSave)
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _addNewQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F66D0),
                            shape: const CircleBorder(),
                            elevation: 2,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  if (_showAddButtonAboveSave) const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveExamToDatabase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F66D0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Exam to Database',
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
          ],
        ),
      ),
    );
  }
}

/// Dialog to edit question text, multiple-choice options, and correct answer.
class _EditQuestionDialog extends StatefulWidget {
  const _EditQuestionDialog({
    required this.initial,
    required this.isNewQuestion,
  });

  final Map<String, dynamic> initial;
  final bool isNewQuestion;

  @override
  State<_EditQuestionDialog> createState() => _EditQuestionDialogState();
}

class _EditQuestionDialogState extends State<_EditQuestionDialog> {
  late final TextEditingController _questionCtrl;
  late List<TextEditingController> _optionCtrls;

  /// `null` = none, option string = that choice, `'__manual__'` = use [_manualCorrectCtrl]
  String? _correctSelection;
  late final TextEditingController _manualCorrectCtrl;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _questionCtrl = TextEditingController(
      text: (q['question'] ?? '').toString(),
    );

    final opts = List<String>.from(q['options'] ?? []);
    if (opts.isEmpty) {
      _optionCtrls = [TextEditingController(), TextEditingController()];
    } else {
      _optionCtrls = opts.map((o) => TextEditingController(text: o)).toList();
    }

    final correct = (q['correct_answer'] ?? '').toString().trim();
    final trimmedOpts = _trimmedOptionsFromControllers();
    if (correct.isEmpty) {
      _correctSelection = null;
    } else if (trimmedOpts.contains(correct)) {
      _correctSelection = correct;
    } else {
      _correctSelection = '__manual__';
    }
    _manualCorrectCtrl = TextEditingController(
      text: trimmedOpts.contains(correct) ? '' : correct,
    );
  }

  List<String> _trimmedOptionsFromControllers() {
    return _optionCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _buildCorrectAnswer() {
    if (_correctSelection == null || _correctSelection!.isEmpty) return '';
    if (_correctSelection == '__manual__') {
      return _manualCorrectCtrl.text.trim();
    }
    return _correctSelection!;
  }

  void _addOption() {
    setState(() {
      _optionCtrls.add(TextEditingController());
    });
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    _manualCorrectCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the question text.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    final options = _trimmedOptionsFromControllers();
    var correct = _buildCorrectAnswer();
    // Clear correct if it pointed at a removed option (not using custom text).
    if (correct.isNotEmpty &&
        options.isNotEmpty &&
        !options.contains(correct) &&
        _correctSelection != '__manual__') {
      correct = '';
    }

    if (!widget.isNewQuestion) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('You Did Some Changes'),
            content: const Text(
              'Are you sure you want to leave this page?\n\nClick Continue to Save Your Progress',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F66D0),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (shouldContinue != true) return;
    }

    if (!mounted) return;


    Navigator.of(context).pop(<String, dynamic>{
      'question': question,
      'options': options,
      'correct_answer': correct,
    });
  }

  static const Color _brand = Color(0xFF2F66D0);
  static const Color _surfaceMuted = Color(0xFFF1F5F9);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final options = _trimmedOptionsFromControllers();
    final uniqueOptions = <String>[];
    for (final o in options) {
      if (!uniqueOptions.contains(o)) uniqueOptions.add(o);
    }
    final correctItems = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(
        value: null,
        child: Text(
          'No correct answer',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      ...uniqueOptions.map(
        (o) => DropdownMenuItem<String?>(
          value: o,
          child: Text(o, overflow: TextOverflow.ellipsis, maxLines: 2),
        ),
      ),
      DropdownMenuItem<String?>(
        value: '__manual__',
        child: Row(
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 20,
              color: _brand.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('Custom answer (typed)')),
          ],
        ),
      ),
    ];

    var dropdownValue = _correctSelection;
    if (dropdownValue != null &&
        dropdownValue != '__manual__' &&
        !uniqueOptions.contains(dropdownValue)) {
      dropdownValue = '__manual__';
    }

    final inputRadius = BorderRadius.circular(14);
    final borderSide = BorderSide(color: _border);
    final focusedBorder = BorderSide(color: _brand, width: 2);

    InputDecoration fieldDecoration({
      String? label,
      String? hint,
      Widget? prefix,
      int? maxLines,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        filled: true,
        fillColor: Colors.white,
        alignLabelWithHint: maxLines != null && maxLines > 1,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: focusedBorder,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 40)
            .clamp(0.0, 440)
            .toDouble(),
        height: (MediaQuery.sizeOf(context).height * 0.85)
            .clamp(320.0, 640)
            .toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
              decoration: BoxDecoration(
                color: _brand,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.isNewQuestion
                          ? Icons.add_circle_outline_rounded
                          : Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isNewQuestion
                              ? 'Add question'
                              : 'Edit question',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isNewQuestion
                              ? 'Create a new question, choices, and the correct answer for grading.'
                              : 'Update the prompt, choices, and the correct answer for grading.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      hoverColor: Colors.white24,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 24),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel(
                      'Question',
                      'Shown to students as written below.',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _questionCtrl,
                      decoration: fieldDecoration(
                        label: 'Question text',
                        hint: 'Enter the full question…',
                        maxLines: 4,
                      ),
                      maxLines: 5,
                      minLines: 3,
                      style: const TextStyle(fontSize: 15, height: 1.45),
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel(
                      'Answer choices',
                      'At least one option. Remove rows you don’t need.',
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_optionCtrls.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _brand.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: _brand,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _optionCtrls[i],
                                  decoration: InputDecoration(
                                    hintText: 'Choice ${i + 1}',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 15),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Remove choice',
                                  icon: Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: _optionCtrls.length > 1
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade300,
                                  ),
                                  onPressed: _optionCtrls.length > 1
                                      ? () {
                                          setState(() {
                                            final removed = _optionCtrls
                                                .removeAt(i);
                                            removed.dispose();
                                            if (_correctSelection ==
                                                removed.text.trim()) {
                                              _correctSelection = null;
                                            }
                                          });
                                        }
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    OutlinedButton.icon(
                      onPressed: _addOption,
                      icon: Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: _brand.withValues(alpha: 0.95),
                      ),
                      label: Text(
                        'Add choice',
                        style: TextStyle(
                          color: _brand,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        side: BorderSide(color: _brand.withValues(alpha: 0.45)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: _brand.withValues(alpha: 0.04),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel(
                      'Correct answer',
                      'Used when auto-grading or highlighting the key.',
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: dropdownValue,
                      decoration:
                          fieldDecoration(
                            label: 'Mark the correct option',
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified_outlined,
                                color: _brand.withValues(alpha: 0.75),
                                size: 22,
                              ),
                            ),
                          ).copyWith(
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                          ),
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(14),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey.shade600,
                      ),
                      items: correctItems,
                      onChanged: (v) {
                        setState(() {
                          _correctSelection = v;
                          if (v != '__manual__' && v != null) {
                            _manualCorrectCtrl.clear();
                          }
                        });
                      },
                    ),
                    if (_correctSelection == '__manual__') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _manualCorrectCtrl,
                        decoration: fieldDecoration(
                          label: 'Custom correct answer',
                          hint:
                              'Must match how you want it stored (e.g. exact spelling)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use this when the key doesn’t match one of the choices exactly.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Divider(height: 1, thickness: 1, color: _border),

            // Footer actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.grey.shade800,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded, size: 22),
                      label: Text(
                        widget.isNewQuestion ? 'Add question' : 'Save changes',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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

  Widget _sectionLabel(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
