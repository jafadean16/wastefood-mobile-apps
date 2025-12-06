import 'package:cloud_firestore/cloud_firestore.dart';
import 'product.dart';

class CartItem {
  final Product product;
  final int quantity;


  /// Harga produk saat ditambahkan ke cart (harga final saat checkout)
  final double priceAtCheckout;

  CartItem({
    required this.product,
    required this.quantity,
    required this.priceAtCheckout,

  });

  /// Membuat CartItem dari Map (misal data Firestore)
  factory CartItem.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      throw ArgumentError('Map kosong, tidak bisa membuat CartItem');
    }

    // Parsing quantity, fallback ke 1 jika tidak valid
    final quantity = (map['jumlah'] is int)
        ? map['jumlah'] as int
        : int.tryParse(map['jumlah']?.toString() ?? '') ?? 1;

    // Parsing harga saat checkout
    double priceAtCheckout;
    if (map.containsKey('totalHarga')) {
      final priceValue = map['totalHarga'];
      if (priceValue is double) {
        priceAtCheckout = priceValue;
      } else if (priceValue is int) {
        priceAtCheckout = priceValue.toDouble();
      } else {
        priceAtCheckout = double.tryParse(priceValue?.toString() ?? '') ??
            (map['harga'] is int
                ? (map['harga'] as int).toDouble()
                : double.tryParse(map['harga']?.toString() ?? '') ?? 0.0);
      }
    } else if (map.containsKey('priceAtCheckout')) {
      final priceValue = map['priceAtCheckout'];
      if (priceValue is double) {
        priceAtCheckout = priceValue;
      } else if (priceValue is int) {
        priceAtCheckout = priceValue.toDouble();
      } else {
        priceAtCheckout = double.tryParse(priceValue?.toString() ?? '') ?? 0.0;
      }
    } else {
      // fallback ke harga produk jika kedua field tidak ada
      priceAtCheckout = (map['harga'] is int)
          ? (map['harga'] as int).toDouble()
          : double.tryParse(map['harga']?.toString() ?? '') ?? 0.0;
    }

    // Inject harga final ke product map agar konsisten
    final productMap = Map<String, dynamic>.from(map);
    productMap['harga'] = priceAtCheckout;

    return CartItem(
      product: Product.fromMap(productMap),
      quantity: quantity,
      priceAtCheckout: priceAtCheckout,
    );
  }

  /// Membuat CartItem dari DocumentSnapshot Firestore
  factory CartItem.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CartItem.fromMap(data);
  }

  /// Convert CartItem ke Map untuk simpan ke Firestore
  Map<String, dynamic> toMap() {
    final productMap = product.toMap();
    return {
      ...productMap,
      'jumlah': quantity,
      'totalHarga': priceAtCheckout,
    };
  }

  /// Membuat salinan CartItem dengan properti baru (immutable update)
  CartItem copyWith({
    Product? product,
    int? quantity,
    double? priceAtCheckout,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      priceAtCheckout: priceAtCheckout ?? this.priceAtCheckout,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          product == other.product &&
          quantity == other.quantity &&
          priceAtCheckout == other.priceAtCheckout;

  @override
  int get hashCode =>
      product.hashCode ^ quantity.hashCode ^ priceAtCheckout.hashCode;

  @override
  String toString() {
    return 'CartItem(product: $product, quantity: $quantity, priceAtCheckout: $priceAtCheckout)';
  }
}
