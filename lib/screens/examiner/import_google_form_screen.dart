import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:examapp/screens/examiner/review_questions_screen.dart';

class ImportGoogleFormScreen extends StatefulWidget {
  const ImportGoogleFormScreen({super.key});

  @override
  State<ImportGoogleFormScreen> createState() => _ImportGoogleFormScreenState();
}

class _ImportGoogleFormScreenState extends State<ImportGoogleFormScreen> {
  final TextEditingController _linkController = TextEditingController();
  bool _isConnecting = false;
  bool _isSuccess = false;
  List<Map<String, dynamic>> _syncedQuestions = [];
  String _importedExamTitle = 'Google Form Exam';

  String _extractFormTitle(Map<String, dynamic> formData) {
    final top = (formData['title'] ?? '').toString().trim();
    if (top.isNotEmpty) return top;
    final info = formData['info'];
    if (info is Map<String, dynamic>) {
      final infoTitle = (info['title'] ?? '').toString().trim();
      if (infoTitle.isNotEmpty) return infoTitle;
      final documentTitle = (info['documentTitle'] ?? '').toString().trim();
      if (documentTitle.isNotEmpty) return documentTitle;
    }
    return 'Google Form Exam';
  }


  String? _extractFormId(String url) {
    var s = url.trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('http')) s = 'https://$s';
    final uri = Uri.tryParse(s);
    if (uri == null) return null;

    final path = uri.path;
    final published = RegExp(
      r'/forms/d/e/([a-zA-Z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (published != null) return published.group(1);

    final editor = RegExp(
      r'/forms/d/(?!e/)([a-zA-Z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (editor != null) return editor.group(1);

    final idParam = uri.queryParameters['id'];
    if (idParam != null && idParam.isNotEmpty) return idParam;

    return null;
  }

  /// Short links (forms.gle, goo.gl) return HTML; extract the real docs.google.com URL.
  Future<String> _expandShortFormLink(String raw) async {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http')) s = 'https://$s';
    final uri = Uri.tryParse(s);
    if (uri == null) return raw.trim();

    final host = uri.host.toLowerCase();
    if (!host.contains('forms.gle') && !host.contains('goo.gl')) {
      return s;
    }

    try {
      final res = await http
          .get(
            uri,
            headers: {'User-Agent': 'Mozilla/5.0 (compatible; ExamApp/1.0)'},
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return s;

      final match = RegExp(
        r'https://docs\.google\.com/forms/d/[^"\s<>]+',
        caseSensitive: false,
      ).firstMatch(res.body);
      if (match != null) {
        var found = match.group(0)!;
        if (found.endsWith('\\') || found.endsWith('"')) {
          found = found.substring(0, found.length - 1);
        }
        return found;
      }
    } catch (e) {
      debugPrint('Short link expand failed: $e');
    }
    return s;
  }


  Future<List<String>> _discoverFormIdsFromPublicPage(String formId) async {
    final urls = <Uri>[
      Uri.parse('https://docs.google.com/forms/d/e/$formId/viewform'),
      Uri.parse('https://docs.google.com/forms/d/$formId/viewform'),
    ];
    final found = <String>{};
    for (final u in urls) {
      try {
        final res = await http
            .get(
              u,
              headers: {'User-Agent': 'Mozilla/5.0 (compatible; ExamApp/1.0)'},
            )
            .timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) continue;
        final body = res.body;
        for (final m in RegExp(
          r'docs\.google\.com/forms/d/([a-zA-Z0-9_-]+)/edit',
          caseSensitive: false,
        ).allMatches(body)) {
          final id = m.group(1);
          if (id != null && id != 'e' && id.isNotEmpty) found.add(id);
        }
        for (final m in RegExp(
          r'"formId"\s*:\s*"([a-zA-Z0-9_-]+)"',
          caseSensitive: false,
        ).allMatches(body)) {
          final id = m.group(1);
          if (id != null && id != 'e' && id.isNotEmpty) found.add(id);
        }
      } catch (e) {
        debugPrint('Public page fetch failed ($u): $e');
      }
    }
    return found.toList();
  }

  Uri _formsApiUri(String formId) {
    return Uri(
      scheme: 'https',
      host: 'forms.googleapis.com',
      pathSegments: ['v1', 'forms', formId],
    );
  }

  Future<http.Response> _getFormWithToken(String formId, String accessToken) {
    return http.get(
      _formsApiUri(formId),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  }


  String _itemQuestionHeading(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString().trim();
    final description = (item['description'] ?? '').toString().trim();
    if (title.isNotEmpty && description.isNotEmpty) {
      return '$title\n$description';
    }
    if (title.isNotEmpty) return title;
    if (description.isNotEmpty) return description;
    return '';
  }

  List<String> _optionsFromChoiceQuestion(Map<String, dynamic> choiceQuestion) {
    final options = <String>[];
    final rawOptions = (choiceQuestion['options'] as List<dynamic>? ?? []);
    for (final option in rawOptions) {
      if (option is Map<String, dynamic>) {
        final value = (option['value'] ?? '').toString().trim();
        if (value.isNotEmpty) options.add(value);
      }
    }
    return options;
  }

  String _correctAnswerFromQuestion(Map<String, dynamic> question) {
    final grading = question['grading'];
    if (grading is! Map<String, dynamic>) return '';
    final correctAnswers = grading['correctAnswers'];
    if (correctAnswers is! Map<String, dynamic>) return '';
    final answers = (correctAnswers['answers'] as List<dynamic>? ?? []);
    if (answers.isEmpty || answers.first is! Map<String, dynamic>) return '';
    return (answers.first['value'] ?? '').toString().trim();
  }

  List<Map<String, dynamic>> _mapQuestionsFromForm(
    Map<String, dynamic> formData,
  ) {
    final items = (formData['items'] as List<dynamic>? ?? []);
    final extracted = <Map<String, dynamic>>[];

    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final item = raw;

      final questionItem = item['questionItem'];
      if (questionItem is Map<String, dynamic>) {
        final question = questionItem['question'];
        if (question is! Map<String, dynamic>) continue;

        var heading = _itemQuestionHeading(item);
        final legacyText = (question['text'] ?? '').toString().trim();
        if (heading.isEmpty && legacyText.isNotEmpty) heading = legacyText;
        if (heading.isEmpty) continue;

        final choiceQuestion = question['choiceQuestion'];
        if (choiceQuestion is Map<String, dynamic>) {
          extracted.add({
            'question': heading,
            'options': _optionsFromChoiceQuestion(choiceQuestion),
            'correct_answer': _correctAnswerFromQuestion(question),
          });
          continue;
        }

        if (question['textQuestion'] != null) {
          extracted.add({
            'question': heading,
            'options': <String>[],
            'correct_answer': '',
          });
        }
        continue;
      }

      final questionGroupItem = item['questionGroupItem'];
      if (questionGroupItem is Map<String, dynamic>) {
        final groupHeading = _itemQuestionHeading(item);
        final grid = questionGroupItem['grid'];
        List<String> columnOptions = [];
        if (grid is Map<String, dynamic>) {
          final columns = grid['columns'];
          if (columns is Map<String, dynamic>) {
            columnOptions = _optionsFromChoiceQuestion(columns);
          }
        }

        final subQuestions =
            (questionGroupItem['questions'] as List<dynamic>? ?? []);
        for (final sub in subQuestions) {
          if (sub is! Map<String, dynamic>) continue;
          final rowQuestion = sub['rowQuestion'];
          if (rowQuestion is! Map<String, dynamic>) continue;
          final rowTitle = (rowQuestion['title'] ?? '').toString().trim();
          if (rowTitle.isEmpty) continue;
          final fullTitle = groupHeading.isNotEmpty
              ? '$groupHeading\n$rowTitle'
              : rowTitle;
          extracted.add({
            'question': fullTitle,
            'options': List<String>.from(columnOptions),
            'correct_answer': _correctAnswerFromQuestion(sub),
          });
        }
      }
    }

    return extracted;
  }

  Future<void> _importGoogleForm() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please paste a Google Form link first!',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _isSuccess = false;
      _syncedQuestions = [];
    });

    try {
      final expandedLink = await _expandShortFormLink(link);
      var formId = _extractFormId(expandedLink);
      if (formId == null) {
        throw Exception(
          'Invalid Google Form link. Paste the full URL (or use Open in Google Forms → copy address bar).',
        );
      }
      debugPrint('Google Form: expanded link → $expandedLink');
      debugPrint('Google Form: extracted formId → $formId');

      final googleSignIn = GoogleSignIn(
        scopes: ['https://www.googleapis.com/auth/forms.body.readonly'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        throw Exception('Google sign-in was cancelled.');
      }
      final auth = await account.authentication;
      final accessToken = auth.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Failed to get Google access token.');
      }

      Future<http.Response> tryFetch(String id) =>
          _getFormWithToken(id, accessToken);

      var response = await tryFetch(formId);
      if (response.statusCode == 404) {
        debugPrint(
          'Google Form: 404 for $formId, trying alternate IDs from public page…',
        );
        final alternates = await _discoverFormIdsFromPublicPage(formId);
        for (final alt in alternates) {
          if (alt == formId) continue;
          final r = await tryFetch(alt);
          if (r.statusCode == 200) {
            formId = alt;
            response = r;
            debugPrint('Google Form: success with alternate id → $formId');
            break;
          }
        }
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Google Forms API Error: ${response.statusCode} ${response.body}',
        );
      }

      final formData = Map<String, dynamic>.from(
        (jsonDecode(response.body) as Map<String, dynamic>),
      );

      final mapped = _mapQuestionsFromForm(formData);
      if (mapped.isEmpty) {
        throw Exception('No question items found in this Google Form.');
      }
      final formTitle = _extractFormTitle(formData);

      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _isSuccess = true;
        _syncedQuestions = mapped;
        _importedExamTitle = formTitle;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully synced Google Form (${_syncedQuestions.length} questions)!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Google Form import error: $e');
      if (!mounted) return;
      String message = 'Failed to import Google Form: $e';
      if (e is PlatformException) {
        final lower = '${e.code} ${e.message ?? ''}'.toLowerCase();
        if (lower.contains('sign_in_failed') ||
            lower.contains('developer_error') ||
            lower.contains('10')) {
          message =
              'Google Sign-In config error (DEVELOPER_ERROR).\n'
              'Check package name, SHA-1, OAuth Android client, and test user.';
        } else if (lower.contains('network_error')) {
          message =
              'Network error while signing in to Google. Please try again.';
        }
      } else {
        final err = e.toString();
        if (err.contains('Google Forms API Error: 404')) {
          message =
              'Form not found (404). Open the form in Google Forms (Edit), '
              'copy the URL that ends with …/edit (…/forms/d/YOUR_ID/edit), paste that here, '
              'and sign in with the same Google account that owns the form.';
        } else if (err.contains('Google Forms API Error: 403')) {
          message =
              'No permission to read this form. Sign in with the account that created it, or get edit access.';
        }
      }
      setState(() {
        _isConnecting = false;
        _isSuccess = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
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
                  'Import Google Form',
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
              // Header Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F66D0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.link, color: Color(0xFF2F66D0), size: 32),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Securely link your Google Form. ExamGuard will instantly grab your multiple-choice questions & answers.',
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

              const SizedBox(height: 32),

              // Paste Link Box
              const Text(
                'Google Form Link',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _linkController,
                enabled: !_isConnecting && !_isSuccess,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.insert_link),
                  hintText: 'https://docs.google.com/forms/...',
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
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notice: Paste the full Google Form URL format like this:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'https://docs.google.com/forms/d/1av6wBm7VqpJPlPVHnAVk_zmflCu2Lf3Cdvi2v0TnHzg/edit?usp=forms_home&ouid=101260999615741390022&ths=true',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade900,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              if (_isConnecting)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2F66D0)),
                    SizedBox(height: 16),
                    Text(
                      'Connecting to Google servers...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else if (_isSuccess)
                const Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 80),
                    SizedBox(height: 16),
                    Text(
                      'Form Synced Successfully!',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _importGoogleForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F66D0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Connect & Import',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              if (_isSuccess)
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewQuestionsScreen(
                            extractedQuestions: _syncedQuestions,
                            initialExamTitle: _importedExamTitle,
                            isGoogleFormMode: true,
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
