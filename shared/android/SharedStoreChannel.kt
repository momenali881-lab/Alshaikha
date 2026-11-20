package com.example.al_sheikha_admin

import android.content.ContentValues
import android.net.Uri
import android.provider.BaseColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class SharedStoreChannel(private val activity: FlutterActivity) {
  fun attach(engine: FlutterEngine) {
    MethodChannel(engine.dartExecutor.binaryMessenger, "al_sheikha/shared_store").setMethodCallHandler { call, result ->
      try {
        val resolver = activity.contentResolver
        val base = SharedDataProvider.BASE_URI
        when (call.method) {
          "list" -> {
            val table = call.argument<String>("table") ?: "members"
            val cursor = resolver.query(base.buildUpon().appendQueryParameter("table", table).build(), null, null, null, null)
            val rows = mutableListOf<Map<String, Any?>>()
            cursor?.use { c -> while (c.moveToNext()) rows.add(mapOf("id" to c.getString(0), "table" to c.getString(1), "payload" to c.getString(2), "updatedAt" to c.getLong(3))) }
            result.success(rows)
          }
          "save" -> {
            val table = call.argument<String>("table") ?: error("table required")
            val payload = call.argument<Map<String, Any?>>("data") ?: error("data required")
            val id = (payload["id"] as? String) ?: java.util.UUID.randomUUID().toString()
            val data = HashMap(payload); data["id"] = id
            val values = ContentValues().apply { put("table_name", table); put("id", id); put("payload", JSONObject(data).toString()) }
            resolver.insert(base, values); result.success(id)
          }
          "delete" -> {
            val table = call.argument<String>("table") ?: error("table required")
            val id = call.argument<String>("id") ?: error("id required")
            val uri = base.buildUpon().appendQueryParameter("table", table).appendQueryParameter("id", id).build()
            result.success(resolver.delete(uri, null, null))
          }
          else -> result.notImplemented()
        }
      } catch (e: Exception) { result.error("STORE_ERROR", e.message, null) }
    }
  }
}
