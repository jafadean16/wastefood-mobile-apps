import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../screens/product_detail_page.dart';

class StoreDetailPage extends StatelessWidget {
  final String tokoId;
  final String tokoNama;

  const StoreDetailPage({
    super.key,
    required this.tokoId,
    required this.tokoNama,
  });

  Future<List<Map<String, dynamic>>> fetchProduk() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('toko')
            .doc(tokoId)
            .collection('produk')
            .orderBy('updatedAt', descending: true)
            .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<Map<String, dynamic>> fetchTokoReviewStats() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('toko')
            .doc(tokoId)
            .collection('reviews')
            .get();

    if (snapshot.docs.isEmpty) {
      return {'averageRating': 0.0, 'totalReviews': 0};
    }

    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['rating'] ?? 0);
    }

    double avg = total / snapshot.docs.length;

    return {'averageRating': avg, 'totalReviews': snapshot.docs.length};
  }

  Future<void> tambahKeKeranjang(
    BuildContext context,
    Map<String, dynamic> produk,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final messenger = ScaffoldMessenger.of(context);

    final itemRef = FirebaseFirestore.instance
        .collection('keranjang')
        .doc(userId)
        .collection('items')
        .doc(produk['id']);

    final snapshot = await itemRef.get();
    final existingQty = snapshot.data()?['jumlah'] ?? 0;
    final stok = produk['stok'] ?? 0;

    if (existingQty + 1 > stok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Stok tidak mencukupi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await itemRef.set({
      'namaProduk': produk['namaProduk'],
      'harga': produk['harga'],
      'gambarUrl': produk['gambarUrl'],
      'jumlah': existingQty + 1,
      'idProduk': produk['id'],
    });

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Produk ditambahkan ke keranjang'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tokoNama),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchTokoReviewStats(),
        builder: (context, reviewSnapshot) {
          if (reviewSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reviewData =
              reviewSnapshot.data ?? {'averageRating': 0.0, 'totalReviews': 0};
          final avgRating = reviewData['averageRating'] as double;
          final totalReviews = reviewData['totalReviews'] as int;

          return Column(
            children: [
              // Rating toko
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: Colors.green.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: Colors.orange.shade400),
                    const SizedBox(width: 6),
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('($totalReviews ulasan)'),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: fetchProduk(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Gagal memuat produk'));
                    }

                    final produkList = snapshot.data ?? [];
                    if (produkList.isEmpty) {
                      return const Center(
                        child: Text('Belum ada produk di toko ini'),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 3 / 4.8,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                      itemCount: produkList.length,
                      itemBuilder: (context, index) {
                        final produk = produkList[index];
                        final stokHabis = (produk['stok'] ?? 0) <= 0;

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        ProductDetailPage(productData: produk),
                              ),
                            );
                          },
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            clipBehavior: Clip.hardEdge,
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Image.network(
                                        produk['gambarUrl'] ?? '',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) => const Icon(
                                              Icons.broken_image,
                                              size: 50,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            produk['namaProduk'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            currency.format(
                                              produk['harga'] ?? 0,
                                            ),
                                            style: TextStyle(
                                              color:
                                                  stokHabis
                                                      ? Colors.grey
                                                      : Colors.green[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Rating per produk
                                          Row(
                                            children: List.generate(
                                              (produk['rating'] ?? 0).round(),
                                              (i) => const Icon(
                                                Icons.star,
                                                color: Colors.orange,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    stokHabis
                                                        ? Colors.grey
                                                        : Colors.green[700],
                                                foregroundColor:
                                                    Colors
                                                        .white, // teks & icon putih
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        12,
                                                      ), // sudut lebih bulat
                                                ),
                                                elevation: 4, // shadow halus
                                              ),
                                              icon: const Icon(
                                                Icons.add_shopping_cart,
                                                size:
                                                    20, // icon sedikit lebih besar
                                              ),
                                              label: Text(
                                                stokHabis
                                                    ? 'Stok Habis'
                                                    : 'Tambah',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              onPressed:
                                                  stokHabis
                                                      ? null
                                                      : () => tambahKeKeranjang(
                                                        context,
                                                        produk,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (stokHabis)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.8,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Stok Habis',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
