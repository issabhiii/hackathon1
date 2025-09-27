import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../app/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoginMode = true;
  bool _loading = false;

  final _nameController = TextEditingController(); // used on Sign Up
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ---------- AUTH: LOGIN ----------
  Future<void> _login() async {
    final supabase = Supabase.instance.client;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Please enter both email and password");
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final authUser = res.user;
      if (authUser == null) {
        _showError("Invalid credentials");
        return;
      }

      final authId = authUser.id; // UUID from Supabase Auth

      // Try to get profile by PK (UUID)
      final row = await supabase
          .from('users')
          .select('user')
          .eq('id', authId)
          .maybeSingle();

      String userName;
      if (row == null) {
        // No profile row yet → create one with the Auth UUID as PK
        userName = _emailPrefix(email);
        await supabase.from('users').upsert({
          'id': authId, // <-- REQUIRED for UUID PK schema
          'email': email,
          'user': userName,
          'clearance': 'uncleared',
          'last_logged': DateTime.now().toIso8601String(),
        });
      } else {
        userName = (row['user'] as String?)?.trim().isNotEmpty == true
            ? row['user'] as String
            : _emailPrefix(email);
        // Update last_logged on login
        await supabase
            .from('users')
            .update({'last_logged': DateTime.now().toIso8601String()})
            .eq('id', authId);
      }

      if (mounted) {
        // ✅ mark app as logged in + store display name
        context.read<AppState>().setDisplayName(userName);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Welcome back, $userName!")));
        Navigator.pop(context, userName); // send name back to HomePage
      }
    } on AuthApiException catch (e) {
      _showError(e.message); // cleaner auth errors
    } catch (e) {
      _showError("Login failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- AUTH: SIGN UP ----------
  Future<void> _signup() async {
    final supabase = Supabase.instance.client;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError("Please fill name, email and password");
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await supabase.auth.signUp(email: email, password: password);

      // Use auth user UUID as PK in `public.users`
      final authId = res.user?.id;
      if (authId == null) {
        _showError("No user from auth");
        return;
      }

      await supabase.from('users').upsert({
        'id': authId, // <-- required for UUID PK
        'email': email,
        'user': name,
        'clearance': 'uncleared',
        'last_logged': DateTime.now().toIso8601String(),
      });

      if (res.session != null) {
        // Email confirmations disabled → user is signed in immediately
        if (mounted) {
          // ✅ mark app as logged in + store display name
          context.read<AppState>().setDisplayName(name);

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Welcome, $name!")));
          Navigator.pop(context, name);
        }
      } else {
        // Confirmations enabled → prompt to verify and then log in
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Account created! Check your email to verify, then log in.",
              ),
            ),
          );
          setState(() => isLoginMode = true);
        }
      }
    } on AuthApiException catch (e) {
      if (e.code == 'user_already_exists') {
        _showError("That email is already registered. Try logging in.");
      } else {
        _showError(e.message);
      }
    } catch (e) {
      _showError("Sign up failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF005EB8);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, Colors.blue.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Icon(
                    Icons.verified_user,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isLoginMode ? "Login" : "Sign Up",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (!isLoginMode)
                    _buildTextField(
                      Icons.person,
                      "Full name",
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                    ),

                  _buildTextField(
                    Icons.email,
                    "Email",
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: isLoginMode
                        ? TextInputAction.done
                        : TextInputAction.next,
                  ),
                  _buildTextField(
                    Icons.lock,
                    "Password",
                    controller: _passwordController,
                    isObscure: true,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            if (isLoginMode) {
                              await _login();
                            } else {
                              await _signup();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isLoginMode ? "Login" : "Sign Up",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),

                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => setState(() => isLoginMode = !isLoginMode),
                    child: Text(
                      isLoginMode
                          ? "Don't have an account? Sign Up"
                          : "Already have an account? Login",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    IconData icon,
    String hint, {
    bool isObscure = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _emailPrefix(String email) {
    final ix = email.indexOf('@');
    return ix > 0 ? email.substring(0, ix) : email;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
