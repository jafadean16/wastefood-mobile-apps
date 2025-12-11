// cart_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wastefood/models/cart_item.dart';
import 'package:wastefood/models/product.dart';
import 'package:wastefood/screens/checkout/checkout_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
  );
  final ValueNotifier<double> totalHargaNotifier = ValueNotifier(0.0);

  Map<String, Map<String, dynamic>> groupedProducts = {};
  Map<String, bool> selectedGroupedItems = {};
  final Map<String, bool> _processing = {};
  StreamSubscription<QuerySnapshot>? _cartSub;
  Map<String, List<Product>> recommendedByStore = {};
  bool isLoadingRekom = false;

  @override
  void initState() {
    super.initState();
    _listenCartUpdates();
  }

  void _listenCartUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _cartSub = FirebaseFirestore.instance
        .collection('keranjang')
        .doc(user.uid)
        .collection('items')
        .snapshots()
        .listen((snapshot) {
          groupCartItems(snapshot.docs);
        });
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    totalHargaNotifier.dispose();
    super.dispose();
  }

  void groupCartItems(List<QueryDocumentSnapshot> docs) async {
    final tmp = <String, Map<String, dynamic>>{};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final idProduk = data['idProduk']?.toString() ?? doc.id;
      final jumlah = (data['jumlah'] as num?)?.toInt() ?? 1;

      // 🔥 Ambil data produk dari koleksi 'produk'
      final prodSnap =
          await FirebaseFirestore.instance
              .collection('produk')
              .doc(idProduk)
              .get();
      final prodData = prodSnap.data();

      final product = Product(
        produkId: idProduk,
        namaProduk: prodData?['nama'] ?? data['nama'] ?? '',
        deskripsi: prodData?['deskripsi'] ?? data['deskripsi'] ?? '',
        harga:
            (prodData?['harga'] as num?)?.toDouble() ??
            (data['harga'] as num?)?.toDouble() ??
            0.0,
        stok:
            (prodData?['stok'] as num?)?.toInt() ??
            0, // ✅ ambil stok asli dari produk
        gambarUrl: prodData?['gambarUrl'] ?? data['gambarUrl'] ?? '',
        kategori: prodData?['kategori'] ?? data['kategori'] ?? '',
        isAvailable: prodData?['isAvailable'] ?? data['isAvailable'] ?? true,
        createdAt:
            (prodData?['createdAt'] as Timestamp?)?.toDate() ??
            (data['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.now(),
        updatedAt:
            (prodData?['updatedAt'] as Timestamp?)?.toDate() ??
            (data['updatedAt'] as Timestamp?)?.toDate() ??
            DateTime.now(),
        tokoId: prodData?['tokoId'] ?? data['tokoId'] ?? '',
        tokoNama: prodData?['tokoNama'] ?? data['tokoNama'] ?? '',
        sellerId: prodData?['sellerId'] ?? data['sellerId'] ?? '',
      );

      tmp[idProduk] = {
        'product': product,
        'quantity': jumlah,
        'docIds': [doc.id],
      };
    }

    final sel = <String, bool>{};
    for (final k in tmp.keys) {
      sel[k] = selectedGroupedItems[k] ?? false;
    }

    if (mounted) {
      setState(() {
        groupedProducts = tmp;
        selectedGroupedItems = sel;
      });
      hitungTotalHarga();
    }
  }

  Future<void> fetchRecommendations(String pid, String tokoId) async {
    if (recommendedByStore[pid] != null) return;

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('produk')
              .where('tokoId', isEqualTo: tokoId)
              .get();

      final List<Product> rekom =
          snap.docs
              .where((doc) => doc.id != pid)
              .map((doc) => Product.fromDocument(doc)) // ← aman!
              .toList();

      setState(() {
        recommendedByStore[pid] = rekom;
      });
    } catch (e) {
      debugPrint("Gagal load rekomendasi: $e");
    }
  }

  void hitungTotalHarga() {
    double total = 0.0;
    for (final e in groupedProducts.entries) {
      if (selectedGroupedItems[e.key] == true) {
        final prod = e.value['product'] as Product;
        final qty = (e.value['quantity'] as int?) ?? 0;
        total += prod.harga * qty;
      }
    }
    totalHargaNotifier.value = total;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Pengguna tidak terautentikasi')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Keranjang'),
        centerTitle: true,
        // 🔥 bikin icon panah jadi putih
        iconTheme: const IconThemeData(color: Colors.white),

        // 🔥 bikin tulisan Keranjang jadi putih
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child:
                groupedProducts.isEmpty
                    ? const Center(child: Text('Keranjang kamu kosong 🛒'))
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: groupedProducts.length,
                      itemBuilder: (context, index) {
                        final pid = groupedProducts.keys.elementAt(index);
                        final data = groupedProducts[pid]!;
                        final prod = data['product'];
                        if (prod == null || prod is! Product) {
                          return const SizedBox.shrink();
                        }
                        return KeyedSubtree(
                          key: ValueKey(pid),
                          child: _buildCartItem(pid, data),
                        );
                      },
                    ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: totalHargaNotifier,
                    builder: (context, total, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            currencyFormatter.format(total),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        selectedGroupedItems.values.any((v) => v)
                            ? handleCheckout
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.shopping_cart_checkout,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Checkout',
                      style: TextStyle(color: Colors.white),
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

  Widget _buildCartItem(String pid, Map<String, dynamic> data) {
    final Product product = data['product'] as Product;
    final int quantity = (data['quantity'] as int?) ?? 0;
    final bool isSelected = selectedGroupedItems[pid] ?? false;
    final bool processing = _processing[pid] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==================== REKOMENDASI PRODUK ====================
        FutureBuilder(
          future: fetchRecommendations(pid, product.tokoId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                (recommendedByStore[pid] == null)) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  height: 30,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final rekom = recommendedByStore[pid] ?? [];

            if (rekom.isEmpty) return const SizedBox();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),

                const Text(
                  "Rekomendasi dari toko ini",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  height: 125, // dinaikkan biar tidak overflow
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: rekom.length,
                    itemBuilder: (context, index) {
                      final r = rekom[index];

                      return InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/product-detail',
                            arguments: {
                              'produkId': r.produkId,
                              'nama': r.namaProduk,
                              'deskripsi': r.deskripsi,
                              'harga': r.harga,
                              'stok': r.stok,
                              'gambarUrl': r.gambarUrl,
                              'kategori': r.kategori,
                              'tokoId': r.tokoId,
                              'tokoNama': r.tokoNama,
                              'sellerId': r.sellerId,
                            },
                          );
                        },
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  r.gambarUrl,
                                  width: 100,
                                  height: 55,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r.namaProduk,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currencyFormatter.format(r.harga),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),
              ],
            );
          },
        ),

        // ==================== CARD PRODUK KERANJANG ====================
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    product.gambarUrl,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                            const Icon(Icons.broken_image, size: 60),
                  ),
                ),

                const SizedBox(width: 12),

                // ==================== INFO PRODUK ====================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.namaProduk,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormatter.format(product.harga),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // ==================== JUMLAH ====================
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.redAccent,
                            onPressed:
                                processing
                                    ? null
                                    : () => ubahJumlahItem(
                                      FirebaseAuth.instance.currentUser!.uid,
                                      pid,
                                      -1,
                                    ),
                          ),
                          Text(
                            "$quantity",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: Colors.green,
                            onPressed:
                                processing
                                    ? null
                                    : () => ubahJumlahItem(
                                      FirebaseAuth.instance.currentUser!.uid,
                                      pid,
                                      1,
                                    ),
                          ),

                          const SizedBox(width: 8),
                          Text(
                            "Stok: ${product.stok}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),

                          if (processing) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // ==================== CHECKBOX + DELETE ====================
                Column(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        selectedGroupedItems[pid] = val ?? false;
                        hitungTotalHarga();
                        setState(() {});
                      },
                      side: const BorderSide(
                        color: Color(0xFF4CAF50),
                        width: 2,
                      ),
                      checkColor: Colors.white,
                      activeColor: const Color(0xFF4CAF50),
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF4CAF50);
                        }
                        return Colors.white;
                      }),
                    ),

                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.redAccent,
                      onPressed:
                          () => hapusItemGroup(
                            pid,
                            FirebaseAuth.instance.currentUser!.uid,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> ubahJumlahItem(String uid, String pid, int delta) async {
    final entry = groupedProducts[pid];
    if (entry == null) return;

    final List<String> docIds = List<String>.from(entry['docIds'] ?? []);
    if (docIds.isEmpty) return;

    if (_processing[pid] == true) return;
    setState(() => _processing[pid] = true);

    final Product prod = entry['product'] as Product;

    int stok = prod.stok;
    try {
      final prodSnap =
          await FirebaseFirestore.instance.collection('produk').doc(pid).get();
      if (prodSnap.exists) {
        stok = (prodSnap.data()?['stok'] as num?)?.toInt() ?? stok;
      }
    } catch (_) {}

    final currentQty = (entry['quantity'] as int?) ?? 0;
    final newQty = (currentQty + delta).clamp(0, stok);

    if (newQty == currentQty) {
      setState(() => _processing.remove(pid));
      return;
    }

    groupedProducts[pid]!['quantity'] = newQty;

    final firstDocId = docIds.first;
    final docRef = FirebaseFirestore.instance
        .collection('keranjang')
        .doc(uid)
        .collection('items')
        .doc(firstDocId);

    try {
      if (newQty <= 0) {
        await docRef.delete();
      } else {
        await docRef.update({'jumlah': newQty});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memperbarui jumlah: $e')));
      }
    } finally {
      setState(() => _processing.remove(pid));
      hitungTotalHarga();
    }
  }

  Future<void> hapusItemGroup(String pid, String uid) async {
    final ids = List<String>.from(groupedProducts[pid]?['docIds'] ?? []);
    if (ids.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance
        .collection('keranjang')
        .doc(uid)
        .collection('items');
    for (final id in ids) {
      batch.delete(col.doc(id));
    }

    try {
      await batch.commit();

      if (!mounted) return; // ✅ pastikan widget masih aktif

      setState(() {
        groupedProducts.remove(pid);
        selectedGroupedItems.remove(pid);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item dihapus')));

      hitungTotalHarga();
    } catch (e) {
      if (!mounted) return; // ✅ tambahkan juga di sini agar aman

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  void handleCheckout() {
    final selectedEntries =
        groupedProducts.entries
            .where((e) => selectedGroupedItems[e.key] == true)
            .toList();

    if (selectedEntries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih item dahulu')));
      return;
    }

    final items =
        selectedEntries.map((e) {
          final prod = e.value['product'] as Product;
          final qty = (e.value['quantity'] as int?) ?? 0;
          return CartItem(
            product: prod,
            quantity: qty,
            priceAtCheckout: prod.harga,
          );
        }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutPage(items: items)),
    );
  }
}
