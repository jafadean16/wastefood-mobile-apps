// File: lib/screens/store/store_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? storeData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchStoreData();
  }

  Future<void> fetchStoreData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception("User belum login");

      final doc = await _firestore.collection('toko').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          storeData = doc.data();
          isLoading = false;
        });
      } else {
        setState(() {
          storeData = null;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Gagal memuat data toko: $e";
        isLoading = false;
      });
    }
  }

  void navigateTo(String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  void navigateToAddProduct() {
    final uid = _auth.currentUser?.uid;

    if (uid != null && storeData != null) {
      Navigator.pushNamed(
        context,
        '/store/add_product',
        arguments: {'tokoId': uid},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data toko belum tersedia.")),
      );
    }
  }

  void navigateToProductList() {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      Navigator.pushNamed(
        context,
        '/store/product_list',
        arguments: {'tokoId': uid},
      );
    }
  }

  void navigateToOrderPage() {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      Navigator.pushNamed(context, '/store/orders', arguments: {'tokoId': uid});
    }
  }

  void navigateToOrderConfirmationPage() {
    Navigator.pushNamed(context, '/order/confirmation');
  }

  void navigateToFinancePage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final tokoSnapshot =
        await FirebaseFirestore.instance
            .collection('toko')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();

    if (!mounted) return;

    if (tokoSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data toko tidak ditemukan')),
      );
      return;
    }

    final tokoId = tokoSnapshot.docs.first.id;

    Navigator.pushNamed(
      context,
      '/store/finance',
      arguments: {'tokoId': tokoId, 'userUid': user.uid},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Toko Saya"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang',
            onPressed: fetchStoreData,
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              : storeData == null
              ? const Center(child: Text("Data toko tidak ditemukan."))
              : Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    if (storeData!['fotoUrl'] != null &&
                        storeData!['fotoUrl'].toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          storeData!['fotoUrl'],
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                                  const Text('Gagal memuat foto toko'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      storeData!['namaToko'] ?? "Nama Toko",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      storeData!['deskripsi'] ?? "Tanpa deskripsi",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const Divider(height: 32),
                    Text("Pemilik: ${storeData!['nama'] ?? '-'}"),
                    const SizedBox(height: 8),
                    Text("NIK: ${storeData!['nik'] ?? '-'}"),
                    const SizedBox(height: 8),
                    Text(
                      "Tanggal Daftar: ${storeData!['createdAt'] != null ? (storeData!['createdAt'] as Timestamp).toDate().toString().split(' ')[0] : '-'}",
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Foto KTP:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (storeData!['ktpUrl'] != null &&
                        storeData!['ktpUrl'].toString().isNotEmpty)
                      Image.network(
                        storeData!['ktpUrl'],
                        height: 150,
                        errorBuilder:
                            (_, __, ___) =>
                                const Text('Gagal memuat gambar KTP'),
                      )
                    else
                      const Text('Tidak ada foto KTP'),
                    const SizedBox(height: 24),
                    const Text(
                      "Selfie dengan KTP:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (storeData!['selfieUrl'] != null &&
                        storeData!['selfieUrl'].toString().isNotEmpty)
                      Image.network(
                        storeData!['selfieUrl'],
                        height: 150,
                        errorBuilder:
                            (_, __, ___) =>
                                const Text('Gagal memuat gambar selfie'),
                      )
                    else
                      const Text('Tidak ada foto selfie'),
                  ],
                ),
              ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        overlayColor: Colors.black,
        overlayOpacity: 0.4,
        spacing: 8,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.inventory),
            label: 'Daftar Produk',
            onTap: navigateToProductList,
          ),
          SpeedDialChild(
            child: const Icon(Icons.bar_chart),
            label: 'Kinerja Toko',
            onTap: () => navigateTo('/store/performance'),
          ),
          SpeedDialChild(
            child: const Icon(Icons.add_box),
            label: 'Tambah Produk',
            onTap: navigateToAddProduct,
          ),
          SpeedDialChild(
            child: const Icon(Icons.account_balance_wallet),
            label: 'Keuangan',
            onTap: navigateToFinancePage,
          ),
          SpeedDialChild(
            child: const Icon(Icons.receipt_long),
            label: 'Pesanan',
            onTap: navigateToOrderPage,
          ),
          SpeedDialChild(
            child: const Icon(Icons.qr_code_2),
            label: 'Konfirmasi Pesanan',
            onTap: navigateToOrderConfirmationPage,
          ),
        ],
      ),
    );
  }
}
