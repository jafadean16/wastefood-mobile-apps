import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../order/order_detail_page.dart';
import '../order/order_success_page.dart';
import '../order/order_canceled_page.dart';

class OrdersPage extends StatefulWidget {
  final String tokoId;

  const OrdersPage({super.key, required this.tokoId});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = true;
  String? errorMessage;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> orders = [];

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final querySnapshot =
          await _firestore
              .collection('pesanan')
              .where('tokoId', isEqualTo: widget.tokoId)
              .orderBy('createdAt', descending: true)
              .get();

      setState(() {
        orders = querySnapshot.docs;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Gagal memuat pesanan: ${e.toString()}";
      });
      debugPrint('Error fetching orders: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
  }

  String formatRupiah(int amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  void handleTapOrder(
    Map<String, dynamic> data,
    String orderId,
    int totalHarga,
  ) {
    final status = data['status'] ?? 'menunggu';

    if (status == 'menunggu') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailPage(orderId: orderId),
        ),
      );
    } else if (status == 'berhasil') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => OrderSuccessPage(
                orderId: orderId,
                totalHarga: totalHarga,
                items:
                    (data['items'] as List<dynamic>?)
                        ?.map((item) => Map<String, dynamic>.from(item))
                        .toList() ??
                    [],
                tokoId: data['tokoId'] ?? '', // ← tambahkan ini!
              ),
        ),
      );
    } else if (status == 'dibatalkan') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderCanceledPage(orderId: orderId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pesanan Masuk"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : orders.isEmpty
              ? const Center(child: Text("Belum ada pesanan masuk."))
              : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final orderDoc = orders[index];
                  final data = orderDoc.data();

                  final List<dynamic> items =
                      (data['items'] is List) ? data['items'] : [];

                  final String status = data['status'] ?? 'Menunggu';
                  final Timestamp? createdAt =
                      data['createdAt'] is Timestamp ? data['createdAt'] : null;
                  final String waktu = formatDate(createdAt);

                  final List<String> namaProduk =
                      items
                          .map((e) => e['nama']?.toString() ?? '')
                          .where((nama) => nama.isNotEmpty)
                          .toList();
                  final String namaPesanan = namaProduk.join(', ');

                  final int totalHarga = _hitungTotal(
                    List<Map<String, dynamic>>.from(items),
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    elevation: 2,
                    child: ListTile(
                      leading: const Icon(
                        Icons.shopping_bag,
                        color: Colors.green,
                      ),
                      title: Text(
                        namaPesanan.isNotEmpty ? namaPesanan : 'Pesanan',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Status: $status"),
                            Text("Waktu: $waktu"),
                            Text("Total: ${formatRupiah(totalHarga)}"),
                          ],
                        ),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap:
                          () => handleTapOrder(data, orderDoc.id, totalHarga),
                    ),
                  );
                },
              ),
    );
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
}
