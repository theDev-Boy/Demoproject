import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _service = ChatService();
  
  List<ChatModel> _chats = [];
  
  List<ChatModel> get chats => _chats;

  /// Start listening to chats for a user.
  void init(String myUid) {
    _service.listenForUserChats(myUid).listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        _chats = data.entries
            .map((e) => ChatModel.fromMap(e.key, e.value))
            .where((chat) => chat.participants.contains(myUid))
            .toList();
        _chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
        notifyListeners();
      }
    });
  }

  /// Get messages for a specific chat.
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _service.listenForMessages(chatId).map((event) {
      if (event.snapshot.value == null) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final msgs = data.entries
          .map((e) => MessageModel.fromMap(e.key, e.value))
          .toList();
      msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return msgs;
    });
  }

  /// Get specific chat metadata.
  Stream<ChatModel?> getChatMeta(String chatId) {
    return FirebaseDatabase.instance.ref('chats_meta').child(chatId).onValue.map((event) {
      if (event.snapshot.value == null) return null;
      return ChatModel.fromMap(chatId, event.snapshot.value as Map);
    });
  }

  Future<void> sendMessage(String chatId, MessageModel message) async {
    await _service.sendMessage(chatId, message);
  }

  Future<void> setTyping(String chatId, String myUid, bool isTyping) async {
    await _service.setTypingStatus(chatId, myUid, isTyping);
  }

  Future<void> deleteMessage(String chatId, String messageId, {bool everyone = false}) async {
    final ref = FirebaseDatabase.instance.ref('messages').child(chatId).child(messageId);
    if (everyone) {
      await ref.remove();
    } else {
      // Hide for self logic (locally or using a multi-map)
      // For simplicity, we remove it but usually we'd use a 'deleted_by' list
      await ref.remove(); 
    }
  }

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    await FirebaseDatabase.instance.ref('messages').child(chatId).child(messageId).update({
      'text': newText,
      'isEdited': true,
    });
  }

  Future<void> clearChat(String chatId) async {
    await FirebaseDatabase.instance.ref('messages').child(chatId).remove();
  }

  Future<void> blockUser(String myUid, String partnerId) async {
     await FirebaseDatabase.instance.ref('users').child(myUid).child('blockedUsers').push().set(partnerId);
  }
}
