import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../profile/map_picker_page_fluttermap.dart';

class StoreInfoPage extends StatefulWidget {
  const StoreInfoPage({super.key});

  @override
  State<StoreInfoPage> createState() => _StoreInfoPageState();
}

class _StoreInfoPageState extends State<StoreInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaTokoController = TextEditingController();
  final _deskripsiController = TextEditingController();

  File? _fotoToko;
  Uint8List? _webImage;
  bool _isLoading = false;

  final Logger _logger = Logger('StoreInfoPage');

  final String cloudName = 'dmmh3pfut';
  final String uploadPreset = 'wastefood_preset';

  double? _latitude;
  double? _longitude;

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          setState(() => _webImage = bytes);
        } else {
          setState(() => _fotoToko = File(picked.path));
        }
      }
    } catch (e) {
      _logger.warning('Gagal memilih gambar: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
    }
  }

  Future<String?> _uploadToCloudinary(String userId) async {
    try {
      Uint8List? imageData;

      if (kIsWeb && _webImage != null) {
        imageData = _webImage;
      } else if (!kIsWeb && _fotoToko != null) {
        imageData = await _fotoToko!.readAsBytes();
      }

      if (imageData == null) return null;

      final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
      );
      final request =
          http.MultipartRequest('POST', uri)
            ..fields['upload_preset'] = uploadPreset
            ..fields['folder'] = 'wastefood/toko'
            ..fields['public_id'] = userId
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                imageData,
                filename: '$userId.jpg',
              ),
            );

      final response = await request.send();
      final responseData = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        final data = json.decode(responseData.body);
        return data['secure_url'];
      } else {
        _logger.warning('Cloudinary response: ${responseData.body}');
        return null;
      }
    } catch (e) {
      _logger.severe('Upload Cloudinary gagal', e);
      return null;
    }
  }

  Future<void> _lanjutKeVerifikasi() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih lokasi toko terlebih dahulu'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User belum login');

      String? fotoUrl;
      if ((kIsWeb && _webImage != null) || (!kIsWeb && _fotoToko != null)) {
        fotoUrl = await _uploadToCloudinary(user.uid);
        if (!mounted) return;
        if (fotoUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengunggah foto toko')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/store/verif',
        arguments: {
          'userId': user.uid,
          'namaToko': _namaTokoController.text.trim(),
          'deskripsi': _deskripsiController.text.trim(),
          'fotoUrl': fotoUrl,
          'latitude': _latitude,
          'longitude': _longitude,
        },
      );
    } catch (e, stackTrace) {
      _logger.severe('Gagal lanjut ke verifikasi', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan saat melanjutkan')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pilihLokasi() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerPageFlutterMap()),
    );

    if (result != null && result is Map<String, double>) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
      });
    }
  }

  @override
  void dispose() {
    _namaTokoController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? imageProvider =
        kIsWeb
            ? (_webImage != null ? MemoryImage(_webImage!) : null)
            : (_fotoToko != null ? FileImage(_fotoToko!) : null);

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('Informasi Toko'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade700,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade200,
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.transparent,
                        backgroundImage: imageProvider,
                        child:
                            imageProvider == null
                                ? const Icon(
                                  Icons.camera_alt,
                                  size: 35,
                                  color: Colors.white,
                                )
                                : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Unggah Foto Toko',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 28),

                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _namaTokoController,
                          decoration: InputDecoration(
                            labelText: 'Nama Toko',
                            prefixIcon: const Icon(
                              Icons.store_mall_directory_rounded,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator:
                              (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Nama toko wajib diisi'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _deskripsiController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Deskripsi Toko',
                            prefixIcon: const Icon(Icons.notes_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator:
                              (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Deskripsi wajib diisi'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _pilihLokasi,
                          icon: const Icon(Icons.location_pin),
                          label: const Text('Pilih Lokasi Toko'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        if (_latitude != null && _longitude != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Lokasi: ($_latitude, $_longitude)',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _lanjutKeVerifikasi,
                    icon:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'Lanjutkan ke Verifikasi',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
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
