import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/cloudinary_service.dart';
import 'store_pending_page.dart';

class StoreVerificationPage extends StatefulWidget {
  final Map<String, dynamic> storeData;

  const StoreVerificationPage({super.key, required this.storeData});

  @override
  State<StoreVerificationPage> createState() => _StoreVerificationPageState();
}

class _StoreVerificationPageState extends State<StoreVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nikController = TextEditingController();
  final _nameController = TextEditingController();

  Uint8List? _ktpImageBytes;
  Uint8List? _selfieImageBytes;
  bool _isLoading = false;

  @override
  void dispose() {
    _nikController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _formKey.currentState?.validate() == true &&
        _ktpImageBytes != null &&
        _selfieImageBytes != null;
  }

  Future<void> _pickImage({required bool isKtp}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        if (isKtp) {
          _ktpImageBytes = bytes;
        } else {
          _selfieImageBytes = bytes;
        }
      });
    }
  }

  Future<void> _submitVerification() async {
    if (!_isFormValid) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User tidak ditemukan. Silakan login ulang.');
      }

      final ktpUrl = await CloudinaryService.uploadImageToCloudinary(
        _ktpImageBytes!,
        'ktp_${user.uid}',
      );

      final selfieUrl = await CloudinaryService.uploadImageToCloudinary(
        _selfieImageBytes!,
        'selfie_${user.uid}',
      );

      final storeData = {
        ...widget.storeData,
        'uid': user.uid,
        'nik': _nikController.text.trim(),
        'nama': _nameController.text.trim(),
        'ktpUrl': ktpUrl,
        'selfieUrl': selfieUrl,
        'isVerified': false,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('toko')
          .doc(user.uid)
          .set(storeData);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StorePendingPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim data: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildUploadTile({
    required String title,
    required Uint8List? imageBytes,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: title,
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.green.shade50,
                backgroundImage:
                    imageBytes != null ? MemoryImage(imageBytes) : null,
                child:
                    imageBytes == null
                        ? Icon(
                          Icons.upload_rounded,
                          color: Colors.green.shade700,
                          size: 30,
                        )
                        : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                imageBytes != null ? 'Foto berhasil diunggah ✅' : title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: imageBytes != null ? Colors.black87 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // tambahkan ini
      appBar: AppBar(
        title: const Text('Verifikasi Toko'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        // aman dari notch & keyboard
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lengkapi Verifikasi Anda',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                _buildUploadTile(
                  title: 'Upload Foto KTP',
                  imageBytes: _ktpImageBytes,
                  onTap: () => _pickImage(isKtp: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nikController,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Induk Kependudukan (NIK)',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (val) {
                    if (val == null || val.length != 16) {
                      return 'Masukkan NIK yang valid (16 digit)';
                    }
                    if (!RegExp(r'^[0-9]+$').hasMatch(val)) {
                      return 'NIK hanya boleh angka';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    border: OutlineInputBorder(),
                  ),
                  validator:
                      (val) =>
                          val == null || val.trim().isEmpty
                              ? 'Nama tidak boleh kosong'
                              : null,
                ),
                const SizedBox(height: 16),
                _buildUploadTile(
                  title: 'Selfie dengan KTP',
                  imageBytes: _selfieImageBytes,
                  onTap: () => _pickImage(isKtp: false),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor:
                          _isFormValid ? Colors.green[700] : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        _isFormValid && !_isLoading
                            ? _submitVerification
                            : null,
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text(
                              'Lanjut',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white, // ✅ ini yang benar
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
