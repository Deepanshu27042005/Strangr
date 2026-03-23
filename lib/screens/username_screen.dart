import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorText;

  final List<String> _prefixes = ['Chill', 'Cool', 'Night', 'Zen', 'Cyber', 'Urban', 'Wild', 'Swift'];
  final List<String> _suffixes = ['Soul', 'Coder', 'Ghost', 'Seeker', 'Sync', 'Flow', 'Nova', 'Echo'];

  void _generateRandom() {
    final random = Random();
    final prefix = _prefixes[random.nextInt(_prefixes.length)];
    final suffix = _suffixes[random.nextInt(_suffixes.length)];
    final number = random.nextInt(999);
    setState(() {
      _controller.text = '$prefix$suffix$number';
      _errorText = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final db = context.read<DatabaseService>();
    final auth = context.read<AuthService>();
    final username = _controller.text.trim();

    try {
      final isAvailable = await db.isUsernameAvailable(username);
      if (!isAvailable) {
        setState(() => _errorText = 'Username already taken');
        return;
      }

      await db.saveUsername(auth.currentUserId!, username);
      // Wrapper will automatically navigate based on Firestore stream
    } catch (e) {
      setState(() => _errorText = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.face_retouching_natural_rounded, size: 80, color: Color(0xFF6C63FF)),
                const SizedBox(height: 32),
                Text(
                  'Choose your identity',
                  style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Stay anonymous, but pick a name',
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _controller,
                  maxLength: 15,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Enter username',
                    errorText: _errorText,
                    filled: true,
                    fillColor: const Color(0xFF1E1E2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF6C63FF)),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Please enter a name';
                    if (value.length < 3) return 'Too short (min 3 chars)';
                    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) return 'Only letters & numbers allowed';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _generateRandom,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('GENERATE RANDOM'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor: const Color(0xFF6C63FF).withOpacity(0.5),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('CONTINUE', style: TextStyle(letterSpacing: 2, fontSize: 18, fontWeight: FontWeight.bold)),
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
