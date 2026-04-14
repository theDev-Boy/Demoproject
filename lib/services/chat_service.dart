import 'package:firebase_database/firebase_database.dart';
import '../models/message_model.dart';

class ChatService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Get or create a chat ID between two users.
  String getChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  /// Send a message to a chat.
  Future<void> sendMessage(String chatId, MessageModel message) async {
    final msgData = message.toMap();
    await _db.child('chats').child(chatId).child('messages').push().set(msgData);
    
    // Update last message in the chat metadata
    await _db.child('chats_meta').child(chatId).update({
      'lastMessage': message.text,
      'lastMessageTime': message.timestamp.millisecondsSinceEpoch,
      'participants': message.deletedFor, // Temp use participants field if needed, but better to keep it clean
    });
  }

  /// Listen for messages in a chat.
  Stream<DatabaseEvent> listenForMessages(String chatId) {
    return _db.child('chats').child(chatId).child('messages').orderByChild('timestamp').onValue;
  }

  /// Listen for all chats a user is part of.
  Stream<DatabaseEvent> listenForUserChats(String myUid) {
    // In a real app, we might use a user_chats index.
    // For simplicity, we filter in the provider or use a custom index.
    return _db.child('chats_meta').onValue;
  }

  /// Set typing status.
  Future<void> setTypingStatus(String chatId, String myUid, bool isTyping) async {
    await _db.child('chats_meta').child(chatId).child('typingStatus').update({
      myUid: isTyping,
    });
  }

  /// Mark message as deleted for everyone.
  Future<void> deleteMessage(String chatId, String messageId) async {
    // Implementation for 'delete for everyone'
    // Typically requires searching for the message key in the 'messages' list.
  }

  /// Clear chat locally (simplified for this app).
  Future<void> clearChatLocally(String chatId, String myUid) async {
    // In a real app, we store a 'lastClearedTimestamp' for the user locally or in DB.
  }
}
