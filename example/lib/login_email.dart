import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_next_auth_core/next_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:next_auth_client_example/session_data.dart';

class EmailLoginPage extends ConsumerStatefulWidget {
  const EmailLoginPage({super.key});

  @override
  ConsumerState<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends ConsumerState<EmailLoginPage> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();

  bool _isLoading = false;
  bool _isVerificationCodeSent = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleSendVerificationCode() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final nextAuthClient = GetIt.instance<NextAuthClient<SessionData>>();
    final ret = await nextAuthClient.signIn(
      'email',
      emailOptions: EmailSignInOptions(
        email: _emailController.text.trim(),
      ),
    );

    setState(() {
      _isLoading = false;
    });

    if (ret.ok) {
      setState(() {
        _isVerificationCodeSent = true;
      });
      _startCountdown();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code sent')),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final errorMessage = ret.error?.toString() ?? 'Send code failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _tokenController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and code')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final nextAuthClient = GetIt.instance<NextAuthClient<SessionData>>();
    final ret = await nextAuthClient.signIn(
      'email',
      emailOptions: EmailSignInOptions(
        email: _emailController.text.trim(),
        token: _tokenController.text.trim(),
      ),
    );

    if (ret.ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final errorMessage = ret.error?.toString() ?? 'Login failed';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Login'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Sign in with email verification code'),
              const SizedBox(height: 24),

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isVerificationCodeSent && !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: (_isLoading || _countdown > 0)
                        ? null 
                        : _handleSendVerificationCode,
                    child: _isLoading && !_isVerificationCodeSent
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _countdown > 0
                                ? 'Resend ($_countdown)'
                                : (_isVerificationCodeSent
                                    ? 'Resend'
                                    : 'Send Code'),
                          ),
                  ),

                  if (_isVerificationCodeSent) ...[
                    const SizedBox(height: 24),
                    TextField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
