import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedMood = 'Chill';
  String _selectedChatType = '1v1';
  final List<String> _selectedTags = [];

  final List<Map<String, dynamic>> _moods = [
    {'title': 'Studying', 'icon': Icons.menu_book_rounded, 'color': const Color(0xFF4A90E2)},
    {'title': 'Chill', 'icon': Icons.local_cafe_rounded, 'color': const Color(0xFF50E3C2)},
    {'title': 'Motivation', 'icon': Icons.auto_awesome_rounded, 'color': const Color(0xFFF5A623)},
    {'title': 'Late Night', 'icon': Icons.nights_stay_rounded, 'color': const Color(0xFF9013FE)},
    {'title': 'Bored', 'icon': Icons.sentiment_dissatisfied_rounded, 'color': const Color(0xFF7ED321)},
    {'title': 'Stressed', 'icon': Icons.psychology_rounded, 'color': const Color(0xFFFF9500)},
    {'title': 'Feeling Low', 'icon': Icons.sentiment_very_dissatisfied_rounded, 'color': const Color(0xFFD0021B)},
    {'title': 'Need Help', 'icon': Icons.support_rounded, 'color': const Color(0xFFFF5252)},
  ];

  final List<String> _tags = [
    'Anyone', 'College Students', 'Gamers', 'Movie Buffs', 'Music Lovers', 'Artists', 'Writers', 'Entrepreneurs', 'Developers', 'Designers', 'Travellers', 'Foodies'
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final db = context.read<DatabaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: Text(
          'STRANGER SYNC',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 20,
            color: const Color(0xFF6C63FF),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            onPressed: () => auth.signOut(),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select your vibe',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Match with people on the same frequency.',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            
            const SizedBox(height: 40),
            
            // Mood Selection
            _buildSectionHeader('Current Mood'),
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: _moods.length,
                itemBuilder: (ctx, i) {
                  final mood = _moods[i];
                  bool isSelected = _selectedMood == mood['title'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMood = mood['title']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 100,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? mood['color'].withOpacity(0.15) : const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected ? mood['color'] : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(color: mood['color'].withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                        ] : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(mood['icon'], color: isSelected ? mood['color'] : Colors.grey[400], size: 32),
                          const SizedBox(height: 10),
                          Text(
                            mood['title'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Tags Selection
            _buildSectionHeader('Whom do you want to talk to?'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _tags.map((tag) {
                bool isSelected = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) _selectedTags.remove(tag);
                      else _selectedTags.add(tag);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF2E2E3E),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),
            
            // Chat Type
            _buildSectionHeader('Chat Type'),
            const SizedBox(height: 16),
            Row(
              children: ['1v1', 'Group Chat'].map((type) {
                bool isSelected = _selectedChatType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedChatType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: type == '1v1' ? 12 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF6C63FF).withOpacity(0.1) : const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF2E2E3E),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        type,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 48),
            
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: () async {
                  final userId = auth.currentUserId;
                  if (userId != null) {
                    await db.updateUserPreferences(
                      userId,
                      mood: _selectedMood,
                      tags: _selectedTags.isEmpty ? ['Anyone'] : _selectedTags,
                      chatType: _selectedChatType,
                    );
                    await db.findMatch(
                      userId,
                      mood: _selectedMood,
                      tags: _selectedTags.isEmpty ? ['Anyone'] : _selectedTags,
                      chatType: _selectedChatType,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  shadowColor: const Color(0xFF6C63FF).withOpacity(0.5),
                  elevation: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('SYNC NOW', style: TextStyle(letterSpacing: 2, fontSize: 18)),
                    const SizedBox(width: 12),
                    const Icon(Icons.bolt_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.spaceGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        color: const Color(0xFF6C63FF),
      ),
    );
  }
}
