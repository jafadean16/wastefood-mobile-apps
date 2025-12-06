// lib/screens/order/order_detail_page.dart
import 'dart:ui';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wastefood/screens/home_screen.dart';
import 'package:wastefood/services/firestore_service.dart';
import 'package:wastefood/screens/order/order_success_page.dart';
import 'package:wastefood/screens/order/order_canceled_page.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  // Stream untuk StreamBuilder (UI)
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> orderStream;

  // Subscription terpisah untuk logic (redirect, update _lastStatus)
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderSub;

  // Timer untuk auto-cancel
  Timer? _autoCancelTimer;

  // state flags
  bool _hasRedirected = false;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();

    // inisialisasi stream
    orderStream =
        FirebaseFirestore.instance
            .collection('pesanan')
            .doc(widget.orderId)
            .snapshots();

    // SUBSCRIPTION khusus untuk logic (redirect & update status)
    _orderSub = orderStream.listen((doc) async {
      if (!mounted) return;
      final data = doc.data();
      if (data == null) return;

      final newStatus = (data['status'] ?? 'menunggu').toString().toLowerCase();
      // --- hitung items + total harga + tokoId --- //
      final itemsRawLocal = data['items'] ?? [];
      final List<Map<String, dynamic>> itemsLocal =
          List<Map<String, dynamic>>.from(itemsRawLocal);

      final int totalHargaLocal = itemsLocal.fold<int>(0, (acc, item) {
        final harga =
            (item['harga'] is num)
                ? (item['harga'] as num).toInt()
                : int.tryParse(item['harga'].toString()) ?? 0;

        final qty =
            (item['jumlah'] is num)
                ? (item['jumlah'] as num).toInt()
                : int.tryParse(item['jumlah'].toString()) ?? 1;

        return acc + (harga * qty);
      });

      final tokoIdLocal = (data['tokoId'] ?? data['toko'] ?? '').toString();

      // jika status berubah, simpan _lastStatus
      if (newStatus != _lastStatus) {
        _lastStatus = newStatus;
      }

      // jika status berubah ke berhasil/dibatalkan → redirect sekali
      // redirect jika STATUS tidak lagi 'menunggu' karena auto-cancel atau seller
      if (!_hasRedirected && newStatus != 'menunggu') {
        _hasRedirected = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          // status berhasil
          if (newStatus == 'berhasil') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (_) => OrderSuccessPage(
                      orderId: widget.orderId,
                      totalHarga: totalHargaLocal,
                      items: itemsLocal,
                      tokoId: tokoIdLocal,
                      fromAutoRedirect: true,
                    ),
              ),
            );

            return;
          }

          // status dibatalkan
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) => OrderCanceledPage(
                    orderId: widget.orderId,
                    fromAutoRedirect: true,
                  ),
            ),
          );
        });
      }

      // jika status berubah ke non-menunggu, hentikan timer auto-cancel
      if (_lastStatus != null && _lastStatus != 'menunggu') {
        _autoCancelTimer?.cancel();
        _autoCancelTimer = null;
      }
    });

    // Mulai timer auto-cancel yang aman
    _startAutoCancelTimer();
  }

  void _startAutoCancelTimer() {
    // Jika sudah ada timer, batalkan dulu
    _autoCancelTimer?.cancel();

    _autoCancelTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      if (!mounted) return;

      // Ambil snapshot realtime terbaru sekali lagi (buat safety)
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('pesanan')
                .doc(widget.orderId)
                .get();
        if (!doc.exists) {
          return;
        }
        final data = doc.data();
        if (data == null) return;

        final status = (data['status'] ?? 'menunggu').toString().toLowerCase();

        // hanya proses kalau status masih 'menunggu'
        if (status != 'menunggu') {
          timer.cancel();
          _autoCancelTimer = null;
          return;
        }

        final timestamp = data['waktuOrder'] as Timestamp?;
        if (timestamp == null) {
          // kalau tidak ada waktu order, skip
          return;
        }

        final createdAt = timestamp.toDate();
        // <-- Ubah durasi di sini kalau mau (jam/detik)
        final expiredAt = createdAt.add(const Duration(hours: 2));

        if (DateTime.now().isAfter(expiredAt)) {
          // batalkan pesanan dan restore stok
          timer.cancel();
          _autoCancelTimer = null;
          await FirestoreService().batalkanPesananDanRestoreStok(
            widget.orderId,
          );
        }
      } catch (e) {
        // jangan crash app kalau error jaringan / firestore
        // bisa log di sini jika perlu
      }
    });
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _autoCancelTimer?.cancel();
    super.dispose();
  }

  String formatRupiah(int amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu':
        return Colors.grey;
      case 'diproses':
        return Colors.orange;
      case 'siap diambil':
        return Colors.blue;
      case 'berhasil':
      case 'selesai':
        return Colors.green;
      case 'dibatalkan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu':
        return Icons.timer_outlined;
      case 'diproses':
        return Icons.sync;
      case 'siap diambil':
        return Icons.shopping_bag_outlined;
      case 'berhasil':
      case 'selesai':
        return Icons.check_circle_outline;
      case 'dibatalkan':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Duration _calculateCountdownDuration(Timestamp? timestamp) {
    if (timestamp == null) return Duration.zero;
    final now = DateTime.now();
    final targetTime = timestamp.toDate().add(const Duration(hours: 2));
    final diff = targetTime.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: orderStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildScaffoldBody('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildScaffoldBody(null, isLoading: true);
        }

        final data = snapshot.data!.data()!;
        // UI hanya membaca dari snapshot, jangan update _lastStatus di sini
        final status = (data['status'] ?? 'menunggu').toString().toLowerCase();
        final timestamp = data['waktuOrder'] as Timestamp?;
        final kodePembayaran = data['kodePembayaran']?.toString() ?? '-';
        final tanggalPesanan =
            timestamp != null
                ? DateFormat('dd MMM yyyy HH:mm').format(timestamp.toDate())
                : '-';

        final itemsRaw = data['items'] ?? [];
        final List<Map<String, dynamic>> items =
            List<Map<String, dynamic>>.from(itemsRaw);

        final int totalHarga = items.fold<int>(0, (acc, item) {
          final int harga = (item['harga'] as num).toInt();
          final int qty = (item['jumlah'] as num).toInt();
          return acc + (harga * qty);
        });

        final countdownDuration = _calculateCountdownDuration(timestamp);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Detail Pesanan'),
            centerTitle: true,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID Pesanan: ${widget.orderId}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text('Kode Pembayaran: $kodePembayaran'),
                        const SizedBox(height: 6),
                        Text('Tanggal: $tanggalPesanan'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              statusIcon(status),
                              color: statusColor(status),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: statusColor(
                                status,
                              ).withValues(alpha: 0.1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (countdownDuration > Duration.zero)
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Waktu Tersisa Pembayaran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CountdownTimer(duration: countdownDuration),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                  const Text(
                    'Daftar Item',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...items.map(
                    (item) => Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.greenAccent,
                          child: Icon(Icons.fastfood, color: Colors.white),
                        ),
                        title: Text(item['nama']),
                        subtitle: Text('Jumlah: ${item['jumlah']}'),
                        trailing: Text(
                          formatRupiah(
                            (item['harga'] as num).toInt() *
                                (item['jumlah'] as num).toInt(),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const Divider(thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Harga:',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        formatRupiah(totalHarga),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: _buildGlassCard(
                      blur: 20,
                      child: QrImageView(
                        data: kodePembayaran,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomeScreen(initialTabIndex: 1),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Kembali ke Riwayat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassCard({required Widget child, double blur = 10}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Scaffold _buildScaffoldBody(String? message, {bool isLoading = false}) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: Center(
        child:
            isLoading
                ? const CircularProgressIndicator()
                : Text(message ?? 'Pesanan tidak ditemukan'),
      ),
    );
  }
}

class CountdownTimer extends StatefulWidget {
  final Duration duration;
  const CountdownTimer({super.key, required this.duration});

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Duration remaining;

  @override
  void initState() {
    super.initState();
    remaining = widget.duration;
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && remaining > Duration.zero) {
        setState(() => remaining -= const Duration(seconds: 1));
        _startTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${h.toString().padLeft(2, '0')} : ${m.toString().padLeft(2, '0')} : ${s.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
