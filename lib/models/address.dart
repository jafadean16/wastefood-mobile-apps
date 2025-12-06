/// Model data alamat pengguna
class Address {
  /// ID dokumen Firestore
  final String id;

  /// Nama lengkap penerima
  final String fullName;

  /// Nomor telepon penerima
  final String phoneNumber;

  /// Nama provinsi
  final String province;

  /// Nama kota/kabupaten
  final String city;

  /// Nama kecamatan
  final String district;

  /// Kode pos
  final String postalCode;

  /// Alamat lengkap (jalan, nomor rumah, gedung, dll.)
  final String streetAddress;

  /// Status alamat utama
  final bool isPrimary;

  /// Latitude lokasi (untuk integrasi peta)
  final double latitude;

  /// Longitude lokasi (untuk integrasi peta)
  final double longitude;

  /// Detail tambahan (opsional)
  final String otherDetails;

  Address({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.province,
    required this.city,
    required this.district,
    required this.postalCode,
    required this.streetAddress,
    required this.isPrimary,
    required this.latitude,
    required this.longitude,
    required this.otherDetails,
  });

  /// Konversi objek [Address] menjadi [Map] untuk penyimpanan di Firestore
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'province': province,
      'city': city,
      'district': district,
      'postalCode': postalCode,
      'streetAddress': streetAddress,
      'isPrimary': isPrimary,
      'latitude': latitude,
      'longitude': longitude,
      'otherDetails': otherDetails,
    };
  }

  /// Buat objek [Address] dari data [Map] Firestore
  factory Address.fromMap(Map<String, dynamic> map, String id) {
    return Address(
      id: id,
      fullName: map['fullName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      province: map['province'] ?? '',
      city: map['city'] ?? '',
      district: map['district'] ?? '',
      postalCode: map['postalCode'] ?? '',
      streetAddress: map['streetAddress'] ?? '',
      isPrimary: map['isPrimary'] is bool ? map['isPrimary'] : false,
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      otherDetails: map['otherDetails'] ?? '',
    );
  }

  /// Fungsi utilitas untuk memastikan konversi ke [double]
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
