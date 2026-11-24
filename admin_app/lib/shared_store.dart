import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SharedStore {
  static const _channel = MethodChannel('al_sheikha/shared_store');
  static final _db = FirebaseFirestore.instance;

  static Future<List<Map<String, dynamic>>> _localList(String table) async {
    try {
      final rows = await _channel.invokeListMethod<dynamic>('list', {'table': table}) ?? [];
      return rows.map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return jsonDecode(map['payload'] as String) as Map<String, dynamic>;
      }).toList();
    } on PlatformException {
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  static Future<void> _cache(String table, Map<String, dynamic> data) async {
    try {
      await _channel.invokeMethod<String>('save', {'table': table, 'data': data});
    } on PlatformException {
      // The customer may install this app on a device without the admin provider.
    } on MissingPluginException {
      // Cloud Firestore remains the source of truth on standalone installs.
    }
  }

  static Future<List<Map<String, dynamic>>> list(String table) async {
    final user = FirebaseAuth.instance.currentUser;
    // Never expose the shared device cache to a signed-out session.
    if (user == null) return [];
    try {
      Query<Map<String, dynamic>> query = _db.collection(table);
      final profile = await _db.collection('profiles').doc(user.uid).get();
      final isAdmin = profile.data()?['role'] == 'admin';
      if (!isAdmin && table == 'notifications') {
        // Global announcements plus notifications addressed to this customer only.
        final snapshots = await Future.wait([
          _db.collection(table).where('target', isEqualTo: 'all').get(),
          _db.collection(table).where('customerId', isEqualTo: user.uid).get(),
        ]);
        final docs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final snapshot in snapshots) {
          for (final doc in snapshot.docs) { docs[doc.id] = doc; }
        }
        final remote = docs.values.map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()}).toList();
        for (final item in remote) { await _cache(table, item); }
        return remote;
      }
      if (!isAdmin) {
        if (table == 'bookings' || table == 'favorites') {
          query = query.where('customerId', isEqualTo: user.uid);
        } else if (table == 'messages') {
          query = query.where('conversationId', isEqualTo: user.uid);
        }
      }
      final snapshot = await query.get();
      final remote = snapshot.docs.map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()}).toList();
      for (final item in remote) {
        await _cache(table, item);
      }
      return remote;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (table == 'bookings' || table == 'messages' ||
          message.contains('permission-denied') || message.contains('unauthorized')) {
        rethrow;
      }
      final local = await _localList(table);
      if (table == 'bookings' || table == 'favorites') {
        return local.where((item) => item['customerId'] == user.uid).toList();
      }
      if (table == 'messages') {
        return local.where((item) => item['conversationId'] == user.uid).toList();
      }
      if (table == 'notifications') {
        return local.where((item) => item['target'] == 'all' || item['customerId'] == user.uid).toList();
      }
      return local;
    }
  }

  static Future<String> save(String table, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول قبل حفظ البيانات المشتركة');
    }
    final id = (data['id'] as String?) ?? _db.collection(table).doc().id;
    final record = <String, dynamic>{...data, 'id': id};
    // Firestore is the source of truth. Cache locally only after the cloud write succeeds.
    await _db.collection(table).doc(id).set({
      ...record,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _cache(table, record);
    return id;
  }

  static Future<void> delete(String table, String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول قبل حذف البيانات المشتركة');
    }
    await _db.collection(table).doc(id).delete();
    try {
      await _channel.invokeMethod<void>('delete', {'table': table, 'id': id});
    } on PlatformException {
      // Local cache is optional on standalone customer devices.
    } on MissingPluginException {
      // Local cache is optional on standalone customer devices.
    }
  }

  static Future<List<Map<String, dynamic>>> _legacyRows(String table) async {
    final rows = await _channel.invokeListMethod<dynamic>('list', {'table': table}) ?? [];
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return jsonDecode(map['payload'] as String) as Map<String, dynamic>;
    }).toList();
  }

  /// Uploads legacy records from this device's SQLite cache without deleting them.
  /// Existing cloud documents are left untouched, making repeated runs safe.
  static Future<Map<String, int>> migrateLocalToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('يجب تسجيل الدخول بحساب الإدارة');
    final profile = await _db.collection('profiles').doc(user.uid).get();
    if (profile.data()?['role'] != 'admin') {
      throw StateError('هذه العملية متاحة للإدارة فقط');
    }
    const tables = [
      'members', 'sessions', 'banners', 'bookings',
      'favorites', 'messages', 'notifications', 'announcements',
    ];
    var migrated = 0;
    var skipped = 0;
    for (final table in tables) {
      final localRows = await _legacyRows(table);
      for (final row in localRows) {
        final rawId = row['id']?.toString().trim() ?? '';
        final id = rawId.isEmpty ? _db.collection(table).doc().id : rawId;
        final ref = _db.collection(table).doc(id);
        final existing = await ref.get();
        if (existing.exists) {
          skipped++;
          continue;
        }
        await ref.set({
          ...row,
          'id': id,
          'legacyMigratedAt': FieldValue.serverTimestamp(),
        });
        migrated++;
      }
    }
    return {'migrated': migrated, 'skipped': skipped};
  }
}
