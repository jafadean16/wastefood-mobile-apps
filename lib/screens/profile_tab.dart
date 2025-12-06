import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? userData;
  Map<String, dynamic>? storeData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final userSnapshot =
            await _firestore.collection('users').doc(uid).get();
        final storeSnapshot =
            await _firestore.collection('toko').doc(uid).get();

        if (!mounted) return;

        setState(() {
          userData = userSnapshot.data();
          storeData = storeSnapshot.exists ? storeSnapshot.data() : null;
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching user/store data: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _changeAccount() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _navigateTo(String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  Widget _buildStoreStatus() {
    if (storeData == null) {
      return _profileItem(
        "Mulai Buka Toko",
        icon: Icons.storefront,
        color: Colors.green,
        onTap: () => _navigateTo('/store/add/welcome'),
      );
    }

    final status = storeData?['status'];
    switch (status) {
      case 'pending':
        return _profileItem(
          "Toko Sedang Diverifikasi",
          icon: Icons.pending_actions,
          color: Colors.orange,
          onTap: () => _navigateTo('/store/pending'),
        );
      case 'verified':
        return _profileItem(
          "Toko Saya",
          icon: Icons.store,
          color: Colors.green,
          onTap: () => _navigateTo('/store'),
        );
      default:
        return _profileItem(
          "Status Toko Tidak Diketahui",
          icon: Icons.help_outline,
          color: Colors.grey,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final String userInitial =
        (userData?['name'] != null && userData!['name'].toString().isNotEmpty)
            ? userData!['name'][0].toUpperCase()
            : 'U';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 40),
          // Header dengan animasi avatar
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 45,
                backgroundColor: Colors.green,
                child: Text(
                  userInitial,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              userData?['name'] ?? 'Pengguna',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Kartu menu
          _profileItem(
            "Akun Saya",
            icon: Icons.person_outline,
            color: Colors.green,
            onTap: () => _navigateTo('/profile/account'),
          ),
          _profileItem(
            "Keamanan Akun",
            icon: Icons.lock_outline,
            color: Colors.green,
            onTap: () => _navigateTo('/profile/security'),
          ),
          _profileItem(
            "Alamat",
            icon: Icons.location_on_outlined,
            color: Colors.green,
            onTap: () => _navigateTo('/profile/address'),
          ),
          _profileItem(
            "Pengaturan",
            icon: Icons.settings_outlined,
            color: Colors.green,
            onTap: () => _navigateTo('/profile/settings'),
          ),
          _profileItem(
            "Bantuan",
            icon: Icons.help_outline,
            color: Colors.green,
            onTap: () => _navigateTo('/profile/help'),
          ),

          const Divider(height: 40),
          _buildStoreStatus(),
          const SizedBox(height: 40),

          // Tombol aksi
          ElevatedButton.icon(
            onPressed: _changeAccount,
            icon: const Icon(Icons.switch_account),
            label: const Text("Ganti Akun"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _logout,
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _profileItem(
    String title, {
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
