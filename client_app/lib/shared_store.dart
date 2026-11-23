import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SharedStore {
  static const _channel = MethodChannel('al_sheikha/shared_store');
  static final _db = FirebaseFirestore.instance;

  static Future<List<Map<String, dynamic>>> _localList(String table) async {
    final rows = await _channel.invokeListMethod<dynamic>('list', {'table': table}) ?? [];
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return jsonDecode(map['payload'] as String) as Map<String, dynamic>;
    }).toList();
  }

  static Future<void> _cache(String table, Map<String, dynamic> data) async {
    await _channel.invokeMethod<String>('save', {'table': table, 'data': data});
  }

  static Future<List<Map<String, dynamic>>> list(String table) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _localList(table);
    try {
      Query<Map<String, dynamic>> query = _db.collection(table);
      final profile = await _db.collection('profiles').doc(user.uid).get();
      final isAdmin = profile.data()?['role'] == 'admin';
      if (!isAdmin) {
        if (table == 'bookings' || table == 'favorites') {
          query = query.where('customerId', isEqualTo: user.uid);
        } else if (table == 'messages') {
          query = query.where('conversationId', isEqualTo: user.uid);
        } else if (table == 'notifications') {
          query = query.where('target', whereIn: ['customer', 'all']);
        }
      }
      final snapshot = await query.get();
      final remote = snapshot.docs.map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()}).toList();
      for (final item in remote) {
        await _cache(table, item);
      }
      return remote;
    } catch (e) {
      // Preserve access-control failures; only use the local cache for network errors.
      final message = e.toString().toLowerCase();
      if (message.contains('permission-denied') || message.contains('unauthorized')) rethrow;
      return _localList(table);
    }
  }

  static Future<String> save(String table, Map<String, dynamic> data) async {
    final id = (data['id'] as String?) ?? _db.collection(table).doc().id;
    final record = <String, dynamic>{...data, 'id': id};
    await _cache(table, record);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _db.collection(table).doc(id).set({
        ...record,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return id;
  }

  static Future<void> delete(String table, String id) async {
    await _channel.invokeMethod<void>('delete', {'table': table, 'id': id});
    if (FirebaseAuth.instance.currentUser != null) {
      await _db.collection(table).doc(id).delete();
    }
  }
}
