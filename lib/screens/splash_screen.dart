import 'package:flutter/material.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool showAnimation = false;

  @override
  void initState() {
    super.initState();
    _startSplashSequence();
  }

  /// 🌿 Jalankan urutan animasi + cek login otomatis
  Future<void> _startSplashSequence() async {
    // Tampilkan logo dulu 2 detik
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => showAnimation = true);

    // Lanjut tampilkan animasi 3 detik
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Cek status login Firebase
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // ✅ Sudah login → langsung ke Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // 🔐 Belum login → ke Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade100,
      body: Center(
        child:
            showAnimation
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/leaf_loading.json',
                      width: 180,
                      height: 180,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Second Chance for Great Food',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
                : Image.asset('assets/logo.png', width: 160, height: 160),
      ),
    );
  }
}
