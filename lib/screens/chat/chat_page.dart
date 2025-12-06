import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wastefood/services/firestore_service.dart';

class ChatPage extends StatefulWidget {
  final String userId;
  final String tokoId;

  const ChatPage({super.key, required this.userId, required this.tokoId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _firestoreService = FirestoreService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final senderId = FirebaseAuth.instance.currentUser!.uid;

  String tokoNama = '';
  String? chatId;
  CollectionReference<Map<String, dynamic>>? messagesRef;

  @override
  void initState() {
    super.initState();
    _setupChat();
  }

  Future<void> _setupChat() async {
    chatId = _firestoreService.generateChatId(widget.userId, widget.tokoId);
    messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages');
    await _fetchTokoNama();
    if (mounted) setState(() {});
  }

  Future<void> _fetchTokoNama() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      if (currentUserId == widget.userId) {
        final tokoDoc =
            await FirebaseFirestore.instance
                .collection('toko')
                .doc(widget.tokoId)
                .get();
        setState(() {
          tokoNama = tokoDoc.data()?['nama'] ?? 'Toko tidak ditemukan';
        });
      } else if (currentUserId == widget.tokoId) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .get();
        setState(() {
          tokoNama = userDoc.data()?['name'] ?? 'Pengguna tidak ditemukan';
        });
      } else {
        tokoNama = 'Chat tidak valid';
      }
    } catch (e) {
      tokoNama = 'Gagal memuat nama';
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || chatId == null) return;

    await _firestoreService.sendMessage(
      userId: widget.userId,
      tokoId: widget.tokoId,
      senderId: senderId,
      message: text,
    );

    _controller.clear();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (messagesRef == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.store, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tokoNama.isNotEmpty ? tokoNama : "Memuat...",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                StreamBuilder<DocumentSnapshot>(
                  // 🔹 ambil presence real-time dari users / toko
                  stream:
                      FirebaseFirestore.instance
                          .collection(
                            FirebaseAuth.instance.currentUser!.uid ==
                                    widget.userId
                                ? 'toko'
                                : 'users',
                          )
                          .doc(
                            FirebaseAuth.instance.currentUser!.uid ==
                                    widget.userId
                                ? widget.tokoId
                                : widget.userId,
                          )
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Text(
                        "Memuat status...",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      );
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    final isOnline = data?['isOnline'] ?? false;
                    final lastSeen =
                        data?['lastSeen'] != null
                            ? (data!['lastSeen'] as Timestamp).toDate()
                            : null;

                    String statusText;
                    if (isOnline) {
                      statusText = "Online sekarang";
                    } else if (lastSeen != null) {
                      final difference =
                          DateTime.now().difference(lastSeen).inMinutes;
                      if (difference < 1) {
                        statusText = "Baru saja offline";
                      } else if (difference < 60) {
                        statusText = "Terakhir terlihat $difference menit lalu";
                      } else {
                        final hours = difference ~/ 60;
                        statusText = "Terakhir terlihat $hours jam lalu";
                      }
                    } else {
                      statusText = "Offline";
                    }

                    return Text(
                      statusText,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              key: ValueKey(chatId),
              stream:
                  messagesRef!
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Belum ada pesan",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data();
                    final isMe = msg['senderId'] == senderId;
                    final message = msg['message'] ?? '';

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient:
                              isMe
                                  ? const LinearGradient(
                                    colors: [
                                      Color(0xFF43A047),
                                      Color(0xFF66BB6A),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                  : const LinearGradient(
                                    colors: [Colors.white, Color(0xfff0f0f0)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Chat Input (modern floating bar)
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: "Ketik pesan...",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      onTap:
                          () => Future.delayed(
                            const Duration(milliseconds: 300),
                            () => _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent,
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _sendMessage,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
                        ),
                      ),
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
