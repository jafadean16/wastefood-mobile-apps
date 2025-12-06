import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StoreFinancePage extends StatefulWidget {
  final String tokoId;
  final String userUid;

  const StoreFinancePage({
    super.key,
    required this.tokoId,
    required this.userUid,
  });

  @override
  StoreFinancePageState createState() => StoreFinancePageState();
}

class StoreFinancePageState extends State<StoreFinancePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _calculateFinance() async {
    if (widget.tokoId.isEmpty || widget.userUid.isEmpty) {
      throw Exception('Data user atau toko tidak lengkap');
    }

    try {
      final now = DateTime.now();
      final awalBulan = DateTime(now.year, now.month, 1);
      final awalTahun = DateTime(now.year, 1, 1);

      final snapshot =
          await _firestore
              .collection('pesanan')
              .where('tokoId', isEqualTo: widget.tokoId)
              .where('status', whereIn: ['selesai', 'berhasil']) // fleksibel
              .get();

      int totalIncome = 0;
      int monthlyIncome = 0;
      int yearlyIncome = 0;
      int totalOrders = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data();

        final waktuOrder = data['waktuOrder'];
        if (waktuOrder is! Timestamp) continue;

        final DateTime orderDate = waktuOrder.toDate();

        // Hitung total bayar dari items
        final List<dynamic> items = data['items'] ?? [];
        int bayar = 0;

        for (var item in items) {
          final hargaRaw = item['harga'] ?? 0;
          final jumlahRaw = item['jumlah'] ?? 1;

          // konversi aman int/double/string → int
          final harga =
              (hargaRaw is int)
                  ? hargaRaw
                  : (hargaRaw is double)
                  ? hargaRaw.toInt()
                  : int.tryParse(hargaRaw.toString()) ?? 0;

          final jumlah =
              (jumlahRaw is int)
                  ? jumlahRaw
                  : (jumlahRaw is double)
                  ? jumlahRaw.toInt()
                  : int.tryParse(jumlahRaw.toString()) ?? 1;

          bayar += harga * jumlah;
        }

        totalIncome += bayar;
        if (!orderDate.isBefore(awalBulan)) {
          monthlyIncome += bayar;
        }
        if (!orderDate.isBefore(awalTahun)) {
          yearlyIncome += bayar;
        }
      }

      return {
        'totalIncome': totalIncome,
        'monthlyIncome': monthlyIncome,
        'yearlyIncome': yearlyIncome,
        'totalOrders': totalOrders,
      };
    } catch (e) {
      debugPrint('Error calculating finance: $e');
      throw Exception('Gagal memuat data keuangan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isValid = widget.tokoId.isNotEmpty && widget.userUid.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keuangan Toko'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kembali',
        ),
      ),
      body:
          !isValid
              ? const Center(child: Text('Data user atau toko tidak lengkap'))
              : FutureBuilder<Map<String, dynamic>>(
                future: _calculateFinance(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }

                  final data = snapshot.data ?? {};

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCard(
                          'Total Pendapatan',
                          _formatCurrency(data['totalIncome'] ?? 0),
                          Colors.green,
                        ),
                        const SizedBox(height: 12),
                        _buildCard(
                          'Pendapatan Bulan Ini',
                          _formatCurrency(data['monthlyIncome'] ?? 0),
                          Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _buildCard(
                          'Pendapatan Tahun Ini',
                          _formatCurrency(data['yearlyIncome'] ?? 0),
                          Colors.teal,
                        ),
                        const SizedBox(height: 12),
                        _buildCard(
                          'Total Pesanan Selesai',
                          '${data['totalOrders'] ?? 0}',
                          Colors.orange,
                        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(int number) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }
}
