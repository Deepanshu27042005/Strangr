import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/message_model.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final String roomId;

  const ChatScreen({super.key, required this.roomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DateTime? _lastKeystroke;
  bool _isGroup = false;
  String _currentMood = 'Chill';
  bool _isUploading = false;
  String? _username;

  final List<String> _games = ['Rapid Q&A', 'Would You Rather', 'Truth Question'];
  final Map<String, List<String>> _gameQuestions = {
    'Rapid Q&A': ['Favorite movie?', 'Cats or Dogs?', 'Coffee or Tea?', 'Your dream job?'],
    'Would You Rather': ['Fly or teleport?', 'Be invisible or read minds?', 'Always be late or always be early?'],
    'Truth Question': ['What is your biggest fear?', 'Most embarrassing moment?', 'Secret crush?'],
  };

  @override
  void initState() {
    super.initState();
    _loadRoomData();
    _loadUsername();
  }

  void _loadUsername() async {
    final db = context.read<DatabaseService>();
    final name = await db.getLocalUsername();
    if (mounted) {
      setState(() => _username = name);
    }
  }

  void _loadRoomData() async {
    final db = context.read<DatabaseService>();
    db.getRoomStream(widget.roomId).listen((doc) {
      if (doc.exists) {
        Map data = doc.data() as Map;
        if (mounted) {
          setState(() {
            _isGroup = data['chatType'] == 'Group Chat';
            _currentMood = data['mood'] ?? 'Chill';
          });
        }
      }
    });
  }

  void _onTyping(String text) {
    final now = DateTime.now();
    String status = 'Typing...';
    if (_lastKeystroke != null) {
      final diff = now.difference(_lastKeystroke!).inMilliseconds;
      if (diff < 150) status = 'Typing fast ⚡';
      else if (diff > 1000) status = 'Thinking 💭';
    }
    _lastKeystroke = now;
    final db = context.read<DatabaseService>();
    final auth = context.read<AuthService>();
    db.updateTypingStatus(widget.roomId, auth.currentUserId!, status);

    Timer(const Duration(seconds: 2), () {
      if (mounted && DateTime.now().difference(_lastKeystroke!).inSeconds >= 2) {
        db.updateTypingStatus(widget.roomId, auth.currentUserId!, '');
      }
    });
  }

  void _endSession() async {
    final db = context.read<DatabaseService>();
    final auth = context.read<AuthService>();
    if (auth.currentUserId != null) {
      // In endSession, the current logic handles both 1v1 and group properly
      await db.endSession(widget.roomId, [auth.currentUserId!]);
    }
  }

  void _showEndChatDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isGroup ? 'Leave Group?' : 'End Chat?'),
        content: Text(_isGroup 
            ? 'Are you sure you want to leave this group?' 
            : 'Are you sure you want to leave this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _endSession();
            },
            child: Text(_isGroup ? 'LEAVE' : 'END', style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();
    final auth = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _showEndChatDialog,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isGroup ? 'Synced Group' : 'Synced Stranger', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Synced as $_currentMood', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videogame_asset_outlined),
            onPressed: () => _showGamesMenu(db, auth),
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
            onPressed: () => db.reportUser('target_user_id'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: _getMoodGradient()),
        child: Column(
          children: [
            _buildTypingIndicator(db, auth),
            if (_isUploading)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: StreamBuilder(
                stream: db.getMessagesStream(widget.roomId),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                    Map map = snapshot.data!.snapshot.value as Map;
                    List<MessageModel> msgs = map.values.map((m) => MessageModel.fromMap(m)).toList();
                    msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                    
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: msgs.length,
                      itemBuilder: (ctx, i) => ChatBubble(
                        message: msgs[i], 
                        isMe: msgs[i].senderId == auth.currentUserId,
                        showSenderName: _isGroup,
                      ),
                    );
                  }
                  return const Center(child: Text('Say hello!'));
                },
              ),
            ),
            _buildMessageInput(db, auth),
          ],
        ),
      ),
    );
  }

  LinearGradient _getMoodGradient() {
    switch (_currentMood) {
      case 'Studying': return LinearGradient(colors: [Colors.blue[900]!, Colors.black], begin: Alignment.topCenter);
      case 'Late Night': return const LinearGradient(colors: [Colors.black, Color(0xFF121212)], begin: Alignment.topCenter);
      case 'Motivation': return LinearGradient(colors: [Colors.orange[900]!, Colors.black], begin: Alignment.topCenter);
      default: return const LinearGradient(colors: [Color(0xFF1A1A1A), Colors.black], begin: Alignment.topCenter);
    }
  }

  Widget _buildTypingIndicator(DatabaseService db, AuthService auth) {
    return StreamBuilder(
      stream: db.getTypingStream(widget.roomId),
      builder: (ctx, snapshot) {
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          Map map = snapshot.data!.snapshot.value as Map;
          String typingUsers = '';
          map.forEach((id, status) {
            if (id != auth.currentUserId && status.toString().isNotEmpty) {
              typingUsers += '$status ';
            }
          });
          if (typingUsers.isEmpty) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            alignment: Alignment.centerLeft,
            child: Text(typingUsers, style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _showGamesMenu(DatabaseService db, AuthService auth) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: _games.map((g) => ListTile(
          title: Text(g),
          onTap: () {
            final questions = _gameQuestions[g]!;
            final q = questions[DateTime.now().millisecond % questions.length];
            db.sendMessage(widget.roomId, MessageModel(
              senderId: auth.currentUserId!,
              senderName: _username,
              message: '[$g] $q',
              timestamp: DateTime.now().millisecondsSinceEpoch,
              type: MessageType.game,
            ));
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }

  Widget _buildMessageInput(DatabaseService db, AuthService auth) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black45,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image_outlined),
            onPressed: _isUploading ? null : () async {
              try {
                final picker = ImagePicker();
                final XFile? xFile = await picker.pickImage(source: ImageSource.gallery);
                
                if (xFile != null) {
                  setState(() => _isUploading = true);
                  
                  String? url;
                  if (kIsWeb) {
                    final bytes = await xFile.readAsBytes();
                    url = await db.uploadImage(bytes);
                  } else {
                    url = await db.uploadImage(File(xFile.path));
                  }

                  if (url != null) {
                    await db.sendMessage(widget.roomId, MessageModel(
                      senderId: auth.currentUserId!,
                      senderName: _username,
                      message: 'Shared an image',
                      imageUrl: url,
                      timestamp: DateTime.now().millisecondsSinceEpoch,
                      type: MessageType.image,
                    ));
                  }
                }
              } catch (e) {
                debugPrint('Upload error: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to upload image: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isUploading = false);
              }
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: _onTyping,
              decoration: InputDecoration(
                hintText: 'Message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              if (_messageController.text.trim().isNotEmpty) {
                db.sendMessage(widget.roomId, MessageModel(
                  senderId: auth.currentUserId!,
                  senderName: _username,
                  message: _messageController.text.trim(),
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ));
                _messageController.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showSenderName;

  const ChatBubble({
    super.key, 
    required this.message, 
    required this.isMe,
    this.showSenderName = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderName && !isMe && message.senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                message.senderName!,
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.type == MessageType.game 
                  ? Colors.amber[900]!.withOpacity(0.3) 
                  : (isMe ? Colors.deepPurple : Colors.grey[900]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.type == MessageType.image && message.imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        message.imageUrl!, 
                        width: 200, 
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            width: 200, 
                            height: 200, 
                            child: Center(child: CircularProgressIndicator())
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            width: 200,
                            height: 100,
                            child: Center(child: Icon(Icons.broken_image, color: Colors.red)),
                          );
                        },
                      ),
                    ),
                  ),
                Text(message.message, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
