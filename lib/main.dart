import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';
import 'screens/matching_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/username_screen.dart';
import 'models/user_model.dart';
import 'firebase_options.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const StrangerSyncApp());
  } catch (e) {
    debugPrint('Firebase Initialization Error: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Error initializing app: $e'),
        ),
      ),
    ));
  }
}

class StrangerSyncApp extends StatelessWidget {
  const StrangerSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        StreamProvider<UserModel?>(
          create: (context) {
            final auth = context.read<AuthService>();
            return auth.user.map((user) {
              if (user == null) {
                auth.signInAnonymous(); 
                return null;
              }
              return UserModel(userId: user.uid);
            });
          },
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Stranger Sync',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C63FF),
            brightness: Brightness.dark,
            surface: const Color(0xFF0F0F1A),
            primary: const Color(0xFF6C63FF),
          ),
          textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF6C63FF)),
              const SizedBox(height: 24),
              Text(
                'STRANGER SYNC',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: const Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Finding your frequency...',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder(
      stream: context.read<DatabaseService>().getUserStream(user.userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Stream Error: ${snapshot.error}')));
        }
        
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const UsernameScreen();
        }

        final userData = UserModel.fromFirestore(snapshot.data!);

        if (userData.username == null || userData.username!.isEmpty) {
          return const UsernameScreen();
        }

        if (userData.isMatched && userData.currentRoomId != null) {
          return ChatScreen(roomId: userData.currentRoomId!);
        }

        if (userData.status != null && userData.status!.isNotEmpty) {
          return MatchingScreen(status: userData.status!);
        }

        return const HomeScreen();
      },
    );
  }
}
