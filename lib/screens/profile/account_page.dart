import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  bool isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _birthPlaceController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _genderController.text = data['gender'] ?? '';
        _ageController.text = data['age']?.toString() ?? '';
        _birthPlaceController.text = data['birthPlace'] ?? '';
        _birthDateController.text = data['birthDate'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['location'] ?? '';
        _emailController.text = data['email'] ?? '';
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> updateProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).update({
        'name': _nameController.text.trim(),
        'gender': _genderController.text.trim(),
        'age': _ageController.text.trim(),
        'birthPlace': _birthPlaceController.text.trim(),
        'birthDate': _birthDateController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _addressController.text.trim(),
        'email': _emailController.text.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorPrimary = Colors.green[700];
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Akun Saya"),
        backgroundColor: colorPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: colorPrimary,
                            child: Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text[0].toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text
                                      : "Nama belum diisi",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _emailController.text,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Form Section
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          buildTextField("Nama Lengkap", _nameController),
                          buildTextField("Jenis Kelamin", _genderController),
                          buildTextField(
                            "Umur",
                            _ageController,
                            isNumber: true,
                          ),
                          buildTextField("Tempat Lahir", _birthPlaceController),
                          buildDateField("Tanggal Lahir", _birthDateController),
                          buildTextField(
                            "No. HP",
                            _phoneController,
                            isNumber: true,
                          ),
                          buildTextField("Alamat", _addressController),
                          buildTextField(
                            "Email",
                            _emailController,
                            enabled: false,
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : updateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child:
                                  isSaving
                                      ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text(
                                        "Simpan Perubahan",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool enabled = true,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
          ),
        ),
        validator: (value) {
          if (enabled && (value == null || value.trim().isEmpty)) {
            return 'Field ini wajib diisi';
          }
          return null;
        },
      ),
    );
  }

  Widget buildDateField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: "Pilih tanggal lahir",
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(Icons.calendar_today_rounded),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Field ini wajib diisi';
          }
          return null;
        },
        onTap: () async {
          FocusScope.of(context).requestFocus(FocusNode());
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1950),
            lastDate: DateTime.now(),
            locale: const Locale('id', 'ID'),
          );

          if (pickedDate != null) {
            controller.text =
                "${pickedDate.day.toString().padLeft(2, '0')}/"
                "${pickedDate.month.toString().padLeft(2, '0')}/"
                "${pickedDate.year}";
          }
        },
      ),
    );
  }
}
