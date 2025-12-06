import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../screens/home_screen.dart';

class OrderCanceledPage extends StatelessWidget {
  final String orderId;
  final bool fromAutoRedirect;

  const OrderCanceledPage({
    super.key,
    required this.orderId,
    this.fromAutoRedirect = false,
  });

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
    final ordersRef = FirebaseFirestore.instance.collection('pesanan');

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Pesanan Dibatalkan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Kembali ke halaman History, BUKAN ke OrderDetail
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder:
                    (_) => const HomeScreen(initialTabIndex: 1), // tab History
              ),
              (route) => false,
            );
          },
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFFD32F2F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: FutureBuilder<DocumentSnapshot>(
        future: ordersRef.doc(orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Data pesanan tidak ditemukan.'));
          }

          final order = snapshot.data!.data() as Map<String, dynamic>;
          final createdAt = (order['createdAt'] as Timestamp).toDate();
          final kodePembayaran = order['kodePembayaran'] ?? '-';
          final metode = order['metode'] ?? '-';
          final pengambilan = order['pengambilan'] ?? '-';
          final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
          final totalHarga = _hitungTotal(items);
          final format = NumberFormat.currency(
            locale: 'id',
            symbol: 'Rp ',
            decimalDigits: 0,
          );
          final formatDate = DateFormat('dd MMM yyyy, HH:mm');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cancel_rounded,
                      color: Colors.red,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pesanan ini telah dibatalkan.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(
                        Icons.calendar_today,
                        'Tanggal Order',
                        formatDate.format(createdAt),
                      ),
                      _infoRow(
                        Icons.receipt_long,
                        'Kode Pembayaran',
                        kodePembayaran,
                      ),
                      _infoRow(Icons.payment, 'Metode Pembayaran', metode),
                      _infoRow(Icons.storefront, 'Pengambilan', pengambilan),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Daftar Item',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...items.map((item) {
                final harga =
                    (item['harga'] is double)
                        ? (item['harga'] as double).toInt()
                        : item['harga'] ?? 0;
                final jumlah = item['jumlah'] ?? 1;
                final subtotal = harga * jumlah;
                return Card(
                  elevation: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    title: Text(
                      item['nama'] ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Jumlah: $jumlah  •  Harga: ${format.format(harga)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Text(
                      format.format(subtotal),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                );
              }),
              const Divider(height: 32, thickness: 1.2),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ${format.format(totalHarga)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
