import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseTest {
  static Future<void> testConnection() async {
    await FirebaseFirestore.instance
        .collection('test')
        .doc('connection')
        .set({
      'status': 'connected',
      'timestamp': DateTime.now().toString(),
    });
  }
}