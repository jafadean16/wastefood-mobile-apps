import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class OrderConfirmationPage extends StatefulWidget {
  const OrderConfirmationPage({super.key});

  @override
  State<OrderConfirmationPage> createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  final TextEditingController _kodeController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _orderData;
  String? _currentOrderId;

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _kodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrderData(String kode) async {
    if (kode.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _orderData = null;
      _currentOrderId = null;
    });

    try {
      // Step 1: Ambil dokumen dari kodePembayaran
      final lookupSnapshot =
          await FirebaseFirestore.instance
              .collection('kodePembayaran')
              .doc(kode)
              .get();

      if (!lookupSnapshot.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kode pembayaran tidak ditemukan')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final orderId = lookupSnapshot.data()?['orderId'];
      if (orderId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data orderId tidak ditemukan dalam lookup'),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Step 2: Ambil dokumen dari koleksi pesanan berdasarkan orderId
      final orderSnapshot =
          await FirebaseFirestore.instance
              .collection('pesanan')
              .doc(orderId)
              .get();

      if (!orderSnapshot.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesanan tidak ditemukan')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final data = orderSnapshot.data()!;
      final items = (data['items'] as List<dynamic>?) ?? [];
      final total = items
          .map<int>((item) {
            final harga = item['price'] ?? item['harga'] ?? 0;
            final jumlah =
                item['quantity'] ?? item['jumlah'] ?? item['qty'] ?? 0;
            return (harga * jumlah).toInt();
          })
          .fold(0, (a, b) => a + b);

      String customerName = '-';
      if (data['userId'] != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(data['userId'])
                .get();
        if (userDoc.exists) {
          customerName = userDoc.data()?['name'] ?? '-';
        }
      }

      if (!mounted) return;
      setState(() {
        _orderData = {
          ...data,
          'calculatedTotal': total,
          'customerName': customerName,
        };
        _currentOrderId = orderId;
        _kodeController.text = kode;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data pesanan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _konfirmasiPesanan() async {
    if (_currentOrderId == null || _orderData == null) return;

    final status = _orderData!['status'] ?? '';
    if (status == 'berhasil') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan sudah dikonfirmasi')),
      );
      return;
    } else if (status == 'dibatalkan') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pesanan sudah dibatalkan')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Konfirmasi Pesanan'),
            content: const Text(
              'Apakah Anda yakin ingin mengonfirmasi pesanan ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ya'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('pesanan')
          .doc(_currentOrderId)
          .update({
            'status': 'berhasil',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan berhasil dikonfirmasi')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengonfirmasi pesanan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _bukaScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: MobileScanner(
              controller: MobileScannerController(
                detectionSpeed: DetectionSpeed.normal,
                facing: CameraFacing.back,
              ),
              onDetect: (BarcodeCapture capture) async {
                final List<Barcode> barcodes = capture.barcodes;

                for (final barcode in barcodes) {
                  final kode = barcode.rawValue;
                  if (kode != null) {
                    Navigator.pop(context);
                    await _fetchOrderData(kode);
                    break; // berhenti setelah dapet satu kode
                  }
                }
              },
            ),
          ),
    );
  }

  Widget _buildOrderDetails() {
    if (_orderData == null) return const SizedBox.shrink();

    final customerName = _orderData!['customerName'] ?? '-';
    final kodePembayaran = _orderData!['kodePembayaran'] ?? '-';
    final totalHarga = _orderData!['calculatedTotal'] ?? 0;
    final items = _orderData!['items'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID Pesanan: $_currentOrderId',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Kode Pembayaran: $kodePembayaran'),
            const SizedBox(height: 8),
            Text('Nama Pembeli: $customerName'),
            const SizedBox(height: 8),
            const Text(
              'Daftar Produk:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...items.map((item) {
              final productName =
                  item['productName'] ?? item['nama'] ?? 'Produk';
              final quantity =
                  item['quantity'] ?? item['jumlah'] ?? item['qty'] ?? 0;
              final price = item['price'] ?? item['harga'] ?? 0;
              final subtotal = price * quantity;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('$productName x $quantity')),
                    Text(_currencyFormat.format(subtotal)),
                  ],
                ),
              );
            }),
            const Divider(),
            Text(
              'Total Harga: ${_currencyFormat.format(totalHarga)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed:
                  (_isLoading || _orderData == null)
                      ? null
                      : _konfirmasiPesanan,

              icon:
                  _isLoading
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white, // ⬅️ warna loading putih
                        ),
                      )
                      : const Icon(
                        Icons.check,
                        color: Colors.white, // ⬅️ warna icon putih
                      ),

              label: Text(
                _isLoading ? 'Memproses...' : 'Konfirmasi Pesanan',
                style: const TextStyle(
                  color: Colors.white, // ⬅️ teks putih
                  fontWeight: FontWeight.bold,
                ),
              ),

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // ⬅️ tombol hijau
                padding: const EdgeInsets.symmetric(vertical: 14),
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
      appBar: AppBar(
        title: const Text('Konfirmasi Pesanan'),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor:
            Colors.white, // ✅ ini membuat teks & panah back jadi putih
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Masukkan Kode Pembayaran atau Scan QR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _kodeController,
                decoration: InputDecoration(
                  labelText: 'Kode Pembayaran',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (value) async {
                  final kode = value.trim();
                  if (kode.isNotEmpty) {
                    await _fetchOrderData(kode);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kode pembayaran tidak boleh kosong'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isLoading
                              ? null
                              : () async {
                                final kode = _kodeController.text.trim();
                                if (kode.isNotEmpty) {
                                  await _fetchOrderData(kode);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Kode pembayaran tidak boleh kosong',
                                      ),
                                    ),
                                  );
                                }
                              },
                      icon:
                          _isLoading
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(
                                Icons.search,
                                color: Colors.white,
                              ), // ikon putih
                      label: Text(
                        _isLoading ? 'Mencari...' : 'Cari Pesanan',
                        style: const TextStyle(
                          color: Colors.white,
                        ), // teks putih
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _bukaScanner,
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                    ), // ikon putih
                    label: const Text(
                      'Scan QR',
                      style: TextStyle(color: Colors.white),
                    ), // teks putih
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(child: _buildOrderDetails()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
