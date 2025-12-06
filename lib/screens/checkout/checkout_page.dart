// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/address.dart';
import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../services/firestore_service.dart';
// === 🔔 KIRIM NOTIFIKASI KE SELLER ===

class CheckoutPage extends StatefulWidget {
  final List<CartItem> items;

  const CheckoutPage({super.key, required this.items});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Address? selectedAddress;
  String pickupMethod = "Ambil Sendiri";
  bool isLoading = false;

  final TextEditingController catatanOrderController = TextEditingController();

  int get totalHarga => widget.items.fold(
    0,
    (total, item) => total + (item.product.harga * item.quantity).toInt(),
  );

  @override
  void dispose() {
    catatanOrderController.dispose();
    super.dispose();
  }

  Future<void> _selectAddress() async {
    if (pickupMethod == "Ambil Sendiri") {
      _showMessage("Metode ambil sendiri tidak perlu pilih alamat.");
      return;
    }

    final result = await Navigator.pushNamed(context, '/alamat-pilih');
    if (!mounted) return;
    if (result is Address) {
      setState(() => selectedAddress = result);
    } else {
      _showMessage("Alamat tidak valid atau tidak dipilih.");
    }
  }

  Future<void> _submitOrder() async {
    if (pickupMethod == "Diantar" && selectedAddress == null) {
      _showMessage("Silakan pilih alamat terlebih dahulu.");
      return;
    }

    if (widget.items.isEmpty) {
      _showMessage("Keranjang kosong.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage("Pengguna tidak ditemukan.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final firestoreService = FirestoreService();

      // ✅ Cek stok semua produk dulu
      for (var item in widget.items) {
        final stokGlobal = await firestoreService.getGlobalProdukStok(
          item.product.produkId,
        );
        final stokToko = await firestoreService.getTokoProdukStok(
          item.product.tokoId,
          item.product.produkId,
        );
        final minimalStok = stokGlobal < stokToko ? stokGlobal : stokToko;

        if (minimalStok < item.quantity) {
          _showMessage("Stok produk '${item.product.namaProduk}' tidak cukup.");
          setState(() => isLoading = false);
          return;
        }
      }

      // ✅ Data order aman
      final orderId = firestoreService.generateOrderId();
      final tokoId = widget.items.first.product.tokoId;
      final kodePembayaran = _generateKodePembayaran();

      final lokasiId =
          pickupMethod == "Diantar"
              ? selectedAddress!.id
              : "ambil_sendiri"; // 🧩 biar gak kosong

      final order = Order(
        orderId: orderId,
        userId: user.uid,
        tokoId: tokoId,
        lokasiId: lokasiId,
        metode: 'COD',
        pengambilan: pickupMethod,
        status: 'menunggu',
        kodePembayaran: kodePembayaran,
        waktuOrder: DateTime.now(),
        kadaluarsa: DateTime.now().add(const Duration(hours: 2)),
        catatanOrder: catatanOrderController.text,
        items:
            widget.items
                .map(
                  (item) => OrderItem(
                    idProduk: item.product.produkId,
                    nama: item.product.namaProduk,
                    harga: item.product.harga,
                    jumlah: item.quantity,
                    catatan: '',
                    tokoId: item.product.tokoId,
                  ),
                )
                .toList(),
      );

      debugPrint(
        "DEBUG ORDER: orderId=${order.orderId}, userId=${order.userId}, tokoId=${order.tokoId}, lokasiId=${order.lokasiId}",
      );

      await firestoreService.saveOrder(
        orderId: order.orderId,
        userId: order.userId,
        tokoId: order.tokoId,
        lokasiId: order.lokasiId,
        metode: order.metode,
        pengambilan: order.pengambilan,
        status: order.status,
        kodePembayaran: order.kodePembayaran,
        items: order.items.map((e) => e.toMap()).toList(),
        waktuOrder: order.waktuOrder,
        kadaluarsa: order.kadaluarsa,
        catatanOrder: order.catatanOrder,
      );

      await firestoreService.clearCartAfterOrder(userId: user.uid);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/order-detail',
        (route) => false,
        arguments: order.orderId,
      );
    } catch (e) {
      debugPrint("Gagal submit order: $e");
      if (mounted) {
        _showMessage("Terjadi kesalahan saat memproses pesanan.");
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _generateKodePembayaran() {
    final kode = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
    return kode.toString().padLeft(6, '0');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildAddressSection() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.green),
        title: const Text(
          'Alamat Pengiriman',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle:
            pickupMethod == "Ambil Sendiri"
                ? const Text(
                  'Tidak diperlukan alamat',
                  style: TextStyle(color: Colors.grey),
                )
                : selectedAddress != null
                ? Text(
                  '${selectedAddress!.streetAddress}, ${selectedAddress!.district}, ${selectedAddress!.city}',
                  style: const TextStyle(fontSize: 14),
                )
                : const Text(
                  'Belum dipilih',
                  style: TextStyle(color: Colors.grey),
                ),
        trailing:
            pickupMethod == "Diantar" ? const Icon(Icons.chevron_right) : null,
        onTap: pickupMethod == "Diantar" ? _selectAddress : null,
      ),
    );
  }

  Widget _buildPickupDropdown() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.delivery_dining, color: Colors.green),
        title: const Text(
          "Metode Pengambilan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: DropdownButton<String>(
          value: pickupMethod,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(
              value: "Ambil Sendiri",
              child: Text("Ambil Sendiri"),
            ),
            DropdownMenuItem(value: "Diantar", child: Text("Diantar")),
          ],
          onChanged: (value) {
            if (value != null && mounted) {
              setState(() {
                pickupMethod = value;
                if (pickupMethod == "Ambil Sendiri") selectedAddress = null;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildItemList() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Daftar Pesanan",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.items.map((item) {
            final total = item.product.harga * item.quantity;
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:
                      item.product.gambarUrl.isNotEmpty
                          ? Image.network(
                            item.product.gambarUrl,
                            width: 55,
                            height: 55,
                            fit: BoxFit.cover,
                          )
                          : Container(
                            width: 55,
                            height: 55,
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                            ),
                          ),
                ),
                title: Text(
                  item.product.namaProduk,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'x${item.quantity}',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Text(
                  NumberFormat.currency(
                    locale: 'id_ID',
                    symbol: 'Rp ',
                  ).format(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCatatanOrderField() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: catatanOrderController,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: "Catatan untuk pesanan",
          labelStyle: TextStyle(color: Colors.green[700]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              NumberFormat.currency(
                locale: 'id_ID',
                symbol: 'Rp ',
              ).format(totalHarga),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            ElevatedButton.icon(
              onPressed: isLoading ? null : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white, // ✅ tulisan putih
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label:
                  isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Text(
                        "Buat Pesanan",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // ✅ putih juga di text
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text("Checkout"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildPickupDropdown(),
            _buildAddressSection(),
            _buildItemList(),
            _buildCatatanOrderField(),
            const SizedBox(height: 70),
          ],
        ),
      ),
      bottomNavigationBar: _buildSummary(),
    );
  }
}
