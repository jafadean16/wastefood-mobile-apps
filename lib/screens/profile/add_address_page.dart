import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wastefood/models/address.dart';
import 'package:wastefood/services/firestore_service.dart';
import 'map_picker_page_fluttermap.dart';

class AddAddressPage extends StatefulWidget {
  final Address? address;

  const AddAddressPage({super.key, this.address});

  @override
  AddAddressPageState createState() => AddAddressPageState();
}

class AddAddressPageState extends State<AddAddressPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _streetAddressController =
      TextEditingController();
  final TextEditingController _otherDetailsController = TextEditingController();

  bool _isPrimary = false;
  double? _latitude;
  double? _longitude;

  final FirestoreService _firestoreService = FirestoreService();

  Map<String, dynamic> regions = {};
  String? selectedProvince;
  String? selectedCity;
  String? selectedDistrict;
  String? selectedPostalCode;

  @override
  void initState() {
    super.initState();
    _loadRegions();

    final addr = widget.address;
    if (addr != null) {
      _fullNameController.text = addr.fullName;
      _phoneNumberController.text = addr.phoneNumber;
      _streetAddressController.text = addr.streetAddress;
      _otherDetailsController.text = addr.otherDetails;
      _isPrimary = addr.isPrimary;
      _latitude = addr.latitude;
      _longitude = addr.longitude;
      selectedProvince = addr.province;
      selectedCity = addr.city;
      selectedDistrict = addr.district;
      selectedPostalCode = addr.postalCode;
    }
  }

  Future<void> _loadRegions() async {
    final jsonString = await rootBundle.loadString(
      'assets/data/indonesia_regions.json',
    );
    setState(() {
      regions = json.decode(jsonString);
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapPickerPageFlutterMap()),
    );

    if (!mounted) return;
    if (result != null && result is Map<String, double>) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
      });
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tolong pilih lokasi di peta')),
      );
      return;
    }

    final newAddress = Address(
      id: widget.address?.id ?? '',
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneNumberController.text.trim(),
      province: selectedProvince ?? '',
      city: selectedCity ?? '',
      district: selectedDistrict ?? '',
      postalCode: selectedPostalCode ?? '',
      streetAddress: _streetAddressController.text.trim(),
      otherDetails: _otherDetailsController.text.trim(),
      isPrimary: _isPrimary,
      latitude: _latitude!,
      longitude: _longitude!,
    );

    try {
      if (widget.address != null) {
        await _firestoreService.updateAddress(newAddress);
      } else {
        await _firestoreService.saveAddress(newAddress);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan alamat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.green.shade600;
    final provinceList = regions.keys.toList();
    final cityList =
        (selectedProvince != null)
            ? (regions[selectedProvince] as Map<String, dynamic>).keys.toList()
            : <String>[];
    final districtList =
        (selectedCity != null && selectedProvince != null)
            ? (regions[selectedProvince]?[selectedCity] as Map<String, dynamic>)
                .keys
                .toList()
            : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.address != null ? 'Edit Alamat' : 'Tambah Alamat Baru',
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      body:
          regions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildTextField(_fullNameController, 'Nama Lengkap'),
                          _buildTextField(
                            _phoneNumberController,
                            'Nomor Telepon',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 8),
                          _buildDropdown(
                            'Provinsi',
                            selectedProvince,
                            provinceList,
                            (value) {
                              setState(() {
                                selectedProvince = value;
                                selectedCity = null;
                                selectedDistrict = null;
                                selectedPostalCode = null;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildDropdown(
                            'Kota / Kabupaten',
                            selectedCity,
                            cityList,
                            (value) {
                              setState(() {
                                selectedCity = value;
                                selectedDistrict = null;
                                selectedPostalCode = null;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildDropdown(
                            'Kecamatan',
                            selectedDistrict,
                            districtList,
                            (value) {
                              setState(() {
                                selectedDistrict = value;
                                selectedPostalCode =
                                    (regions[selectedProvince]?[selectedCity]?[value]
                                            as List)
                                        .first;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            readOnly: true,
                            controller: TextEditingController(
                              text: selectedPostalCode ?? '',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Kode Pos',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            _streetAddressController,
                            'Alamat Lengkap',
                          ),
                          _buildTextField(
                            _otherDetailsController,
                            'Detail Lainnya (opsional)',
                            isRequired: false,
                          ),
                          Row(
                            children: [
                              Switch.adaptive(
                                activeTrackColor: themeColor.withValues(
                                  alpha: 0.5,
                                ),
                                activeThumbColor: themeColor,
                                value: _isPrimary,
                                onChanged:
                                    (value) =>
                                        setState(() => _isPrimary = value),
                              ),
                              const Text('Atur sebagai alamat utama'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _pickLocation,
                            icon: const Icon(Icons.map),
                            label: Text(
                              _latitude != null
                                  ? 'Lokasi Dipilih'
                                  : 'Pilih Lokasi di Peta',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _saveAddress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Simpan Alamat',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items:
          items.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (!isRequired) return null;
          if (value == null || value.trim().isEmpty) {
            return '$label harus diisi';
          }
          return null;
        },
      ),
    );
  }
}
