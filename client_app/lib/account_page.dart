import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'get_pronto_uploader.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.onShowGuide});
  final VoidCallback? onShowGuide;
  @override State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _name = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = true, _saving = false, _changingPassword = false;
  String? _avatar;
  String? _avatarUrl;
  XFile? _avatarFile;
  String? _username;
  @override void initState() { super.initState(); _load(); }
  @override void dispose() {
    _name.dispose(); _currentPassword.dispose(); _newPassword.dispose(); _confirmPassword.dispose();
    super.dispose();
  }
  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { if (mounted) setState(() => _loading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('profiles').doc(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};
      _name.text = (data['displayName'] ?? user.displayName ?? '').toString();
      _username = data['username']?.toString() ?? user.email?.split('@').first;
      _avatar = data['avatarBase64']?.toString();
      _avatarUrl = (data['avatarUrl'] ?? data['photoUrl'])?.toString();
    } catch (e) { _message('تعذر تحميل بيانات الحساب: $e'); }
    if (mounted) setState(() => _loading = false);
  }
  Future<void> _pickAvatar() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 62, maxWidth: 600, maxHeight: 600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 700 * 1024) { _message('الصورة كبيرة؛ اختر صورة أصغر'); return; }
      setState(() { _avatar = base64Encode(bytes); _avatarFile = file; });
    } catch (e) { _message('تعذر اختيار الصورة: $e'); }
  }
  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final name = _name.text.trim();
    if (user == null) return;
    if (name.isEmpty) { _message('اكتب الاسم الذي سيظهر في حسابك'); return; }
    setState(() => _saving = true);
    try {
      var uploadedAvatarUrl = _avatarUrl;
      if (_avatarFile != null) {
        uploadedAvatarUrl = await GetProntoUploader.upload(_avatarFile!);
      } else if ((uploadedAvatarUrl == null || uploadedAvatarUrl.isEmpty) && _avatar != null && _avatar!.isNotEmpty) {
        final legacyBytes = base64Decode(_avatar!);
        uploadedAvatarUrl = await GetProntoUploader.upload(
          XFile.fromData(legacyBytes, name: 'customer-avatar.jpg', mimeType: 'image/jpeg'),
        );
      }
      await FirebaseFirestore.instance.collection('profiles').doc(user.uid).set({
        'uid': user.uid,
        'username': _username ?? user.email?.split('@').first ?? '',
        'displayName': name,
        if (_avatar != null) 'avatarBase64': _avatar,
        if (uploadedAvatarUrl != null && uploadedAvatarUrl.isNotEmpty) 'avatarUrl': uploadedAvatarUrl,
        if (uploadedAvatarUrl != null && uploadedAvatarUrl.isNotEmpty) 'photoUrl': uploadedAvatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.updateDisplayName(name);
      _avatarUrl = uploadedAvatarUrl;
      _avatarFile = null;
      _message('تم تحديث بيانات الحساب');
    } catch (e) { _message('تعذر حفظ بيانات الحساب: $e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    final current = _currentPassword.text;
    final next = _newPassword.text;
    if (user == null || user.email == null) return;
    if (current.isEmpty) { _message('أدخل كلمة المرور الحالية'); return; }
    if (next.length < 6) { _message('كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف'); return; }
    if (next != _confirmPassword.text) { _message('تأكيد كلمة المرور غير مطابق'); return; }
    setState(() => _changingPassword = true);
    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: current);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(next);
      _currentPassword.clear(); _newPassword.clear(); _confirmPassword.clear();
      _message('تم تغيير كلمة المرور بنجاح');
    } on FirebaseAuthException catch (e) {
      _message(e.code == 'wrong-password' || e.code == 'invalid-credential'
        ? 'كلمة المرور الحالية غير صحيحة'
        : e.code == 'weak-password' ? 'كلمة المرور الجديدة ضعيفة' : 'تعذر تغيير كلمة المرور: ${e.message ?? e.code}');
    } catch (e) { _message('تعذر تغيير كلمة المرور: $e'); }
    finally { if (mounted) setState(() => _changingPassword = false); }
  }
  Future<void> _signOut() async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تسجيل الخروج'), content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل الخروج'))],
    ));
    if (yes == true) await FirebaseAuth.instance.signOut();
  }
  @override Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
          GestureDetector(onTap: _pickAvatar, child: Stack(children: [
            CircleAvatar(radius: 48, backgroundColor: const Color(0xFFFCE4EC),
              backgroundImage: _avatar == null || _avatar!.isEmpty ? null : MemoryImage(base64Decode(_avatar!)),
              child: _avatar == null || _avatar!.isEmpty ? const Icon(Icons.person, size: 48, color: Color(0xFF6A1B9A)) : null),
            const Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 16, child: Icon(Icons.camera_alt, size: 17))),
          ])),
          const SizedBox(height: 8), TextButton.icon(onPressed: _pickAvatar, icon: const Icon(Icons.photo_camera), label: const Text('تغيير صورة الحساب')),
          Text(_username == null ? '' : '@$_username', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          TextField(controller: _name, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'الاسم الظاهر', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _saveProfile,
            icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ بيانات الحساب'))),
        ]))),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('تغيير كلمة المرور', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: _currentPassword, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الحالية', prefixIcon: Icon(Icons.lock_outline))),
          const SizedBox(height: 9),
          TextField(controller: _newPassword, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', prefixIcon: Icon(Icons.lock_reset))),
          const SizedBox(height: 9),
          TextField(controller: _confirmPassword, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة', prefixIcon: Icon(Icons.verified_user_outlined))),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(onPressed: _changingPassword ? null : _changePassword,
            icon: const Icon(Icons.password), label: Text(_changingPassword ? 'جارٍ التغيير...' : 'تحديث كلمة المرور')),
        ]))),
        const SizedBox(height: 18),
        if (widget.onShowGuide != null) OutlinedButton.icon(onPressed: widget.onShowGuide, icon: const Icon(Icons.help_outline), label: const Text('دليل الاستخدام')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red)),
        const SizedBox(height: 30),
      ],
    ),
  );
}
