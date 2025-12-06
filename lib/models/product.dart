import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String produkId;
  final String namaProduk;
  final String deskripsi;
  final double harga;
  final int stok;
  final String gambarUrl;
  final String kategori;
  final bool isAvailable;
  final DateTime createdAt;  // ubah ke DateTime
  final DateTime updatedAt;  // ubah ke DateTime
  final String tokoId;
  final String tokoNama;
  final String sellerId;

  Product({
    required this.produkId,
    required this.namaProduk,
    required this.deskripsi,
    required this.harga,
    required this.stok,
    required this.gambarUrl,
    required this.kategori,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
    required this.tokoId,
    required this.tokoNama,
    required this.sellerId,
  });

  /// Convert Product instance to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'produkId': produkId,
      'namaProduk': namaProduk,
      'deskripsi': deskripsi,
      'harga': harga,
      'stok': stok,
      'gambarUrl': gambarUrl,
      'kategori': kategori,
      'isAvailable': isAvailable,
      // Convert DateTime ke Timestamp sebelum simpan ke Firestore
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'tokoId': tokoId,
      'tokoNama': tokoNama,
      'sellerId': sellerId,
    };
  }

  /// Create Product instance from Map (e.g. Firestore document data)
  factory Product.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    double parseHarga(dynamic value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseStok(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      return 0;
    }

    bool parseIsAvailable(dynamic value) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return true;
    }

    return Product(
      produkId: map['produkId'] ?? '',
      namaProduk: map['namaProduk'] ?? '',
      deskripsi: map['deskripsi'] ?? '',
      harga: parseHarga(map['harga']),
      stok: parseStok(map['stok']),
      gambarUrl: map['gambarUrl'] ?? '',
      kategori: map['kategori'] ?? '',
      isAvailable: parseIsAvailable(map['isAvailable']),
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
      tokoId: map['tokoId'] ?? '',
      tokoNama: map['tokoNama'] ?? '',
      sellerId: map['sellerId'] ?? '',
    );
  }

  /// Create Product instance from Firestore DocumentSnapshot
  factory Product.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Product.fromMap(data);
  }

  /// Return a copy of Product with optional new values
  Product copyWith({
    String? produkId,
    String? namaProduk,
    String? deskripsi,
    double? harga,
    int? stok,
    String? gambarUrl,
    String? kategori,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? tokoId,
    String? tokoNama,
    String? sellerId,
  }) {
    return Product(
      produkId: produkId ?? this.produkId,
      namaProduk: namaProduk ?? this.namaProduk,
      deskripsi: deskripsi ?? this.deskripsi,
      harga: harga ?? this.harga,
      stok: stok ?? this.stok,
      gambarUrl: gambarUrl ?? this.gambarUrl,
      kategori: kategori ?? this.kategori,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tokoId: tokoId ?? this.tokoId,
      tokoNama: tokoNama ?? this.tokoNama,
      sellerId: sellerId ?? this.sellerId,
    );
  }

  /// Format harga to Rupiah string with thousand separator, e.g. "Rp12.000"
  String get formattedHarga {
    final priceStr = harga.toStringAsFixed(0);
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final formatted = priceStr.replaceAllMapped(reg, (match) => '.');
    return 'Rp$formatted';
  }
}
