import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StorePerformancePage extends StatefulWidget {
  const StorePerformancePage({super.key});

  @override
  State<StorePerformancePage> createState() => _StorePerformancePageState();
}

class _StorePerformancePageState extends State<StorePerformancePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? tokoId;

  @override
  void initState() {
    super.initState();
    _loadTokoId();
  }

  Future<void> _loadTokoId() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final snapshot = await _firestore
          .collection('toko')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          tokoId = snapshot.docs.first.id;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _getStorePerformance() async {
    if (tokoId == null) return {};

    try {
      // Ambil semua produk dari toko
      final produkSnapshot = await _firestore
          .collection('toko')
          .doc(tokoId)
          .collection('produk')
          .get();

      final int totalProduk = produkSnapshot.docs.length;
      final int totalStok = produkSnapshot.docs.fold<int>(
        0,
        (acc, doc) => acc + (doc.data()['stok'] ?? 0) as int,
      );

      // Ambil semua pesanan dengan status "berhasil"
      final pesananSnapshot = await _firestore
          .collection('pesanan')
          .where('tokoId', isEqualTo: tokoId)
          .where('status', isEqualTo: 'berhasil')
          .get();

      final int totalOrders = pesananSnapshot.docs.length;

      double totalSales = 0;
      Set<String> pelangganUnik = {};

      for (var doc in pesananSnapshot.docs) {
        final items = doc.data()['items'] as List<dynamic>? ?? [];

        for (var item in items) {
          final harga = (item['harga'] ?? 0).toDouble();
          final jumlah = (item['jumlah'] ?? 0).toDouble();
          totalSales += harga * jumlah;
        }

        final userId = doc.data()['userId'];
        if (userId != null) pelangganUnik.add(userId);
      }

      return {
        'totalProduk': totalProduk,
        'totalStok': totalStok,
        'totalOrders': totalOrders,
        'totalSales': totalSales,
        'totalCustomers': pelangganUnik.length,
      };
    } catch (e) {
      debugPrint('Error fetching performance: $e');
      return {};
    }
  }

  String _formatCurrency(num amount) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performa Toko'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: tokoId == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Map<String, dynamic>>(
              future: _getStorePerformance(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Gagal memuat data performa.'));
                }

                final data = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      _buildCard(
                          'Total Penjualan',
                          _formatCurrency(data['totalSales']),
                          Colors.green),
                      const SizedBox(height: 16),
                      _buildCard('Total Pesanan',
                          '${data['totalOrders']} Pesanan', Colors.blue),
                      const SizedBox(height: 16),
                      _buildCard('Jumlah Pembeli',
                          '${data['totalCustomers']} Pelanggan', Colors.orange),
                      const SizedBox(height: 16),
                      _buildCard('Total Produk',
                          '${data['totalProduk']} Produk', Colors.deepPurple),
                      const SizedBox(height: 16),
                      _buildCard('Total Stok',
                          '${data['totalStok']} Barang', Colors.teal),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(value,
                style: TextStyle(
                    fontSize: 16, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
