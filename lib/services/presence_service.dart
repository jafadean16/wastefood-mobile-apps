import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Jalankan listener status online/offline
  void init() {
    WidgetsBinding.instance.addObserver(this);

    // Saat user login, tandai online
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _updateStatus(true);
      }
    });
  }

  /// Update status online/offline di Firestore
  Future<void> _updateStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Coba update di "users" dulu, kalau gak ada, baru "toko"
    final userRef = _firestore.collection('users').doc(user.uid);
    final tokoRef = _firestore.collection('toko').doc(user.uid);

    try {
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        await userRef.set({
          'isOnline': isOnline,
          'lastSeen': DateTime.now(),
        }, SetOptions(merge: true));
      } else {
        await tokoRef.set({
          'isOnline': isOnline,
          'lastSeen': DateTime.now(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // optional: print debug log
      debugPrint('Gagal update status online: $e');
    }
  }

  /// Jalankan otomatis saat lifecycle berubah
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_auth.currentUser == null) return;

    if (state == AppLifecycleState.resumed) {
      _updateStatus(true); // aktif lagi
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _updateStatus(false); // keluar / minimize
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
