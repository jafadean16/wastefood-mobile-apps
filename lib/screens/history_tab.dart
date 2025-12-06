import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:wastefood/services/firestore_service.dart';
import 'dart:async';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Logger _logger = Logger();
  final firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // TIMER AUTO CANCEL
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        final snapshot =
            await FirebaseFirestore.instance
                .collection('pesanan')
                .where('userId', isEqualTo: user.uid)
                .get();

        for (var d in snapshot.docs) {
          final data = d.data();
          final status = (data['status'] ?? '').toString().toLowerCase();
          final waktuOrder = data['waktuOrder'] as Timestamp?;

          if (status == 'menunggu' && waktuOrder != null) {
            final expiredAt = waktuOrder.toDate().add(const Duration(hours: 2));
            if (DateTime.now().isAfter(expiredAt)) {
              await firestoreService.batalkanPesananDanRestoreStok(d.id);
              if (mounted) setState(() {}); // paksa UI rebuild
            }
          }
        }
      } catch (e, st) {
        _logger.e("Auto-cancel error", error: e, stackTrace: st);
      }
    });
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('EEEE, dd MMM yyyy - HH:mm', 'id_ID').format(date);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'berhasil':
        return Colors.green.shade700;
      case 'dibatalkan':
      case 'batal':
        return Colors.red.shade600;
      case 'menunggu':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'berhasil':
        return Icons.check_circle_rounded;
      case 'dibatalkan':
      case 'batal':
        return Icons.cancel_rounded;
      case 'menunggu':
        return Icons.hourglass_bottom_rounded;
      default:
        return Icons.info_outline;
    }
  }

  int _hitungTotal(List<Map<String, dynamic>> items) {
    return items.fold(0, (total, item) {
      final hargaRaw = item['harga'] ?? 0;
      final jumlahRaw = item['jumlah'] ?? 1;
      final harga =
          (hargaRaw is int)
              ? hargaRaw
              : (hargaRaw is double)
              ? hargaRaw.toInt()
              : int.tryParse(hargaRaw.toString()) ?? 0;
      final jumlah =
          (jumlahRaw is int)
              ? jumlahRaw
              : int.tryParse(jumlahRaw.toString()) ?? 1;
      return total + (harga * jumlah);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Silakan login terlebih dahulu."));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6F3),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 3,
          backgroundColor: Colors.green.shade700,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  tabs: const [Tab(text: 'Menunggu'), Tab(text: 'Riwayat')],
                ),
                const SizedBox(height: 1),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('pesanan')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('waktuOrder', descending: true)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              _logger.e("Stream error: ${snapshot.error}");
              return Center(
                child: Text("Terjadi kesalahan: ${snapshot.error}"),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            // Pisahkan list menunggu & riwayat
            final menungguDocs =
                docs.where((d) {
                  final status =
                      ((d.data() as Map)['status'] ?? '')
                          .toString()
                          .toLowerCase();
                  return status == 'menunggu';
                }).toList();

            final riwayatDocs =
                docs.where((d) {
                  final status =
                      ((d.data() as Map)['status'] ?? '')
                          .toString()
                          .toLowerCase();
                  return status == 'berhasil' ||
                      status == 'dibatalkan' ||
                      status == 'batal';
                }).toList();

            return TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildList(context, menungguDocs),
                _buildList(context, riwayatDocs),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<DocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return const Center(
        child: Text(
          "Belum ada pesanan.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final orderId = docs[index].id;
        final status = (data['status'] ?? 'menunggu').toString().toLowerCase();
        final userId = data['userId'] ?? '';

        final waktuOrder = data['waktuOrder'] as Timestamp;
        final items =
            (data['items'] as List<dynamic>? ?? [])
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
        final totalHarga = _hitungTotal(items);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: _getStatusColor(status).withValues(alpha: 0.15),
              child: Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
                size: 26,
              ),
            ),
            title: FutureBuilder<String>(
              future: getUserName(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text(
                    'Pesanan dari ...',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  );
                }

                return Text(
                  'Pesanan dari ${snapshot.data}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),

            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(waktuOrder),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${items.length} item',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Rp${NumberFormat('#,###', 'id_ID').format(totalHarga)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${status[0].toUpperCase()}${status.substring(1)}',
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            onTap: () {
              if (status == 'menunggu') {
                Navigator.pushNamed(
                  context,
                  '/order-detail',
                  arguments: orderId,
                );
              } else if (status == 'berhasil') {
                Navigator.pushNamed(
                  context,
                  '/order-success',
                  arguments: {
                    'orderId': orderId,
                    'totalHarga': totalHarga,
                    'items': items,
                  },
                );
              } else {
                Navigator.pushNamed(
                  context,
                  '/order-canceled',
                  arguments: orderId,
                );
              }
            },
          ),
        );
      },
    );
  }

  Future<String> getUserName(String userId) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    return doc.data()?['name'] ?? 'Customer';
  }
}
