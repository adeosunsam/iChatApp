import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ichat_app/allConstants/constants.dart';
import 'package:ichat_app/allModel/message_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatProvider {
  final FirebaseStorage firebaseStorage;
  final FirebaseFirestore firebaseFirestore;
  final SharedPreferences prefs;

  ChatProvider({
    required this.firebaseStorage,
    required this.firebaseFirestore,
    required this.prefs,
  });

  UploadTask uploadFile(File image, String filename) {
    Reference reference = firebaseStorage.ref().child(filename);
    UploadTask uploadTask = reference.putFile(image);
    return uploadTask;
  }

  Future<void> updateDataFireStore(
    String collectionPath,
    String path,
    Map<String, String?> dataNeedUpdate,
  ) {
    return firebaseFirestore
        .collection(collectionPath)
        .doc(path)
        .update(dataNeedUpdate);
  }

  Stream<QuerySnapshot> getStreamChat(
    String groupChatId,
    int limit,
  ) {
    return firebaseFirestore
        .collection(FirestoreConstants.pathMessageCollection)
        .doc(groupChatId)
        .collection(groupChatId)
        .orderBy(FirestoreConstants.timestamp, descending: true)
        .limit(limit)
        .snapshots();
  }

  void sendMessage(String content, int type, String groupChatId,
      String currentUserId, String peerId) {
    DocumentReference documentReference = firebaseFirestore
        .collection(FirestoreConstants.pathMessageCollection)
        .doc(groupChatId)
        .collection(groupChatId)
        .doc(DateTime.now().millisecondsSinceEpoch.toString());

    MessageChat messageChat = MessageChat(
      idFrom: currentUserId,
      idTo: peerId,
      timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: type,
    );

    FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.set(documentReference, messageChat.toJson());
    });
  }
}

class TypeMessage {
  static const text = 0;
  static const image = 1;
  static const sticker = 2;
}
