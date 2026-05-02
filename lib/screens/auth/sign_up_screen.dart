import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:email_otp/email_otp.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:examapp/screens/auth/login_screen.dart';
import 'package:examapp/screens/student/student_dashboard.dart';
import 'package:examapp/screens/examiner/examiner_dashboard.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _rePasswordController = TextEditingController();

  String? _selectedRole;
  bool _obscurePassword = true;
  bool _obscureRePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _rePasswordController.dispose();
    super.dispose();
  }

  Future<void> _setupEmailOTP() async {
    EmailOTP.config(
      appName: 'ExamGuard',
      otpType: OTPType.numeric,
      emailTheme: EmailTheme.v1,
    );

    // Attempt to load SMTP from .env
    final smtpEmail = dotenv.env['SMTP_EMAIL'];
    final smtpPassword = dotenv.env['SMTP_PASSWORD'];

    if (smtpEmail != null &&
        smtpEmail.isNotEmpty &&
        smtpPassword != null &&
        smtpPassword.isNotEmpty) {
      EmailOTP.setSMTP(
        host: 'smtp.gmail.com',
        emailPort: EmailPort.port587,
        secureType: SecureType.tls,
        password: smtpPassword,
        username: smtpEmail,
      );
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedRole == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a role')));
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        await _setupEmailOTP();

        String email = _emailController.text.trim().toLowerCase();
        bool isSent = await EmailOTP.sendOTP(email: email);

        setState(() {
          _isLoading = false;
        });

        if (isSent) {
          _showOTPDialog(
            email,
            _passwordController.text,
            _nameController.text.trim(),
            _selectedRole!,
            null, // Not google auth
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to send OTP. If using Gmail, ensure SMTP_EMAIL and SMTP_PASSWORD are set in .env.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending OTP: $e')));
      }
    }
  }

  Future<void> _showOTPDialog(
    String email,
    String password,
    String name,
    String role,
    AuthCredential? googleCredential,
  ) async {
    final TextEditingController otpController = TextEditingController();
    bool isVerifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Email Verification',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'An OTP has been sent to $email. Please enter it below to verify your account.',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter OTP',
                      prefixIcon: const Icon(Icons.security),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () {
                          if (googleCredential != null) {
                            GoogleSignIn().signOut();
                          }
                          Navigator.pop(context);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          setDialogState(() => isVerifying = true);
                          bool isValid = EmailOTP.verifyOTP(
                            otp: otpController.text.trim(),
                          );
                          if (isValid) {
                            Navigator.pop(context); // Close dialog
                            if (googleCredential != null) {
                              _completeGoogleSignUp(
                                googleCredential,
                                email,
                                name,
                                password,
                                role,
                              );
                            } else {
                              _createAccount(email, password, name, role);
                            }
                          } else {
                            setDialogState(() => isVerifying = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invalid OTP. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F66D0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createAccount(
    String email,
    String password,
    String name,
    String role,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'name': name,
            'email': email,
            'role': role,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sign Up Successful!',
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
          duration: const Duration(milliseconds: 1500),
        ),
      );

      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                role == 'Test Taker'
                ? const StudentDashboard()
                : const ExaminerDashboard(),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      String message = 'An error occurred. Please try again.';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _signUpWithGoogle() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a role')));
      return;
    }

    try {
      final googleSignIn = GoogleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) return;

      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      _showGooglePasswordDialog(credential, account);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _showGooglePasswordDialog(
    AuthCredential credential,
    GoogleSignInAccount account,
  ) async {
    final TextEditingController passController = TextEditingController();
    final TextEditingController rePassController = TextEditingController();
    bool isProcessing = false;
    bool obscurePass = true;
    bool obscureRePass = true;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Create a Password',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Please create a password for your account before completing sign up.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passController,
                      obscureText: obscurePass,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePass
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscurePass = !obscurePass),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: rePassController,
                      obscureText: obscureRePass,
                      decoration: InputDecoration(
                        hintText: 'Re-enter Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureRePass
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureRePass = !obscureRePass,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value != passController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () {
                          GoogleSignIn().signOut();
                          Navigator.pop(context);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isProcessing = true);

                            // Now send OTP for google sign up
                            await _setupEmailOTP();
                            String email = account.email.toLowerCase();
                            bool isSent = await EmailOTP.sendOTP(email: email);

                            if (context.mounted && Navigator.canPop(context)) {
                              Navigator.pop(context); // Close password dialog
                            }

                            if (!context.mounted) return;
                            if (isSent) {
                              _showOTPDialog(
                                email,
                                passController.text,
                                account.displayName ?? 'Google User',
                                _selectedRole!,
                                credential,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Failed to send OTP. If using Gmail, ensure SMTP_EMAIL and SMTP_PASSWORD are set in .env.',
                                  ),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F66D0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _completeGoogleSignUp(
    AuthCredential credential,
    String email,
    String name,
    String password,
    String role,
  ) async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      await userCredential.user!.updatePassword(password);

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      String? resolvedRole;
      if (userDoc.exists) {
        resolvedRole = userDoc.get('role');
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'name': name,
              'email': email,
              'role': role,
              'createdAt': FieldValue.serverTimestamp(),
            });
        resolvedRole = role;
      }

      if (resolvedRole != role) {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Role mismatch. That account is not registered as this role.',
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome! Signed in as $resolvedRole.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green.shade600,
        ),
      );

      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                resolvedRole == 'Test Taker'
                ? const StudentDashboard()
                : const ExaminerDashboard(),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Sign-In Failed: ${e.message}'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 1000));
            if (mounted) setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Section
                Container(
                  padding: const EdgeInsets.only(top: 20, bottom: 40),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2F66D0),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Image.asset(
                          'Images/Polygon.png',
                          width: 50,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ExamGuard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Welcome Text
                      const Text(
                        'Welcome New User',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to continue',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),

                      const SizedBox(height: 24),

                      // 3. Form Fields
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Name',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person_outline),
                                hintText: 'Enter your Display Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your display name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'Email or Username',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.email_outlined),
                                hintText: 'Enter your email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(value)) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'Password',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                hintText: 'Enter your password',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'Re-Password',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _rePasswordController,
                              obscureText: _obscureRePassword,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureRePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureRePassword = !_obscureRePassword;
                                    });
                                  },
                                ),
                                hintText: 'Re-Enter your password',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please re-enter your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 4. Login Redirect Text
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const LoginScreen(),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0.0, 0.05),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeOutCubic,
                                                ),
                                              ),
                                          child: child,
                                        ),
                                      );
                                    },
                                transitionDuration: const Duration(
                                  milliseconds: 500,
                                ),
                              ),
                            );
                          },
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(text: 'Already have an account? '),
                                TextSpan(
                                  text: 'Log-In Here',
                                  style: TextStyle(
                                    color: Color(0xFF2F66D0),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 5. Role Selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedRole = 'Test Taker';
                                });
                              },
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                opacity:
                                    _selectedRole == null ||
                                        _selectedRole == 'Test Taker'
                                    ? 1.0
                                    : 0.5,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutBack,
                                  scale:
                                      _selectedRole == null ||
                                          _selectedRole == 'Test Taker'
                                      ? 1.0
                                      : 0.85,
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        'Images/tk.png',
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Test Taker',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedRole = 'Examiner';
                                });
                              },
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                opacity:
                                    _selectedRole == null ||
                                        _selectedRole == 'Examiner'
                                    ? 1.0
                                    : 0.5,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutBack,
                                  scale:
                                      _selectedRole == null ||
                                          _selectedRole == 'Examiner'
                                      ? 1.0
                                      : 0.85,
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        'Images/tk.png',
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Examiner',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // 6. Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F66D0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.black87,
                              thickness: 0.5,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.black87,
                              thickness: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _signUpWithGoogle,
                          icon: Image.asset(
                            'Images/google-logo.png',
                            height: 26,
                            width: 26,
                          ),
                          label: const Text(
                            'Sign up with Google',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B9DFD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),

                      const SafeArea(top: false, child: SizedBox(height: 24)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
