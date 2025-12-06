import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wastefood/models/address.dart';
import 'package:wastefood/models/product.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final logger = Logger();

  // ====================== USER ======================
  Future<void> saveUserData(User user, String name) async {
    try {
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': user.email,
        'role': 'customer', // default role user baru
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Gagal menyimpan data user: $e');
    }
  }

  // ====================== ALAMAT ======================
  Future<List<Address>> getUserAddresses() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    try {
      final snapshot =
          await _db
              .collection('users')
              .doc(user.uid)
              .collection('lokasi')
              .get();

      return snapshot.docs
          .map((doc) => Address.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception("Gagal mengambil alamat: $e");
    }
  }

  Future<Address?> getPrimaryAddress() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    try {
      final query =
          await _db
              .collection('users')
              .doc(user.uid)
              .collection('lokasi')
              .where('utama', isEqualTo: true)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return Address.fromMap(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      throw Exception("Gagal mengambil alamat utama: $e");
    }
  }

  Future<Address?> getAddressById(String id) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    try {
      final doc =
          await _db
              .collection('users')
              .doc(user.uid)
              .collection('lokasi')
              .doc(id)
              .get();

      if (doc.exists) {
        return Address.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception("Gagal mengambil detail alamat: $e");
    }
  }

  Future<void> saveAddress(Address address) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    try {
      final ref = _db.collection('users').doc(user.uid).collection('lokasi');
      final docRef = (address.id.isEmpty) ? ref.doc() : ref.doc(address.id);

      if (address.isPrimary) {
        final allDocs = await ref.get();
        for (var doc in allDocs.docs) {
          await doc.reference.update({'utama': false});
        }
      }

      await docRef.set(address.toMap());
    } catch (e) {
      throw Exception("Gagal menyimpan alamat: $e");
    }
  }

  Future<void> updateAddress(Address address) async {
    final user = _auth.currentUser;
    if (user == null || address.id.isEmpty) {
      throw Exception("User atau alamat tidak valid");
    }

    try {
      final ref = _db.collection('users').doc(user.uid).collection('lokasi');

      if (address.isPrimary) {
        final allDocs = await ref.get();
        for (var doc in allDocs.docs) {
          await doc.reference.update({'utama': false});
        }
      }

      await ref.doc(address.id).update(address.toMap());
    } catch (e) {
      throw Exception("Gagal update alamat: $e");
    }
  }

  Future<void> deleteAddress(Address address) async {
    final user = _auth.currentUser;
    if (user == null || address.id.isEmpty) {
      throw Exception("User atau alamat tidak valid");
    }

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('lokasi')
          .doc(address.id)
          .delete();
    } catch (e) {
      throw Exception("Gagal menghapus alamat: $e");
    }
  }

  // ====================== TOKO ======================
  Future<void> saveStoreData(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    try {
      await _db.collection('toko').doc(user.uid).set({
        ...data,
        'uid': user.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Gagal menyimpan data toko: $e");
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getMyStore() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    try {
      return await _db.collection('toko').doc(user.uid).get();
    } catch (e) {
      throw Exception("Gagal mengambil data toko: $e");
    }
  }

  Future<String?> getStoreVerificationStatus() async {
    try {
      final store = await getMyStore();
      return store.data()?['status'] as String?;
    } catch (e) {
      throw Exception("Gagal cek status verifikasi: $e");
    }
  }

  // ====================== PRODUK ======================
  Future<void> saveProduct(Product product) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    try {
      final produkRef = _db.collection('produk').doc();
      final data = {
        ...product.toMap(),
        'produkId': produkRef.id,
        'penjualId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await produkRef.set(data);
      await _db
          .collection('toko')
          .doc(user.uid)
          .collection('produk')
          .doc(produkRef.id)
          .set(data);
    } catch (e) {
      throw Exception("Gagal menyimpan produk: $e");
    }
  }

  Future<void> updateProduct(
    String produkId,
    String tokoId,
    Map<String, dynamic> data,
  ) async {
    try {
      final produkRef = _db.collection('produk').doc(produkId);
      final tokoProdukRef = _db
          .collection('toko')
          .doc(tokoId)
          .collection('produk')
          .doc(produkId);

      await produkRef.update(data);
      await tokoProdukRef.update(data);
    } catch (e) {
      throw Exception("Gagal memperbarui produk: $e");
    }
  }

  Future<void> deleteProduct(String produkId, String tokoId) async {
    try {
      final produkRef = _db.collection('produk').doc(produkId);
      final tokoProdukRef = _db
          .collection('toko')
          .doc(tokoId)
          .collection('produk')
          .doc(produkId);

      await produkRef.delete();
      await tokoProdukRef.delete();
    } catch (e) {
      throw Exception("Gagal menghapus produk: $e");
    }
  }

  // ====================== KERANJANG ======================

  /// Tambah produk ke keranjang dengan validasi stok
  Future<void> addToCart(Product product, int qty) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    final parentCartDoc = _db.collection('keranjang').doc(user.uid);
    final cartItemRef = parentCartDoc.collection('items').doc(product.produkId);

    try {
      // Buat atau update data keranjang induk
      await parentCartDoc.set({
        'userId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final existingDoc = await cartItemRef.get();
      final existingQty =
          existingDoc.exists ? (existingDoc.data()?['jumlah'] ?? 0) as int : 0;
      final newQty = existingQty + qty;

      if (newQty > product.stok) {
        throw Exception("Jumlah melebihi stok tersedia (${product.stok})");
      }

      if (existingDoc.exists) {
        await cartItemRef.update({
          'jumlah': newQty,
          'totalHarga': product.harga * newQty,
          'gambarUrl': product.gambarUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await cartItemRef.set({
          'idProduk': product.produkId,
          'nama': product.namaProduk,
          'harga': product.harga,
          'jumlah': qty,
          'totalHarga': product.harga * qty,
          'tokoId': product.sellerId,
          'gambarUrl': product.gambarUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception("Gagal menambahkan ke keranjang: $e");
    }
  }

  /// Ambil semua item di keranjang beserta data produk
  Future<List<Map<String, dynamic>>> getCartItemsWithProductData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    try {
      final cartSnapshot =
          await _db
              .collection('keranjang')
              .doc(user.uid)
              .collection('items')
              .get();

      List<Map<String, dynamic>> results = [];

      for (var doc in cartSnapshot.docs) {
        final cartData = doc.data();
        final idProduk = cartData['idProduk'] as String?;
        final tokoId = cartData['tokoId'] as String?;

        if (idProduk == null || tokoId == null) {
          results.add({
            'cartDocId': doc.id,
            'cartData': cartData,
            'produkData': null,
          });
          continue;
        }

        final produkDoc =
            await _db
                .collection('toko')
                .doc(tokoId)
                .collection('produk')
                .doc(idProduk)
                .get();

        final produkData = produkDoc.exists ? produkDoc.data() : null;

        results.add({
          'cartDocId': doc.id,
          'cartData': cartData,
          'produkData': produkData,
        });
      }

      return results;
    } catch (e) {
      throw Exception("Gagal mengambil data keranjang: $e");
    }
  }

  /// Hapus item dari keranjang berdasarkan produkId
  Future<void> removeFromCart(String produkId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    try {
      await _db
          .collection('keranjang')
          .doc(user.uid)
          .collection('items')
          .doc(produkId)
          .delete();
    } catch (e) {
      throw Exception("Gagal menghapus item keranjang: $e");
    }
  }

  /// Hapus seluruh keranjang pengguna
  Future<void> deleteCart() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    try {
      final items =
          await _db
              .collection('keranjang')
              .doc(user.uid)
              .collection('items')
              .get();

      for (var doc in items.docs) {
        await doc.reference.delete();
      }

      await _db.collection('keranjang').doc(user.uid).delete();
    } catch (e) {
      throw Exception("Gagal menghapus semua isi keranjang: $e");
    }
  }

  /// Ambil jumlah item produk tertentu yang sudah ada di keranjang
  Future<int> getExistingCartQty(String productId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak ditemukan");

    try {
      final doc =
          await _db
              .collection('keranjang')
              .doc(user.uid)
              .collection('items')
              .doc(productId)
              .get();

      if (doc.exists) {
        return (doc.data()?['jumlah'] ?? 0) as int;
      } else {
        return 0;
      }
    } catch (e) {
      throw Exception("Gagal mengecek jumlah produk di keranjang: $e");
    }
  }

  // ====================== PESANAN ======================

  /// Generate ID pesanan unik berdasarkan timestamp
  String generateOrderId() {
    final now = DateTime.now();
    return 'WF${now.millisecondsSinceEpoch}';
  }

  /// Ambil stok global produk
  Future<int> getGlobalProdukStok(String produkId) async {
    final doc = await _db.collection('produk').doc(produkId).get();
    return (doc.data()?['stok'] ?? 0) as int;
  }

  /// Ambil stok produk di toko tertentu
  Future<int> getTokoProdukStok(String tokoId, String produkId) async {
    final doc =
        await _db
            .collection('toko')
            .doc(tokoId)
            .collection('produk')
            .doc(produkId)
            .get();
    return (doc.data()?['stok'] ?? 0) as int;
  }

  /// Update stok produk di koleksi toko/{tokoId}/produk/{produkId}
  Future<void> updateTokoProdukStok({
    required String tokoId,
    required String produkId,
    required int stok,
  }) async {
    await _db
        .collection('toko')
        .doc(tokoId)
        .collection('produk')
        .doc(produkId)
        .update({'stok': stok});
  }

  /// Update stok produk di koleksi global produk/{produkId}
  Future<void> updateGlobalProdukStok({
    required String produkId,
    required int stok,
  }) async {
    await _db.collection('produk').doc(produkId).update({'stok': stok});
  }

  /// Simpan pesanan baru dan kurangi stok produk secara atomik (transaksi)
  Future<void> saveOrder({
    required String orderId,
    required String userId,
    required String tokoId,
    required String? lokasiId,
    required List<Map<String, dynamic>> items,
    required String metode,
    required String pengambilan,
    required String catatanOrder, // ✅ tambahkan ini
    String? kodePembayaran,
    String status = 'menunggu',
    DateTime? waktuOrder,
    DateTime? kadaluarsa,
  }) async {
    final waktu = waktuOrder ?? DateTime.now();
    final expiredTime = kadaluarsa ?? waktu.add(const Duration(hours: 2));
    final pesananRef = _db.collection('pesanan').doc(orderId);

    try {
      // 1. Validasi stok untuk semua produk
      for (final item in items) {
        final produkId = item['produkId'] ?? item['idProduk'];
        final jumlah = item['jumlah'];

        if (produkId == null || jumlah == null) {
          throw Exception('Item pesanan tidak lengkap: $item');
        }

        final stokGlobal = await getGlobalProdukStok(produkId);
        final stokToko = await getTokoProdukStok(tokoId, produkId);

        if (stokGlobal < jumlah || stokToko < jumlah) {
          throw Exception('Stok tidak mencukupi untuk produk ID: $produkId');
        }
      }

      // 2. Transaksi untuk kurangi stok dan simpan pesanan
      await _db.runTransaction((transaction) async {
        for (final item in items) {
          final produkId = item['produkId'] ?? item['idProduk'];
          final jumlah = item['jumlah'];

          if (produkId == null || jumlah == null) continue;

          final produkRef = _db.collection('produk').doc(produkId);
          final produkTokoRef = _db
              .collection('toko')
              .doc(tokoId)
              .collection('produk')
              .doc(produkId);

          final produkSnapshot = await transaction.get(produkRef);
          final produkTokoSnapshot = await transaction.get(produkTokoRef);

          final stokGlobal = (produkSnapshot.data()?['stok'] ?? 0) as int;
          final stokToko = (produkTokoSnapshot.data()?['stok'] ?? 0) as int;

          if (stokGlobal < jumlah || stokToko < jumlah) {
            throw Exception(
              'Stok tidak mencukupi saat update produk ID: $produkId',
            );
          }

          transaction.update(produkRef, {'stok': stokGlobal - jumlah});
          transaction.update(produkTokoRef, {'stok': stokToko - jumlah});
        }

        // Simpan data pesanan
        transaction.set(pesananRef, {
          'orderId': orderId,
          'userId': userId,
          'tokoId': tokoId,
          'lokasiId': lokasiId ?? '',
          'items': items,
          'metode': metode,
          'pengambilan': pengambilan,
          'catatanOrder': catatanOrder, // ✅ simpan di Firestore
          'kodePembayaran': kodePembayaran ?? '',
          'status': status,
          'waktuOrder': waktu,
          'kadaluarsa': expiredTime,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // 3. Simpan ke koleksi kodePembayaran (jika ada kode)
      if (kodePembayaran != null && kodePembayaran.isNotEmpty) {
        final kodeRef = _db.collection('kodePembayaran').doc(kodePembayaran);
        await kodeRef.set({
          'orderId': orderId,
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. Hapus keranjang
      await clearCartAfterOrder(userId: userId);
    } catch (e, stack) {
      logger.e('Gagal menyimpan pesanan', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Hapus semua item dari keranjang setelah order disimpan
  Future<void> clearCartAfterOrder({required String userId}) async {
    final cartRef = _db.collection('keranjang').doc(userId).collection('items');
    final snapshot = await cartRef.get();

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    // Optional: hapus dokumen induk keranjang
    await _db.collection('keranjang').doc(userId).delete().catchError((_) {});
  }

  /// Update beberapa field di pesanan
  Future<void> updateOrder(
    String orderId,
    Map<String, dynamic> dataToUpdate,
  ) async {
    try {
      dataToUpdate['updatedAt'] = FieldValue.serverTimestamp();
      await _db.collection('pesanan').doc(orderId).update(dataToUpdate);
    } catch (e) {
      throw Exception('Gagal update pesanan: $e');
    }
  }

  Future<void> batalkanPesananDanRestoreStok(String orderId) async {
    final orderRef = _db.collection('pesanan').doc(orderId);
    final orderSnapshot = await orderRef.get();
    if (!orderSnapshot.exists) return;

    final data = orderSnapshot.data()!;
    final status = data['status'];
    if (status != 'menunggu') return;

    final tokoId = data['tokoId'];
    final items = List<Map<String, dynamic>>.from(data['items']);

    // Ambil semua snapshot produk dulu (sebelum transaksi)
    final produkRefs =
        items.map((item) {
          final id = item['produkId'] ?? item['idProduk'];
          return _db.collection('produk').doc(id);
        }).toList();

    final produkTokoRefs =
        items.map((item) {
          final id = item['produkId'] ?? item['idProduk'];
          return _db
              .collection('toko')
              .doc(tokoId)
              .collection('produk')
              .doc(id);
        }).toList();

    final produkSnapshots = await Future.wait(
      produkRefs.map((ref) => ref.get()),
    );
    final produkTokoSnapshots = await Future.wait(
      produkTokoRefs.map((ref) => ref.get()),
    );

    await _db.runTransaction((transaction) async {
      transaction.update(orderRef, {'status': 'dibatalkan'});

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final jumlah = item['jumlah'] ?? 0;

        final produkRef = produkRefs[i];
        final produkTokoRef = produkTokoRefs[i];

        final produkSnapshot = produkSnapshots[i];
        final produkTokoSnapshot = produkTokoSnapshots[i];

        final stokGlobal = (produkSnapshot.data()?['stok'] ?? 0) as int;
        final stokToko = (produkTokoSnapshot.data()?['stok'] ?? 0) as int;

        transaction.update(produkRef, {'stok': stokGlobal + jumlah});
        transaction.update(produkTokoRef, {'stok': stokToko + jumlah});
      }
    });
  }

  /// Ambil stream pesanan berdasarkan user ID
  Stream<List<Map<String, dynamic>>> getOrdersByUser(String userId) {
    return _db
        .collection('pesanan')
        .where('userId', isEqualTo: userId)
        .orderBy('waktuOrder', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Ambil stream pesanan berdasarkan toko ID
  Stream<List<Map<String, dynamic>>> getOrdersByToko(String tokoId) {
    return _db
        .collection('pesanan')
        .where('tokoId', isEqualTo: tokoId)
        .orderBy('waktuOrder', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Ambil detail pesanan berdasarkan orderId
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    try {
      final doc = await _db.collection('pesanan').doc(orderId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      throw Exception('Gagal mengambil detail pesanan: $e');
    }
  }

  // ====================== REVIEW (REVISI: Subkoleksi) ======================

  // ------------------ REVIEW PRODUK ------------------

  // Simpan review produk
  Future<void> saveReviewProduk({
    required String produkId,
    required String userId,
    required String orderId,
    required int rating,
    required String komentar,
  }) async {
    try {
      final reviewRef =
          _db.collection('produk').doc(produkId).collection('reviews').doc();

      await reviewRef.set({
        'reviewId': reviewRef.id,
        'produkId': produkId,
        'userId': userId,
        'orderId': orderId,
        'rating': rating,
        'komentar': komentar,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Gagal menyimpan review produk: $e");
    }
  }

  // Ambil semua review produk
  Future<List<Map<String, dynamic>>> getReviewsProduk(String produkId) async {
    try {
      final snapshot =
          await _db
              .collection('produk')
              .doc(produkId)
              .collection('reviews')
              .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception("Gagal mengambil review produk: $e");
    }
  }

  // Update review produk
  Future<void> updateReviewProduk({
    required String produkId,
    required String reviewId,
    int? rating,
    String? komentar,
  }) async {
    try {
      final ref = _db
          .collection('produk')
          .doc(produkId)
          .collection('reviews')
          .doc(reviewId);

      Map<String, dynamic> data = {};
      if (rating != null) data['rating'] = rating;
      if (komentar != null) data['komentar'] = komentar;
      data['updatedAt'] = FieldValue.serverTimestamp();

      if (data.isNotEmpty) {
        await ref.update(data);
      }
    } catch (e) {
      throw Exception("Gagal update review produk: $e");
    }
  }

  // Hapus review produk
  Future<void> deleteReviewProduk({
    required String produkId,
    required String reviewId,
  }) async {
    try {
      await _db
          .collection('produk')
          .doc(produkId)
          .collection('reviews')
          .doc(reviewId)
          .delete();
    } catch (e) {
      throw Exception("Gagal menghapus review produk: $e");
    }
  }

  // ------------------ REVIEW TOKO ------------------

  // Simpan review toko
  Future<void> saveReviewToko({
    required String tokoId,
    required String userId,
    required String orderId,
    required int rating,
    required String komentar,
  }) async {
    try {
      final reviewRef =
          _db.collection('toko').doc(tokoId).collection('reviews').doc();

      await reviewRef.set({
        'reviewId': reviewRef.id,
        'tokoId': tokoId,
        'userId': userId,
        'orderId': orderId,
        'rating': rating,
        'komentar': komentar,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Gagal menyimpan review toko: $e");
    }
  }

  // Ambil semua review toko
  Future<List<Map<String, dynamic>>> getReviewsToko(String tokoId) async {
    try {
      final snapshot =
          await _db.collection('toko').doc(tokoId).collection('reviews').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception("Gagal mengambil review toko: $e");
    }
  }

  // Update review toko
  Future<void> updateReviewToko({
    required String tokoId,
    required String reviewId,
    int? rating,
    String? komentar,
  }) async {
    try {
      final ref = _db
          .collection('toko')
          .doc(tokoId)
          .collection('reviews')
          .doc(reviewId);

      Map<String, dynamic> data = {};
      if (rating != null) data['rating'] = rating;
      if (komentar != null) data['komentar'] = komentar;
      data['updatedAt'] = FieldValue.serverTimestamp();

      if (data.isNotEmpty) {
        await ref.update(data);
      }
    } catch (e) {
      throw Exception("Gagal update review toko: $e");
    }
  }

  // Hapus review toko
  Future<void> deleteReviewToko({
    required String tokoId,
    required String reviewId,
  }) async {
    try {
      await _db
          .collection('toko')
          .doc(tokoId)
          .collection('reviews')
          .doc(reviewId)
          .delete();
    } catch (e) {
      throw Exception("Gagal menghapus review toko: $e");
    }
  }

  // Cek apakah user sudah review produk tertentu
  Future<bool> hasReviewedProduk(String produkId, String userId) async {
    final snapshot =
        await _db
            .collection('produk')
            .doc(produkId)
            .collection('reviews')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();

    return snapshot.docs.isNotEmpty;
  }

  // Cek apakah user sudah review toko tertentu
  Future<bool> hasReviewedToko(String tokoId, String userId) async {
    final snapshot =
        await _db
            .collection('toko')
            .doc(tokoId)
            .collection('reviews')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();

    return snapshot.docs.isNotEmpty;
  }

  ////CHAT/////
  /// 🔹 Generate chatId unik berdasarkan user & toko
  String generateChatId(String userId, String tokoId) {
    return '${userId}_$tokoId';
  }

  /// 🔹 Kirim pesan + buat / update metadata chat
  Future<void> sendMessage({
    required String userId,
    required String tokoId,
    required String senderId,
    required String message,
  }) async {
    final chatId = generateChatId(userId, tokoId);
    final chatRef = _db.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final timestamp = Timestamp.now();

    // Pastikan dokumen chat selalu ada atau diperbarui
    await chatRef.set({
      'userId': userId,
      'tokoId': tokoId,
      'lastMessage': message,
      'lastTimestamp': timestamp,
    }, SetOptions(merge: true));

    // Simpan pesan ke subkoleksi messages
    await messageRef.set({
      'senderId': senderId,
      'message': message,
      'timestamp': timestamp,
      'seen': false,
    });
  }

  /// 🔹 Ambil pesan (fix: biar muncul realtime walau chat baru)
  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    final chatRef = _db.collection('chats').doc(chatId);

    // Dengarkan perubahan di dokumen utama dulu
    return chatRef.snapshots().asyncExpand((chatSnapshot) {
      // Kalau chat belum ada → kirim stream kosong (biar UI gak error)
      if (!chatSnapshot.exists) {
        return Stream.value([]);
      }

      // Kalau sudah ada, dengarkan pesan-pesan di subkoleksi messages
      return chatRef
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    });
  }

  /// 🔹 Ambil semua chat user (baik sebagai userId atau tokoId)
  Stream<List<Map<String, dynamic>>> getUserChats(String currentUserId) {
    final userChatsStream =
        _db
            .collection('chats')
            .where('userId', isEqualTo: currentUserId)
            .snapshots();

    final tokoChatsStream =
        _db
            .collection('chats')
            .where('tokoId', isEqualTo: currentUserId)
            .snapshots();

    // Gabungkan dua stream agar user bisa melihat dua sisi (user/toko)
    return CombineLatestStream.list([userChatsStream, tokoChatsStream]).map((
      snapshots,
    ) {
      final allDocs = [...snapshots[0].docs, ...snapshots[1].docs];

      // Urutkan dari yang terbaru
      allDocs.sort((a, b) {
        final timeA = a['lastTimestamp'] ?? Timestamp(0, 0);
        final timeB = b['lastTimestamp'] ?? Timestamp(0, 0);
        return (timeB as Timestamp).compareTo(timeA as Timestamp);
      });

      // Masukkan chatId ke hasil data
      return allDocs.map((doc) {
        final data = doc.data();
        data['chatId'] = doc.id;
        return data;
      }).toList();
    });
  }

  // ============================================================
  //  🔥 FCM TOKEN MANAGEMENT
  // ============================================================

  /// Save new token (multi-device supported)
  Future<void> saveFcmToken(String userId, String token) async {
    try {
      await _db.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
      logger.i("FCM token saved");
    } catch (e) {
      logger.e("Error saving FCM token", error: e);
    }
  }

  /// Remove token (on logout)
  Future<void> removeFcmToken(String userId, String token) async {
    try {
      await _db.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
      logger.i("FCM token removed");
    } catch (e) {
      logger.e("Error removing FCM token", error: e);
    }
  }

  /// Get all user FCM tokens
  Future<List<String>> getUserTokens(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      return List<String>.from(doc.data()?['fcmTokens'] ?? []);
    } catch (e) {
      logger.e("Error fetching user tokens", error: e);
      return [];
    }
  }

  /// Handle token refresh
  Future<void> updateUserToken(String userId, String newToken) async {
    try {
      final userRef = _db.collection('users').doc(userId);
      final doc = await userRef.get();

      List oldTokens = doc.data()?['fcmTokens'] ?? [];

      if (!oldTokens.contains(newToken)) {
        await userRef.update({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
        });
      }

      logger.i("FCM token updated");
    } catch (e) {
      logger.e("Error updating FCM token", error: e);
    }
  }

  // ============================================================
  //  🔥 UPDATE PRODUCT (EDIT PRODUK SELLER)
  // ============================================================

  Future<void> sendStockUpdateNotifications(String productId) async {
    try {
      // 1. Ambil daftar watchers
      final watcherIds = await getProductWatchers(productId);

      logger.i("Watcher found: ${watcherIds.length}");

      // 2. Kirim notif ke masing-masing watcher
      for (var userId in watcherIds) {
        await addNotification(
          userId: userId,
          title: "Stok Diperbarui!",
          message: "Produk yang kamu ikuti sudah update stok!",
        );

        logger.i("Notifikasi terkirim ke $userId");
      }
    } catch (e) {
      logger.e("❌ Error sending stock update notifications", error: e);
    }
  }

  // ============================================================
  //  🔥 GET WATCHERS (customer yang follow produk)
  // ============================================================

  Future<List<String>> getProductWatchers(String productId) async {
    try {
      final snapshot =
          await _db
              .collection('products')
              .doc(productId)
              .collection('watchers')
              .get();

      final List<String> watchers = [];

      for (var doc in snapshot.docs) {
        if (doc.id.isNotEmpty) watchers.add(doc.id);
      }

      logger.i("Watcher found: ${watchers.length}");
      return watchers;
    } catch (e) {
      logger.e("❌ Error fetching watchers", error: e);
      return [];
    }
  }

  // ============================================================
  //  🔥 NOTIFICATION FIRESTORE (untuk Notification Page)
  // ============================================================

  /// Save notification log
  Future<void> addNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      await _db
          .collection('notifications')
          .doc(userId)
          .collection('user_notifications')
          .add({
            "title": title,
            "message": message,
            "createdAt": FieldValue.serverTimestamp(),
            "read": false,
          });

      logger.i("✔️ Notification saved for user $userId");
    } catch (e) {
      logger.e("❌ Error saving notification", error: e);
    }
  }

  /// Reader for NotificationPage
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _db
        .collection("notifications")
        .doc(userId)
        .collection("user_notifications")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  /// Mark as read
  Future<void> markNotificationAsRead({
    required String userId,
    required String notifId,
  }) async {
    try {
      await _db
          .collection("notifications")
          .doc(userId)
          .collection("user_notifications")
          .doc(notifId)
          .update({"read": true});

      logger.i("✔️ Notification $notifId marked as read");
    } catch (e) {
      logger.e("❌ Error marking notification read", error: e);
    }
  }
}
