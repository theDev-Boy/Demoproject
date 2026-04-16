import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/local_db_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _service = ChatService();
  
  List<ChatModel> _chats = [];
  String _myUid = '';
  
  List<ChatModel> get chats => _chats;

  /// Start listening to chats for a user.
  void init(String myUid) {
    _myUid = myUid;
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
  Stream<List<MessageModel>> getMessages(String chatId) async* {
    final clearedAt = await LocalDbService().getChatClearedAt(chatId);
    yield* _service.listenForMessages(chatId).map((event) {
      if (event.snapshot.value == null) return <MessageModel>[];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final msgs = data.entries
          .map((e) => MessageModel.fromMap(e.key, e.value))
          // Only show messages that arrived after it was cleared locally
          .where((m) => m.timestamp.millisecondsSinceEpoch > clearedAt)
          // Hide messages deleted locally for this user
          .where((m) => _myUid.isNotEmpty && !m.deletedFor.contains(_myUid))
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
    final ref = FirebaseDatabase.instance.ref('chats').child(chatId).child('messages').child(messageId);
    if (everyone) {
      await ref.remove();
    } else {
      if (_myUid.isNotEmpty) {
        final snap = await ref.child('deletedFor').get();
        List<String> current = [];
        if (snap.exists && snap.value != null) {
          current = (snap.value as Object) is List
            ? (snap.value as List).map((e) => e.toString()).toList()
            : [];
        }
        if (!current.contains(_myUid)) {
          current.add(_myUid);
          await ref.child('deletedFor').set(current);
        }
      }
    }
  }

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    await FirebaseDatabase.instance.ref('chats').child(chatId).child('messages').child(messageId).update({
      'text': newText,
      'isEdited': true,
    });
  }

  Future<void> clearChat(String chatId) async {
    await LocalDbService().clearChatLocally(chatId);
    notifyListeners();
  }

  Future<void> blockUser(String myUid, String partnerId) async {
     await FirebaseDatabase.instance.ref('users').child(myUid).child('blockedUsers').push().set(partnerId);
  }
}
