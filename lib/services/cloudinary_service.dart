import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'dmmh3pfut'; // Ganti dengan cloud name kamu
  static const String uploadPreset = 'wastefood_preset';

  static Future<String> uploadImageToCloudinary(Uint8List imageBytes, String fileName) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['public_id'] = fileName
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
      ));

    final response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);
      return data['secure_url'];
    } else {
      throw Exception('Gagal upload gambar ke Cloudinary. Status: ${response.statusCode}');
    }
  }
}
