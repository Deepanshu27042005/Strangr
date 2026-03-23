import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';
import '../models/message_model.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtime = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _roomsCollection => _firestore.collection('chat_rooms');

  // Username Logic
  Future<bool> isUsernameAvailable(String username) async {
    final query = await _usersCollection.where('username', isEqualTo: username).get();
    return query.docs.isEmpty;
  }

  Future<void> saveUsername(String userId, String username) async {
    await _usersCollection.doc(userId).set({
      'username': username,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  Future<String?> getLocalUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  Future<void> updateUserStatus(String userId, String status) async {
    await _usersCollection.doc(userId).update({
      'status': status,
      'isMatched': false,
      'currentRoomId': null,
    });
  }

  Future<void> updateUserPreferences(String userId, {
    required String mood,
    required List<String> tags,
    required String chatType,
  }) async {
    await _usersCollection.doc(userId).update({
      'status': mood,
      'tags': tags,
      'chatType': chatType,
      'isMatched': false,
      'currentRoomId': null,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> findMatch(String userId, {
    required String mood,
    required List<String> tags,
    required String chatType,
  }) async {
    // 1. Group Chat Specific Logic
    if (chatType == 'Group Chat') {
      final existingRooms = await _roomsCollection
          .where('chatType', isEqualTo: 'Group Chat')
          .where('mood', isEqualTo: mood)
          .where('isActive', isEqualTo: true)
          .get();

      for (var roomDoc in existingRooms.docs) {
        List userIds = List.from(roomDoc['userIds'] ?? []);
        if (userIds.length < 5) { // Room has space
          String roomId = roomDoc.id;
          await _roomsCollection.doc(roomId).update({
            'userIds': FieldValue.arrayUnion([userId])
          });
          await _usersCollection.doc(userId).update({
            'isMatched': true,
            'currentRoomId': roomId
          });
          return;
        }
      }
    }

    // 2. Regular Matchmaking Logic
    Query query = _usersCollection
        .where('status', isEqualTo: mood)
        .where('chatType', isEqualTo: chatType)
        .where('isMatched', isEqualTo: false)
        .where(FieldPath.documentId, isNotEqualTo: userId);

    if (tags.isNotEmpty && !tags.contains('Anyone')) {
      query = query.where('tags', arrayContainsAny: tags);
    }

    // For Group, we start with whatever is available (up to 4 partners)
    // For 1v1, we need exactly 1 partner.
    int limit = chatType == 'Group Chat' ? 4 : 1;
    QuerySnapshot snapshot = await query.orderBy(FieldPath.documentId).limit(limit).get();

    if (snapshot.docs.isNotEmpty) {
      List<String> partners = snapshot.docs.map((doc) => doc.id).toList();
      String roomId = const Uuid().v4();
      List<String> allUsers = [userId, ...partners];

      await _roomsCollection.doc(roomId).set({
        'userIds': allUsers,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'chatType': chatType,
        'mood': mood,
      });

      WriteBatch batch = _firestore.batch();
      for (String id in allUsers) {
        batch.update(_usersCollection.doc(id), {
          'isMatched': true,
          'currentRoomId': roomId
        });
      }
      await batch.commit();
    }
  }

  DatabaseReference _messagesRef(String roomId) => _realtime.ref().child('chat_rooms').child(roomId).child('messages');
  DatabaseReference _typingRef(String roomId) => _realtime.ref().child('chat_rooms').child(roomId).child('typing');

  Stream<DatabaseEvent> getMessagesStream(String roomId) => _messagesRef(roomId).orderByChild('timestamp').onValue;
  Stream<DatabaseEvent> getTypingStream(String roomId) => _typingRef(roomId).onValue;

  Future<void> updateTypingStatus(String roomId, String userId, String status) async {
    await _typingRef(roomId).child(userId).set(status);
  }

  Future<void> sendMessage(String roomId, MessageModel message) async {
    await _messagesRef(roomId).push().set(message.toMap());
  }

  Future<String> uploadImage(dynamic fileData) async {
    String fileName = const Uuid().v4();
    Reference ref = _storage.ref().child('chat_images').child('$fileName.jpg');
    UploadTask uploadTask = kIsWeb ? ref.putData(fileData) : ref.putFile(fileData as File);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> reportUser(String reportedUserId) async {
    await _usersCollection.doc(reportedUserId).update({
      'reportCount': FieldValue.increment(1)
    });
  }

  Future<void> endSession(String roomId, List<String> userIds) async {
    DocumentSnapshot room = await _roomsCollection.doc(roomId).get();
    if (!room.exists) return;

    String chatType = room['chatType'] ?? '1v1';
    List roomUserIds = List.from(room['userIds'] ?? []);

    if (chatType == 'Group Chat' && roomUserIds.length > 1) {
      // Just leave the group room
      await _roomsCollection.doc(roomId).update({
        'userIds': FieldValue.arrayRemove(userIds)
      });

      WriteBatch batch = _firestore.batch();
      for (String id in userIds) {
        batch.update(_usersCollection.doc(id), {
          'isMatched': false,
          'currentRoomId': null,
          'status': null,
        });
      }
      await batch.commit();
    } else {
      // 1v1 or the last person leaving a group
      await _roomsCollection.doc(roomId).update({'isActive': false});
      WriteBatch batch = _firestore.batch();
      for (String id in roomUserIds) {
        batch.update(_usersCollection.doc(id), {
          'isMatched': false,
          'currentRoomId': null,
          'status': null,
        });
      }
      await batch.commit();
      // Clean up realtime DB
      await _realtime.ref().child('chat_rooms').child(roomId).remove();
    }
  }

  Stream<DocumentSnapshot> getUserStream(String userId) => _usersCollection.doc(userId).snapshots();
  Stream<DocumentSnapshot> getRoomStream(String roomId) => _roomsCollection.doc(roomId).snapshots();
}
