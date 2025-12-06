import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

final Set<String> _reviewDialogShownOrders = {};
final logger = Logger();

class OrderSuccessPage extends StatefulWidget {
  final String orderId;
  final int totalHarga;
  final List<Map<String, dynamic>> items;
  final String tokoId;
  final bool fromAutoRedirect; // <--- TAMBAHKAN INI

  const OrderSuccessPage({
    super.key,
    required this.orderId,
    required this.totalHarga,
    required this.items,
    required this.tokoId,
    this.fromAutoRedirect = false, // <--- TAMBAHKAN INI
  });

  @override
  State<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends State<OrderSuccessPage> {
  late String userId;
  bool _hasShownDialog = false;
  Map<String, bool> _produkReviewStatus = {};

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _cekStatusReviewSemuaProduk();

    // ✅ Popup hanya muncul sekali per order (tidak tiap buka)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted ||
          _hasShownDialog ||
          _reviewDialogShownOrders.contains(widget.orderId)) {
        return;
      }

      if (adaProdukBelumReview) {
        _hasShownDialog = true;
        _reviewDialogShownOrders.add(widget.orderId);
        _showReviewDialog();
      }
    });
  }

  // ✅ Cek apakah user sudah review produk (di subkoleksi produk/reviews)
  Future<bool> _cekReviewProduk(String produkId) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('produk')
              .doc(produkId)
              .collection('reviews')
              .where('userId', isEqualTo: userId)
              .where('orderId', isEqualTo: widget.orderId)
              .limit(1)
              .get();

      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      logger.e("Gagal cek review produk", error: e, stackTrace: st);
      return false;
    }
  }

  // ✅ Cek status semua produk di order ini
  Future<void> _cekStatusReviewSemuaProduk() async {
    if (userId.isEmpty || widget.items.isEmpty) return;
    final statusMap = <String, bool>{};

    for (final item in widget.items) {
      final produkId = item['idProduk'] ?? '';
      if (produkId.isEmpty) continue;
      final sudah = await _cekReviewProduk(produkId);
      statusMap[produkId] = sudah;
    }

    if (mounted) setState(() => _produkReviewStatus = statusMap);
  }

  bool get adaProdukBelumReview =>
      _produkReviewStatus.values.any((sudah) => !sudah);

  // ✅ Dialog review muncul sekali
  void _showReviewDialog() {
    String produkId = '';
    for (final item in widget.items) {
      final pid = item['idProduk'] ?? '';
      if (pid.isNotEmpty && _produkReviewStatus[pid] == false) {
        produkId = pid;
        break;
      }
    }

    if (produkId.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Berikan Ulasan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Yuk berikan ulasan untuk pesananmu agar kami bisa terus meningkatkan layanan!',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Nanti Saja',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToReview(userId, produkId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Tulis Ulasan',
                  style: TextStyle(
                    color: Colors.white, // ⬅️ Tambahkan ini
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // ✅ Setelah kirim review → tombol & popup hilang otomatis
  Future<void> _navigateToReview(String userId, String produkId) async {
    await Navigator.pushNamed(
      context,
      '/review',
      arguments: {
        'produkId': produkId,
        'userId': userId,
        'tokoId': widget.tokoId,
        'orderId': widget.orderId,
      },
    );

    await _cekStatusReviewSemuaProduk();
    if (mounted) setState(() {});
  }

  String _formatRupiah(num value) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final semuaSudahReview =
        _produkReviewStatus.isNotEmpty &&
        !_produkReviewStatus.values.any((r) => r == false);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade300, Colors.green.shade600],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Lottie.asset(
                    'assets/success_animation.json',
                    width: 200,
                    height: 200,
                    repeat: false,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  "Pesanan Berhasil!",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Terima kasih telah memesan di WasteFood.\nPesananmu sedang diproses.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade800,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                _buildOrderSummary(),
                const SizedBox(height: 28),

                if (adaProdukBelumReview) _buildReviewButton(),

                if (semuaSudahReview)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      "Semua produk pada pesanan ini telah diulas.\nTerima kasih!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),

                const SizedBox(height: 25),
                _buildBackToHomeButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final total = _formatRupiah(widget.totalHarga);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Kode Pesanan",
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            widget.orderId,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          const Text(
            "Detail Pesanan:",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ...widget.items.map((item) {
            final nama = item['namaProduk'] ?? '-';
            final jumlah = (item['jumlah'] ?? 0);
            final harga = (item['harga'] ?? 0);
            final totalItem = _formatRupiah(
              (harga is num ? harga : 0) * jumlah,
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text("$nama x $jumlah")),
                  Text(
                    totalItem,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }),
          const Divider(thickness: 1, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Pembayaran:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                total,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewButton() {
    final produkBelumReview =
        _produkReviewStatus.entries
            .firstWhere((e) => !e.value, orElse: () => MapEntry('', true))
            .key;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed:
            produkBelumReview.isNotEmpty
                ? () => _navigateToReview(userId, produkBelumReview)
                : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.orange.shade600,
        ),
        child: const Text(
          "Tulis Ulasan",
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBackToHomeButton() {
    return ElevatedButton(
      onPressed:
          () =>
              Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.green.shade600,
      ),
      child: const Text(
        "Kembali ke Beranda",
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }
}
