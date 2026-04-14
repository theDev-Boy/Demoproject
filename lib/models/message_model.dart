enum MessageType { text, emoji, voice, callEvent }

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final bool isEdited;
  final List<String> deletedFor;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    required this.timestamp,
    this.isEdited = false,
    this.deletedFor = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isEdited': isEdited,
      'deletedFor': deletedFor,
    };
  }

  factory MessageModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      isEdited: map['isEdited'] ?? false,
      deletedFor: List<String>.from(map['deletedFor'] ?? []),
    );
  }
}
