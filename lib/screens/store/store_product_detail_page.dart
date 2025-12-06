import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../services/firestore_service.dart';

class StoreProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> productData;

  const StoreProductDetailPage({super.key, required this.productData});

  @override
  State<StoreProductDetailPage> createState() => _StoreProductDetailPageState();
}

class _StoreProductDetailPageState extends State<StoreProductDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();

  void _showEditDialog(Product product) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    final namaController = TextEditingController(text: product.namaProduk);
    final hargaController = TextEditingController(
      text: currencyFormatter.format(product.harga),
    );
    final stokController = TextEditingController(text: product.stok.toString());
    final deskripsiController = TextEditingController(text: product.deskripsi);

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Edit Produk'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: namaController,
                    decoration: const InputDecoration(labelText: 'Nama Produk'),
                  ),
                  TextField(
                    controller: hargaController,
                    decoration: const InputDecoration(labelText: 'Harga'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: stokController,
                    decoration: const InputDecoration(labelText: 'Stok'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: deskripsiController,
                    decoration: const InputDecoration(labelText: 'Deskripsi'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                child: const Text('Simpan'),
                onPressed: () async {
                  // Hapus format rupiah
                  final hargaInt =
                      int.tryParse(
                        hargaController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                      ) ??
                      product.harga;

                  final updatedData = {
                    'namaProduk': namaController.text,
                    'harga': hargaInt,
                    'stok': int.tryParse(stokController.text) ?? product.stok,
                    'deskripsi': deskripsiController.text,
                    'updatedAt': DateTime.now(),
                  };

                  try {
                    // 🔥 Ini satu-satunya yang perlu dilakukan!
                    await _firestoreService.updateProduct(
                      product.produkId,
                      product.tokoId,
                      updatedData,
                    );

                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Produk berhasil diperbarui'),
                      ),
                    );

                    // Update tampilan lokal
                    setState(() {
                      widget.productData.addAll(updatedData);
                    });
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal memperbarui produk: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
    );
  }

  void _confirmDelete(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Hapus Produk'),
            content: const Text(
              'Anda yakin ingin menghapus produk ini? Tindakan ini tidak bisa dibatalkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _firestoreService.deleteProduct(product.produkId, product.tokoId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produk berhasil dihapus')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = Product.fromMap(widget.productData);
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditDialog(product),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(product),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(product.gambarUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            product.namaProduk,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormatter.format(product.harga),
            style: const TextStyle(fontSize: 18, color: Colors.green),
          ),
          const SizedBox(height: 8),
          Text('Stok: ${product.stok}', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Text('Kategori: ${product.kategori}'),
          const SizedBox(height: 8),
          Text('Toko: ${product.tokoNama}'),
          const SizedBox(height: 16),
          const Text(
            'Deskripsi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(product.deskripsi),
        ],
      ),
    );
  }
}
