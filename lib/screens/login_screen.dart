import 'package:flutter/material.dart';

/// Pure widget: every Firebase call is injected as a callback (wired by
/// [AuthGate]), so it can be tested without touching Firebase at all —
/// the same convention as [NoteEditorScreen]'s onSave/onPreview.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onSignIn,
    required this.onSignUp,
    required this.onContinueAsGuest,
    required this.onSignInWithGoogle,
    required this.onForgotPassword,
  });

  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function(String email, String password) onSignUp;
  final Future<void> Function() onContinueAsGuest;
  final Future<void> Function() onSignInWithGoogle;
  final Future<void> Function(String email) onForgotPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _readableError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _readableError(Object error) {
    final message = error.toString();
    // AuthService wraps FirebaseAuthException in a plain Exception with a
    // "Exception: ..." prefix; strip it so the UI shows a clean sentence.
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter an email and a password.');
      return;
    }
    _guard(
      () => _isSignUp
          ? widget.onSignUp(email, password)
          : widget.onSignIn(email, password),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
        () => _error = 'Enter your email above, then tap "Forgot password?" again.',
      );
      return;
    }
    await _guard(() => widget.onForgotPassword(email));
    if (!mounted || _error != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password reset email sent to $email.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'NotesSync',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp
                        ? 'Create an account'
                        : 'Sign in to sync your notes',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const ValueKey('login_email_field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('login_password_field'),
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isSubmitting ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? 'Sign up' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() {
                            _isSignUp = !_isSignUp;
                            _error = null;
                          }),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : "Don't have an account? Sign up",
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _guard(widget.onSignInWithGoogle),
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Sign in with Google'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _guard(widget.onContinueAsGuest),
                    child: const Text('Continue without an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
