import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../services/firestore_service.dart';
import '../../screens/chat/chat_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wastefood/screens/cart/cart_page.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> productData;

  const ProductDetailPage({super.key, required this.productData});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();
  int _qty = 1;

  bool get isStokHabis =>
      widget.productData['stok'] == null || widget.productData['stok'] <= 0;

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final DateFormat dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final product = Product.fromMap(widget.productData);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    const Color primary = Color(0xFF2E7D32);
    const Color accent = Color(0xFFE8F5E9);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: Text(
          product.namaProduk,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Chat dengan Toko',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => ChatPage(
                        tokoId: product.tokoId,
                        userId: FirebaseAuth.instance.currentUser!.uid,
                      ),
                ),
              );
            },
          ),
          if (userId != null)
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('keranjang')
                      .doc(userId)
                      .collection('items')
                      .snapshots(),
              builder: (context, snapshot) {
                int totalItem = 0;
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final jumlah = data['jumlah'];
                    if (jumlah is int) totalItem += jumlah;
                  }
                }

                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      tooltip: 'Keranjang',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartPage()),
                        );
                      },
                    ),
                    if (totalItem > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$totalItem',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼️ Gambar produk
            Stack(
              children: [
                Hero(
                  tag: product.gambarUrl,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    child: Image.network(
                      product.gambarUrl,
                      height: 280,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      color:
                          isStokHabis
                              ? Colors.white.withValues(alpha: 0.6)
                              : null,
                      colorBlendMode:
                          isStokHabis ? BlendMode.saturation : BlendMode.dst,
                    ),
                  ),
                ),
                if (isStokHabis)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.6),
                      child: const Center(
                        child: Text(
                          'STOK HABIS',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // 🧠 Info produk
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: accent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.namaProduk,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currencyFormatter.format(product.harga),
                        style: const TextStyle(
                          fontSize: 20,
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stok tersedia: ${product.stok}',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              product.stok > 0
                                  ? Colors.black87
                                  : Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            product.tokoNama,
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const Spacer(),
                          Icon(
                            product.isAvailable
                                ? Icons.check_circle
                                : Icons.cancel,
                            color:
                                product.isAvailable
                                    ? Colors.green
                                    : Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product.isAvailable ? 'Tersedia' : 'Tidak Tersedia',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  product.isAvailable
                                      ? Colors.green
                                      : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 📜 Deskripsi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'Deskripsi',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                product.deskripsi,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                'Terakhir diperbarui: ${dateFormat.format(product.updatedAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 30),

            // 🔢 Jumlah Produk
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Jumlah:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade200,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed:
                              isStokHabis || _qty == 1
                                  ? null
                                  : () => setState(() => _qty--),
                        ),
                        Text(
                          '$_qty',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed:
                              isStokHabis || _qty >= product.stok
                                  ? null
                                  : () => setState(() => _qty++),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 🛒 Tombol tambah ke keranjang
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isStokHabis ? Colors.grey : primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: Colors.greenAccent.withValues(alpha: 0.4),
                  ),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(
                    isStokHabis ? 'Stok Habis' : 'Tambah ke Keranjang',
                    style: const TextStyle(fontSize: 16),
                  ),
                  onPressed:
                      isStokHabis
                          ? null
                          : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final existingQty = await _firestoreService
                                  .getExistingCartQty(product.produkId);
                              if ((existingQty + _qty) > product.stok) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Stok tidak mencukupi. Sisa ${product.stok - existingQty}.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              await _firestoreService.addToCart(product, _qty);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Produk ditambahkan ke keranjang',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Gagal: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
