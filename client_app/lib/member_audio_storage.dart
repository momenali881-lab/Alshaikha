import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class MemberAudioStorage {
  static const int maxBytes = 10 * 1024 * 1024;
  static const Set<String> extensions = {'mp3', 'm4a', 'wav', 'aac', 'ogg', 'opus'};

  static String contentType(String extension) => switch (extension.toLowerCase()) {
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'wav' => 'audio/wav',
    'aac' => 'audio/aac',
    'ogg' => 'audio/ogg',
    'opus' => 'audio/opus',
    _ => 'application/octet-stream',
  };

  static Future<Map<String, String>> upload(PlatformFile file, String memberId) async {
    final extension = (file.extension ?? '').toLowerCase();
    if (!extensions.contains(extension)) {
      throw Exception('صيغة الملف غير مدعومة');
    }
    if (file.size <= 0 || file.size > maxBytes) {
      throw Exception('يجب ألا يتجاوز حجم الملف 10 ميغابايت');
    }
    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('تعذر قراءة الملف الصوتي من الهاتف');
    }
    final path = 'member_audio/$memberId/voice.$extension';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType(extension)));
    final url = await ref.getDownloadURL();
    return {'url': url, 'path': path, 'name': file.name};
  }

  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    await FirebaseStorage.instance.ref().child(path).delete();
  }
}
