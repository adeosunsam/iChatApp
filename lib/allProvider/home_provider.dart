import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeProvider {
  final FirebaseFirestore firebaseFirestore;
  final SharedPreferences prefs;

  HomeProvider({
    required this.firebaseFirestore,
    required this.prefs,
  });

  Future<void> updateDataFireStore(
    String collectionPath,
    String path,
    Map<String, String> dataNeedUpdate,
  ) {
    return firebaseFirestore
        .collection(collectionPath)
        .doc(path)
        .update(dataNeedUpdate);
  }
}
