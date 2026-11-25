import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Public upload-only key. Never place a Get Pronto Secret Key in this app.
class GetProntoUploader {
  static const String _apiKey = 'pronto_pk__woiuI3y-s3pTDBuaM7nMJxxjJqi9';
  static const String _baseUrl = 'https://api.getpronto.io/v1';

  static String _mimeType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
  }

  static Future<String> upload(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('ملف الصورة فارغ');
    if (bytes.length > 10 * 1024 * 1024) {
      throw Exception('حجم الصورة يتجاوز الحد المجاني البالغ 10 ميغابايت');
    }

    final mime = _mimeType(file.name);
    final headers = <String, String>{
      'Authorization': 'ApiKey $_apiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final presignResponse = await http.post(
      Uri.parse('$_baseUrl/upload/presign'),
      headers: headers,
      body: jsonEncode({
        'filename': file.name,
        'mimetype': mime,
        'size': bytes.length,
        'folderName': 'alshaikha',
      }),
    ).timeout(const Duration(seconds: 30));
    if (presignResponse.statusCode < 200 || presignResponse.statusCode >= 300) {
      throw Exception('تعذر طلب رابط رفع الصورة (${presignResponse.statusCode})');
    }

    final presign = jsonDecode(presignResponse.body) as Map<String, dynamic>;
    final uploadUrl = presign['uploadUrl']?.toString();
    final pendingUploadId = presign['pendingUploadId']?.toString();
    if (uploadUrl == null || pendingUploadId == null) {
      throw Exception('استجابة خدمة الصور غير مكتملة');
    }

    final uploadResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': mime},
      body: bytes,
    ).timeout(const Duration(minutes: 2));
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw Exception('فشل رفع الصورة إلى التخزين (${uploadResponse.statusCode})');
    }

    final confirmResponse = await http.post(
      Uri.parse('$_baseUrl/upload/confirm'),
      headers: headers,
      body: jsonEncode({'pendingUploadId': pendingUploadId}),
    ).timeout(const Duration(seconds: 30));
    if (confirmResponse.statusCode < 200 || confirmResponse.statusCode >= 300) {
      throw Exception('تعذر تأكيد حفظ الصورة (${confirmResponse.statusCode})');
    }

    final confirmation = jsonDecode(confirmResponse.body) as Map<String, dynamic>;
    final uploadedFile = Map<String, dynamic>.from(confirmation['file'] as Map? ?? {});
    final url = (uploadedFile['secureUrl'] ?? uploadedFile['rawUrl'])?.toString();
    if (url == null || !url.startsWith('https://')) {
      throw Exception('لم تُرجع خدمة الصور رابطاً صالحاً');
    }
    return url;
  }
}
