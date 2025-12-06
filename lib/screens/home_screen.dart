import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Screens
import 'homepage_tab.dart';
import 'history_tab.dart';
import 'profile_tab.dart';
import 'package:wastefood/screens/cart/cart_page.dart';
import 'package:wastefood/screens/chat/chat_list_page.dart';
import 'package:wastefood/screens/profile/add_address_page.dart';
import 'package:wastefood/screens/store/store_detail_page.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;
  const HomeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  bool isLoadingNearby = false;
  List<Map<String, dynamic>> nearbyStores = [];

  final List<Widget> _pages = const [HomepageTab(), HistoryTab(), ProfileTab()];
  final List<String> _titles = ['Beranda', 'Riwayat', 'Profil'];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  // ============================================
  // 🔹 Fungsi lokasi & pencarian toko terdekat
  // ============================================

  Future<LatLng?> getUserLocation(String userId) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('lokasi')
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      final latitude = data['latitude'];
      final longitude = data['longitude'];
      if (latitude != null && longitude != null) {
        return LatLng(latitude, longitude);
      }
    }
    return null;
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> searchNearbyStores() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userLocation = await getUserLocation(userId);
    if (!mounted) return;

    if (userLocation == null) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Alamat Belum Tersedia'),
              content: const Text(
                'Anda belum menambahkan alamat. Tambahkan dulu agar bisa mencari toko terdekat.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddAddressPage()),
                    );
                  },
                  child: const Text('Tambah Alamat'),
                ),
              ],
            ),
      );
      return;
    }

    setState(() => isLoadingNearby = true);

    try {
      final tokoSnapshot =
          await FirebaseFirestore.instance.collection('toko').get();

      final tokoList =
          tokoSnapshot.docs
              .map((doc) {
                final data = doc.data();
                final jarak = calculateDistance(
                  userLocation.latitude,
                  userLocation.longitude,
                  data['latitude'],
                  data['longitude'],
                );
                return {'id': doc.id, 'data': data, 'jarak': jarak};
              })
              .where((toko) {
                final jarak = toko['jarak'] as double?;
                return jarak != null && jarak <= 10;
              })
              .toList();

      tokoList.sort(
        (a, b) => (a['jarak'] as double).compareTo(b['jarak'] as double),
      );

      if (!mounted) return;
      setState(() {
        nearbyStores = tokoList;
        isLoadingNearby = false;
      });

      if (tokoList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada toko dalam radius 10 km.")),
        );
      } else {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text("Toko Terdekat"),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: nearbyStores.length,
                    itemBuilder: (context, index) {
                      final toko = nearbyStores[index];
                      final data = toko['data'];
                      final jarak = toko['jarak'] as double;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(data['namaToko']),
                          subtitle: Text('${jarak.toStringAsFixed(2)} km'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => StoreDetailPage(
                                      tokoId: toko['id'],
                                      tokoNama: data['namaToko'],
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text("Tutup"),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal memuat toko: $e")));
      setState(() => isLoadingNearby = false);
    }
  }

  // ============================================
  // 🔹 Build UI utama
  // ============================================
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatListPage()),
              );
            },
          ),
          if (userId != null)
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('keranjang')
                      .doc(userId)
                      .collection('items')
                      .snapshots(),
              builder: (context, snapshot) {
                int totalItem = 0;
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final jumlah = data['jumlah'];
                    if (jumlah is int) totalItem += jumlah;
                  }
                }
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CartPage(),
                          ),
                        );
                      },
                    ),
                    if (totalItem > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$totalItem',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: SafeArea(child: _pages[_currentIndex]),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,

      floatingActionButton: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: isLoadingNearby ? 0.9 : 1,
        child: FloatingActionButton(
          backgroundColor: Colors.white,
          elevation: 6,
          onPressed: isLoadingNearby ? null : searchNearbyStores,
          child:
              isLoadingNearby
                  ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color:
                          Colors
                              .green, // warna loading tetap hijau biar kontras
                      strokeWidth: 2,
                    ),
                  )
                  : const Icon(
                    Icons.location_searching_rounded,
                    color:
                        Colors.green, // ikon hijau agar kontras di tombol putih
                    size: 28,
                  ),
        ),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Colors.green[800],
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Beranda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_rounded),
                label: 'Riwayat',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Model sederhana koordinat lokasi
class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}
