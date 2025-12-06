import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/product.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';

class AddProductPage extends StatefulWidget {
  final String tokoId;

  const AddProductPage({super.key, required this.tokoId});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  final _picker = ImagePicker();
  Uint8List? _imageBytes;

  final _kategoriList = ['Umum', 'Makanan', 'Minuman', 'Snack'];
  String _selectedKategori = 'Umum';

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _imageBytes = bytes);
      }
    } catch (e) {
      _showSnackbar('Gagal memilih gambar: $e', isError: true);
    }
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      _showSnackbar('Gambar produk wajib dipilih!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Pengguna belum login');

      final tokoDoc =
          await FirebaseFirestore.instance
              .collection('toko')
              .doc(widget.tokoId)
              .get();

      if (!tokoDoc.exists) throw Exception('Toko tidak ditemukan');

      final tokoNama = tokoDoc.data()?['namaToko'] ?? 'Tanpa Nama';
      final fileName = 'produk_${DateTime.now().millisecondsSinceEpoch}';
      final imageUrl = await CloudinaryService.uploadImageToCloudinary(
        _imageBytes!,
        fileName,
      );

      final produkId = FirebaseFirestore.instance.collection('produk').doc().id;

      final product = Product(
        produkId: produkId,
        namaProduk: _nameController.text.trim(),
        deskripsi: _descController.text.trim(),
        // Hapus koma/titik sebelum parse
        harga: double.parse(_priceController.text.replaceAll('.', '')),
        stok: int.parse(_stockController.text.trim()),
        gambarUrl: imageUrl,
        kategori: _selectedKategori,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tokoId: widget.tokoId,
        tokoNama: tokoNama,
        sellerId: user.uid,
      );

      await _firestoreService.saveProduct(product);

      _showSnackbar('Produk berhasil ditambahkan!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackbar('Gagal menambahkan produk: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _isLoading ? null : _pickImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          image:
              _imageBytes != null
                  ? DecorationImage(
                    image: MemoryImage(_imageBytes!),
                    fit: BoxFit.cover,
                  )
                  : null,
        ),
        child:
            _imageBytes == null
                ? const Center(
                  child: Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                )
                : null,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label wajib diisi';
        }
        if (keyboardType == TextInputType.number) {
          final number = double.tryParse(value.replaceAll('.', '').trim());
          if (number == null) return '$label harus berupa angka';
          if (label.toLowerCase().contains('harga') && number <= 0) {
            return 'Harga harus lebih dari 0';
          }
          if (label.toLowerCase().contains('stok') && number < 0) {
            return 'Stok tidak boleh negatif';
          }
        }
        return null;
      },
    );
  }

  Widget _buildKategoriDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedKategori,
      items:
          _kategoriList
              .map(
                (kategori) =>
                    DropdownMenuItem(value: kategori, child: Text(kategori)),
              )
              .toList(),
      onChanged:
          _isLoading ? null : (val) => setState(() => _selectedKategori = val!),
      decoration: InputDecoration(
        labelText: 'Kategori Produk',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon:
            _isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Icon(Icons.save, color: Colors.white),
        label: Text(
          _isLoading ? 'Menyimpan...' : 'Simpan Produk',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _isLoading ? null : _submitProduct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Produk'),
        backgroundColor: Colors.green.shade700,
        foregroundColor:
            Colors.white, // ✅ ini membuat teks & panah back jadi putih
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImagePicker(),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Nama Produk',
                controller: _nameController,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Deskripsi Produk',
                controller: _descController,
                keyboardType: TextInputType.multiline,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Harga (Rp)',
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsFormatter(),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Stok',
                controller: _stockController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              _buildKategoriDropdown(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// Formatter ribuan untuk kolom harga
class ThousandsFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,###', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // hapus semua koma/titik dulu
    String digits = newValue.text.replaceAll('.', '');
    int value = int.parse(digits);

    String newText = _formatter.format(value);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
