import 'dart:convert';
import 'package:flutter/services.dart';

class SharedStore {
  static const _channel = MethodChannel('al_sheikha/shared_store');
  static Future<List<Map<String, dynamic>>> list(String table) async {
    final rows = await _channel.invokeListMethod<dynamic>('list', {'table': table}) ?? [];
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final decoded = jsonDecode(map['payload'] as String) as Map<String, dynamic>;
      return decoded;
    }).toList();
  }
  static Future<String> save(String table, Map<String, dynamic> data) async =>
      (await _channel.invokeMethod<String>('save', {'table': table, 'data': data}))!;
  static Future<void> delete(String table, String id) async =>
      _channel.invokeMethod<void>('delete', {'table': table, 'id': id});
}
