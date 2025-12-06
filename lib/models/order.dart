import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String idProduk;
  final String nama;
  final double harga; // harga per item
  final int jumlah;
  final String catatan;
  final String tokoId;

  double get totalHarga => harga * jumlah;

  OrderItem({
    required this.idProduk,
    required this.nama,
    required this.harga,
    required this.jumlah,
    required this.catatan, // tidak nullable, harus diisi
    required this.tokoId,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      throw ArgumentError('Map kosong, tidak bisa membuat OrderItem');
    }

    double parseHarga(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    int parseJumlah(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return OrderItem(
      idProduk: map['idProduk'] ?? '',
      nama: map['nama'] ?? '',
      harga: parseHarga(map['harga']),
      jumlah: parseJumlah(map['jumlah']),
      catatan: map.containsKey('catatan') && map['catatan'] is String ? map['catatan'] : '',
      tokoId: map['tokoId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idProduk': idProduk,
      'nama': nama,
      'harga': harga,
      'jumlah': jumlah,
      'catatan': catatan,
      'tokoId': tokoId,
    };
  }

  OrderItem copyWith({
    String? idProduk,
    String? nama,
    double? harga,
    int? jumlah,
    String? catatan,
    String? tokoId,
  }) {
    return OrderItem(
      idProduk: idProduk ?? this.idProduk,
      nama: nama ?? this.nama,
      harga: harga ?? this.harga,
      jumlah: jumlah ?? this.jumlah,
      catatan: catatan ?? this.catatan,
      tokoId: tokoId ?? this.tokoId,
    );
  }
}

class Order {
  final String orderId;
  final String userId;
  final String tokoId;
  final String lokasiId;
  final String metode;      // metode pembayaran, contoh: 'COD', 'Transfer'
  final String pengambilan; // 'Ambil Sendiri' atau 'Diantar'
  final String status;      // status order, contoh: 'menunggu', 'selesai', dll
  final String kodePembayaran;
  final List<OrderItem> items;
  final DateTime waktuOrder;
  final DateTime kadaluarsa;

  // tambahan 3 field
  final String alamatPengiriman; // alamat lengkap tujuan
  final String namaPembeli;      // nama pembeli / penerima
  final String catatanOrder;     // catatan khusus order level

  Order({
    required this.orderId,
    required this.userId,
    required this.tokoId,
    required this.lokasiId,
    required this.metode,
    required this.pengambilan,
    required this.status,
    required this.kodePembayaran,
    required this.items,
    required this.waktuOrder,
    required this.kadaluarsa,
    this.alamatPengiriman = '',
    this.namaPembeli = '',
    this.catatanOrder = '',
  });

  factory Order.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      throw ArgumentError('Map kosong, tidak bisa membuat Order');
    }

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return Order(
      orderId: map['orderId'] ?? '',
      userId: map['userId'] ?? '',
      tokoId: map['tokoId'] ?? '',
      lokasiId: map['lokasiId'] ?? '',
      metode: map['metode'] ?? '',
      pengambilan: map['pengambilan'] ?? '',
      status: map['status'] ?? '',
      kodePembayaran: map['kodePembayaran'] ?? '',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      waktuOrder: parseDate(map['waktuOrder']),
      kadaluarsa: parseDate(map['kadaluarsa']),
      alamatPengiriman: map['alamatPengiriman'] ?? '',
      namaPembeli: map['namaPembeli'] ?? '',
      catatanOrder: map.containsKey('catatanOrder') && map['catatanOrder'] is String ? map['catatanOrder'] : '',

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'userId': userId,
      'tokoId': tokoId,
      'lokasiId': lokasiId,
      'metode': metode,
      'pengambilan': pengambilan,
      'status': status,
      'kodePembayaran': kodePembayaran,
      'items': items.map((item) => item.toMap()).toList(),
      'waktuOrder': Timestamp.fromDate(waktuOrder),
      'kadaluarsa': Timestamp.fromDate(kadaluarsa),
      'alamatPengiriman': alamatPengiriman,
      'namaPembeli': namaPembeli,
      'catatanOrder': catatanOrder,
    };
  }

  Order copyWith({
    String? orderId,
    String? userId,
    String? tokoId,
    String? lokasiId,
    String? metode,
    String? pengambilan,
    String? status,
    String? kodePembayaran,
    List<OrderItem>? items,
    DateTime? waktuOrder,
    DateTime? kadaluarsa,
    String? alamatPengiriman,
    String? namaPembeli,
    String? catatanOrder,
  }) {
    return Order(
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      tokoId: tokoId ?? this.tokoId,
      lokasiId: lokasiId ?? this.lokasiId,
      metode: metode ?? this.metode,
      pengambilan: pengambilan ?? this.pengambilan,
      status: status ?? this.status,
      kodePembayaran: kodePembayaran ?? this.kodePembayaran,
      items: items ?? this.items,
      waktuOrder: waktuOrder ?? this.waktuOrder,
      kadaluarsa: kadaluarsa ?? this.kadaluarsa,
      alamatPengiriman: alamatPengiriman ?? this.alamatPengiriman,
      namaPembeli: namaPembeli ?? this.namaPembeli,
      catatanOrder: catatanOrder ?? this.catatanOrder,
    );
  }
}
