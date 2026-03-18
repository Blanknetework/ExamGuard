import 'package:flutter/material.dart';

class ImportGoogleFormScreen extends StatefulWidget {
  const ImportGoogleFormScreen({super.key});

  @override
  State<ImportGoogleFormScreen> createState() => _ImportGoogleFormScreenState();
}

class _ImportGoogleFormScreenState extends State<ImportGoogleFormScreen> {
  final TextEditingController _linkController = TextEditingController();
  bool _isConnecting = false;
  bool _isSuccess = false;

  void _simulateSync() async {
    if (_linkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please paste a Google Form link first!', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _isSuccess = false;
    });

    // Simulate API connection
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isConnecting = false;
        _isSuccess = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Successfully synced Google Form!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
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
                    borderSide: const BorderSide(color: Color(0xFF2F66D0), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
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
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
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
                    onPressed: _simulateSync,
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
                      // Navigate to exam editor or success view
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
