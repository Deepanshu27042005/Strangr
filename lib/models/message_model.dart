enum MessageType { text, image, game }

class MessageModel {
  final String senderId;
  final String? senderName;
  final String message;
  final int timestamp;
  final MessageType type;
  final String? imageUrl;

  MessageModel({
    required this.senderId,
    this.senderName,
    required this.message,
    required this.timestamp,
    this.type = MessageType.text,
    this.imageUrl,
  });

  factory MessageModel.fromMap(Map<dynamic, dynamic> map) {
    return MessageModel(
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'],
      message: map['message'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': timestamp,
      'type': type.name,
      'imageUrl': imageUrl,
    };
  }
}
