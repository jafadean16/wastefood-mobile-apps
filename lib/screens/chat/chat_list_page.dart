import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wastefood/services/firestore_service.dart';
import 'chat_page.dart';

class ChatListPage extends StatelessWidget {
  ChatListPage({super.key});

  final _firestoreService = FirestoreService();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  Future<String> _getNamaLawan(String lawanId) async {
    // 🔍 cek di 'users'
    final userSnap =
        await FirebaseFirestore.instance.collection('users').doc(lawanId).get();
    if (userSnap.exists) {
      final data = userSnap.data() ?? {};
      final nama =
          data['nama'] ??
          data['displayName'] ??
          data['username'] ??
          data['name'];
      if (nama != null && nama.toString().trim().isNotEmpty) return nama;
    }

    // 🔍 cek di 'toko'
    final tokoSnap =
        await FirebaseFirestore.instance.collection('toko').doc(lawanId).get();
    if (tokoSnap.exists) {
      final data = tokoSnap.data() ?? {};
      final nama = data['nama'] ?? data['nama_toko'] ?? data['name'];
      if (nama != null && nama.toString().trim().isNotEmpty) return nama;
    }

    // 🔁 fallback
    return "Pengguna";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Pesan Anda"),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getUserChats(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data ?? [];
          if (chats.isEmpty) {
            return const Center(
              child: Text(
                "Belum ada percakapan.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final userId = chat['userId'];
              final tokoId = chat['tokoId'];
              final lawanId =
                  (currentUserId == userId) ? tokoId : userId; // auto detect
              final lastMessage = chat['lastMessage'] ?? '';
              final timestamp = chat['lastTimestamp'];

              String time = '';
              if (timestamp is Timestamp) {
                final date = timestamp.toDate().toLocal();
                time =
                    "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
              }

              return FutureBuilder<String>(
                future: _getNamaLawan(lawanId),
                builder: (context, userSnap) {
                  final namaLawan =
                      userSnap.data ??
                      (currentUserId == userId ? "Toko" : "Pengguna");

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ChatPage(userId: userId, tokoId: tokoId),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade400,
                                  Colors.green.shade700,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person, color: Colors.green),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  namaLawan,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastMessage.isNotEmpty
                                      ? lastMessage
                                      : "(Belum ada pesan)",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
