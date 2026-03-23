import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String? username;
  final String? status; // mood
  final List<String> tags;
  final String chatType; // '1v1' or 'group'
  final bool isMatched;
  final String? currentRoomId;
  final DateTime? timestamp;
  final int reportCount;

  UserModel({
    required this.userId,
    this.username,
    this.status,
    this.tags = const [],
    this.chatType = '1v1',
    this.isMatched = false,
    this.currentRoomId,
    this.timestamp,
    this.reportCount = 0,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
    if (data == null) return UserModel(userId: doc.id);

    return UserModel(
      userId: doc.id,
      username: data['username'] as String?,
      status: data['status'] as String?,
      tags: List<String>.from(data['tags'] ?? []),
      chatType: data['chatType'] ?? '1v1',
      isMatched: data['isMatched'] ?? false,
      currentRoomId: data['currentRoomId'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      reportCount: data['reportCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'status': status,
      'tags': tags,
      'chatType': chatType,
      'isMatched': isMatched,
      'currentRoomId': currentRoomId,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
      'reportCount': reportCount,
    };
  }
}
