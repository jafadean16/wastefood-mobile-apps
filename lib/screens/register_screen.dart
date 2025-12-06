import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final ageController = TextEditingController();
  final locationController = TextEditingController();
  String gender = 'Laki-laki';
  bool isLoading = false;

  bool isLengthValid = false;
  bool isUppercaseValid = false;
  bool isNumberValid = false;
  bool isSpecialCharValid = false;

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    ageController.dispose();
    locationController.dispose();
    super.dispose();
  }

  void validatePassword(String value) {
    setState(() {
      isLengthValid = value.length >= 8;
      isUppercaseValid = value.contains(RegExp(r'[A-Z]'));
      isNumberValid = value.contains(RegExp(r'[0-9]'));
      isSpecialCharValid = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  Future<void> register() async {
    if (!isLengthValid ||
        !isUppercaseValid ||
        !isNumberValid ||
        !isSpecialCharValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password belum memenuhi semua kriteria')),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      final userCredential = await auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final userId = userCredential.user!.uid;

      await firestore.collection('users').doc(userId).set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'age': ageController.text.trim(),
        'gender': gender,
        'location': locationController.text.trim(),
        'roles': ['customer'],
        'createdAt': FieldValue.serverTimestamp(),

        // 🟢 Tambahan Presence
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registrasi Gagal: ${e.message}')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget passwordChecklist(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isValid ? Colors.green : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: isValid ? Colors.green.shade700 : Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  InputDecoration modernInputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.green),
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.green.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.person_add_alt_1, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              "Buat Akun Baru",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Daftar untuk mulai menggunakan aplikasi",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 40),

            // Input Fields
            TextField(
              controller: nameController,
              decoration: modernInputDecoration(
                "Nama Lengkap",
                Icons.person_outline,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: modernInputDecoration("Email", Icons.email_outlined),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              onChanged: validatePassword,
              decoration: modernInputDecoration("Password", Icons.lock_outline),
            ),
            const SizedBox(height: 10),

            // Checklist Password
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                passwordChecklist("Minimal 8 karakter", isLengthValid),
                passwordChecklist("Huruf kapital", isUppercaseValid),
                passwordChecklist("Angka", isNumberValid),
                passwordChecklist("Karakter khusus", isSpecialCharValid),
              ],
            ),

            const SizedBox(height: 16),
            TextField(
              controller: ageController,
              decoration: modernInputDecoration("Umur", Icons.cake_outlined),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: modernInputDecoration("Jenis Kelamin", Icons.wc),
              items:
                  ['Laki-laki', 'Perempuan'].map((gender) {
                    return DropdownMenuItem(value: gender, child: Text(gender));
                  }).toList(),
              onChanged: (value) => setState(() => gender = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: modernInputDecoration(
                "Lokasi",
                Icons.location_on_outlined,
              ),
            ),
            const SizedBox(height: 30),

            // Tombol Register
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: Colors.greenAccent.shade100,
                ),
                child:
                    isLoading
                        ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                        : const Text(
                          'Daftar Sekarang',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
