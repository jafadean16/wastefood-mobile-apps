import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_screen.dart';
import 'store_page.dart';

class StorePendingPage extends StatefulWidget {
  const StorePendingPage({super.key});

  @override
  State<StorePendingPage> createState() => _StorePendingPageState();
}

class _StorePendingPageState extends State<StorePendingPage>
    with SingleTickerProviderStateMixin {
  bool _isChecking = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // Inisialisasi controller DI SINI (initState selalu dipanggil sebelum build)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    // mulai forward animasi
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _isChecking = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'User tidak ditemukan.',
        );
      }

      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('toko')
              .doc(user.uid)
              .get();

      if (!docSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Data toko tidak ditemukan.',
        );
      }

      final isVerified = docSnapshot.data()?['isVerified'] == true;

      if (isVerified) {
        // transisi Fade ke StorePage
        navigator.pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 700),
            pageBuilder:
                (context, animation, secondaryAnimation) => FadeTransition(
                  opacity: animation,
                  child: const StorePage(),
                ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Verifikasi masih diproses. Silakan cek kembali nanti.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text("Terjadi kesalahan: ${e.toString()}"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _navigateToProfileTab() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder:
            (context, animation, secondaryAnimation) => FadeTransition(
              opacity: animation,
              child: const HomeScreen(initialTabIndex: 2),
            ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _navigateToProfileTab();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9F8),
        appBar: AppBar(
          title: const Text("Status Verifikasi"),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateToProfileTab,
          ),
        ),
        body: FadeTransition(
          opacity: _controller,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'verifIcon',
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade100.withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.hourglass_top,
                        size: 90,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    "Verifikasi dalam Proses",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Tim kami sedang memverifikasi data toko Anda.\nMohon tunggu beberapa saat.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 36),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child:
                        _isChecking
                            ? const CircularProgressIndicator(
                              color: Colors.green,
                            )
                            : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _checkVerificationStatus,
                                icon: const Icon(Icons.refresh),
                                label: const Text(
                                  "Cek Status",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
