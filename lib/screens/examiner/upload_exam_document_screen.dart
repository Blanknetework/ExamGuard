import 'dart:io' as io;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:examapp/screens/examiner/review_questions_screen.dart';

class UploadExamDocumentScreen extends StatefulWidget {
  const UploadExamDocumentScreen({super.key});

  @override
  State<UploadExamDocumentScreen> createState() =>
      _UploadExamDocumentScreenState();
}

class _UploadExamDocumentScreenState extends State<UploadExamDocumentScreen> {
  static const String _debugGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY_DEBUG',
  );
  final TextEditingController _questionCountController = TextEditingController(
    text: '50',
  );
  List<Map<String, dynamic>> _extractedQuestions = [];
  bool _isUploading = false;
  bool _isSuccess = false;

  String _suggestExamTitleFromFileName(String fileName) {
    final normalized = fileName.replaceAll('\\', '/');
    final nameOnly = normalized.split('/').last;
    final dotIndex = nameOnly.lastIndexOf('.');
    final baseName = dotIndex > 0 ? nameOnly.substring(0, dotIndex) : nameOnly;
    final cleaned = baseName.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return cleaned.isNotEmpty ? cleaned : 'AI Generated Exam';
  }

  bool _isQuotaLikeError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('429') ||
        text.contains('503') ||
        text.contains('500') ||
        text.contains('502') ||
        text.contains('504') ||
        text.contains('resource_exhausted') ||
        text.contains('quota');
  }

  int _requestedQuestionCount() {
    final raw = _questionCountController.text.trim();
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return 10;
    if (parsed > 100) return 100;
    return parsed;
  }

  List<Map<String, dynamic>> _buildOfflineQuestionsFromText(String text) {
    final targetCount = _requestedQuestionCount();
    final normalized = text.replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.length > 12)
        .toList();

    final candidates = <String>[];
    for (final line in lines) {
      if (line.contains('?')) {
        candidates.add(line);
      }
      if (candidates.length >= targetCount) break;
    }

    if (candidates.isEmpty) {
      final sentencePieces = normalized
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((e) => e.trim())
          .where((e) => e.length > 20)
          .toList();
      for (final s in sentencePieces) {
        if (candidates.length >= targetCount) break;
        candidates.add(s.endsWith('?') ? s : '$s?');
      }
    }

    final limited = candidates.take(targetCount).toList();
    if (limited.isEmpty) {
      return [
        {
          'question': 'What is the sum of 2 + 2?',
          'options': ['3', '4', '5', '6'],
          'correct_answer': '4',
        },
        {
          'question': 'Which planet is known as the Red Planet?',
          'options': ['Earth', 'Mars', 'Jupiter', 'Saturn'],
          'correct_answer': 'Mars',
        },
      ];
    }

    return limited.map((q) {
      return {
        'question': q,
        'options': const ['Option A', 'Option B', 'Option C', 'Option D'],
        'correct_answer': 'Option A',
      };
    }).toList();
  }

  List<Map<String, dynamic>> _parseQuestionsFromAiResponse(String rawText) {
    var cleaned = rawText.trim();
    cleaned = cleaned.replaceAll('```json', '').replaceAll('```', '').trim();
    cleaned = cleaned.replaceAll('\u201c', '"').replaceAll('\u201d', '"');
    cleaned = cleaned.replaceAll('\u2018', "'").replaceAll('\u2019', "'");

    final start = cleaned.indexOf('[');
    if (start == -1) {
      throw const FormatException('No JSON array start found.');
    }

    final end = cleaned.lastIndexOf(']');
    if (end == -1 || end <= start) {
      throw const FormatException('No JSON array end found.');
    }

    cleaned = cleaned.substring(start, end + 1);
    cleaned = cleaned.replaceAll(RegExp(r',\s*([\]}])'), r'$1');

    final decoded = jsonDecode(cleaned);
    if (decoded is! List) {
      throw const FormatException('Root JSON value is not a list.');
    }

    final normalized = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final question = (map['question'] ?? '').toString().trim();
      final optionsRaw = map['options'];
      final options = optionsRaw is List
          ? optionsRaw
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];
      var correct = (map['correct_answer'] ?? '').toString().trim();

      if (question.isEmpty || options.isEmpty) continue;
      if (correct.isEmpty || !options.contains(correct)) {
        correct = options.first;
      }

      normalized.add({
        'question': question,
        'options': options,
        'correct_answer': correct,
      });
    }

    return normalized;
  }

  Future<String> _extractTextFromFile(PlatformFile file) async {
    final extension = file.extension?.toLowerCase() ?? '';
    Uint8List fileBytes;

    if (kIsWeb) {
      if (file.bytes == null) throw Exception('File bytes are null on web.');
      fileBytes = file.bytes!;
    } else {
      if (file.path == null) {
        throw Exception('File path is null on mobile/desktop.');
      }
      fileBytes = await io.File(file.path!).readAsBytes();
    }

    if (extension == 'pdf') {
      final document = PdfDocument(inputBytes: fileBytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      return text;
    }
    if (extension == 'docx') {
      return docxToText(fileBytes);
    }
    return utf8.decode(fileBytes);
  }

  String _friendlyErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('503') ||
        text.contains('500') ||
        text.contains('502') ||
        text.contains('504') ||
        text.contains('temporarily unavailable')) {
      return 'Gemini is temporarily unavailable. Generated questions in offline mode instead.';
    }
    if (text.contains('gemini') &&
        (text.contains('429') ||
            text.contains('resource_exhausted') ||
            text.contains('quota'))) {
      return 'Gemini quota/rate limit reached. Try again later or check billing.';
    }
    if (text.contains('formatexception') || text.contains('json')) {
      return 'AI returned invalid JSON format. Please try uploading again.';
    }
    if (text.contains('google api error: 401')) {
      return 'Invalid Gemini API key. Check GEMINI_API_KEY in your .env file.';
    }
    if (text.contains('google api error: 403') ||
        text.contains('permission_denied')) {
      return 'Gemini API access denied. Check your project and key permissions.';
    }
    return 'AI request failed. Generated questions in offline mode instead.';
  }

  @override
  void dispose() {
    _questionCountController.dispose();
    super.dispose();
  }

  void _pickFileAndUpload() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.path == null && file.bytes == null) return;

    final extension = file.extension?.toLowerCase() ?? '';
    if (extension != 'pdf' && extension != 'txt' && extension != 'docx') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please upload a .pdf, .txt, or .docx file.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _isSuccess = false;
      _extractedQuestions = [];
    });

    final examTitle = _suggestExamTitleFromFileName(file.name);

    try {
      bool usedOfflineFallback = false;
      String? fallbackNotice;
      final extractedText = await _extractTextFromFile(file);

      final envGeminiKey = dotenv.env['GEMINI_API_KEY']?.trim();
      final apiKey = (envGeminiKey != null && envGeminiKey.isNotEmpty)
          ? envGeminiKey
          : (_debugGeminiApiKey.isNotEmpty ? _debugGeminiApiKey : null);
      final geminiModel = dotenv.env['GEMINI_MODEL']?.trim().isNotEmpty == true
          ? dotenv.env['GEMINI_MODEL']!.trim()
          : 'gemini-2.0-flash';

      final isMissingKey =
          apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_GEMINI_KEY';
      if (isMissingKey) {
        _extractedQuestions = _buildOfflineQuestionsFromText(extractedText);
        usedOfflineFallback = true;
        fallbackNotice =
            'Gemini API key missing. Generated questions in offline mode.';
      } else {
        try {
          // Gemini request via flutter_gemini package
          final prompt =
              '''
You are an expert exam generation AI. Read the following text and extract exactly ${_questionCountController.text.trim().isEmpty ? "all" : _questionCountController.text.trim()} multiple-choice questions from it.
If the text is messy, cleanly format each question.
You MUST respond with pure JSON array format ONLY. Do not include markdown formatting or backticks.
Return a JSON array of questions only, where each object has:
- "question": string
- "options": array of strings
- "correct_answer": string

Example format:
[
  {
    "question": "What is the capital of France?",
    "options": ["London", "Paris", "Berlin", "Madrid"],
    "correct_answer": "Paris"
  }
]

Text to parse:
$extractedText
''';

          Gemini.init(apiKey: apiKey);
          final gemini = Gemini.instance;
          final response = await gemini.prompt(
            parts: [Part.text(prompt)],
            model: geminiModel,
            generationConfig: GenerationConfig(temperature: 0.2),
          );

          final rawText = (response?.output ?? '').trim();
          if (rawText.isEmpty) {
            throw Exception('Gemini API Error: Empty response text.');
          }
          _extractedQuestions = _parseQuestionsFromAiResponse(rawText);

          if (_extractedQuestions.isEmpty) {
            throw Exception('AI returned an empty format.');
          }
        } catch (e) {
          if (_isQuotaLikeError(e)) {
            _extractedQuestions = _buildOfflineQuestionsFromText(extractedText);
            usedOfflineFallback = true;
            fallbackNotice =
                'Gemini unavailable/quota reached. Generated questions in offline mode.';
          } else {
            rethrow;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isUploading = false;
          _isSuccess = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${usedOfflineFallback ? 'Offline mode generated ' : 'AI successfully extracted '}${_extractedQuestions.length} questions!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: usedOfflineFallback
                ? Colors.orange.shade700
                : Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(20),
            duration: const Duration(seconds: 3),
          ),
        );

        if (usedOfflineFallback && fallbackNotice != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(fallbackNotice),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Navigate to the ReviewQuestionsScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewQuestionsScreen(
              extractedQuestions: _extractedQuestions,
              initialExamTitle: examTitle,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('AI upload error: $e');
      if (mounted) {
        final errorMessage = _friendlyErrorMessage(e);
        List<Map<String, dynamic>> offlineQuestions;
        try {
          final extractedText = await _extractTextFromFile(file);
          offlineQuestions = _buildOfflineQuestionsFromText(extractedText);
        } catch (_) {
          offlineQuestions = [
            {
              'question': 'What is the sum of 2 + 2?',
              'options': ['3', '4', '5', '6'],
              'correct_answer': '4',
            },
          ];
        }
        
        if (!context.mounted) return;

        setState(() {
          _isUploading = false;
          _isSuccess = true;
          _extractedQuestions = offlineQuestions;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.fixed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewQuestionsScreen(
              extractedQuestions: _extractedQuestions,
              initialExamTitle: examTitle,
            ),
          ),
        );
      }
    }
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
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Upload Exam Document',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F66D0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF2F66D0),
                      size: 32,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Our AI will automatically scan your .txt or .pdf file and generate a multiple-choice exam.',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Removed provider label to hide AI usage details

              const SizedBox(height: 24),

              // Question Count Input
              const Text(
                'Number of Questions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _questionCountController,
                keyboardType: TextInputType.number,
                enabled: !_isUploading && !_isSuccess,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.format_list_numbered),
                  hintText: 'e.g. 50 (Leave blank for all)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF2F66D0),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Upload Box
              GestureDetector(
                onTap: _isUploading ? null : _pickFileAndUpload,
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(
                      color: _isSuccess
                          ? Colors.green.shade400
                          : const Color(0xFF2F66D0).withValues(alpha: 0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isUploading) ...[
                        const SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: Color(0xFF2F66D0),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'AI is reading your document...\nPlease wait.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF2F66D0),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (_isSuccess) ...[
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 80,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Exam Generated!',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tap to Select File',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Supported formats: .txt, .pdf, .docx',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Continue Button
              if (_isSuccess)
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewQuestionsScreen(
                            extractedQuestions: _extractedQuestions,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F66D0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Review Questions',
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
