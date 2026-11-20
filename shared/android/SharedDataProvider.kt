package com.example.al_sheikha_admin

import android.content.ContentProvider
import android.content.ContentValues
import android.content.UriMatcher
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.net.Uri
import org.json.JSONObject

class SharedDataProvider : ContentProvider() {
  companion object {
    const val AUTHORITY = "com.example.al_sheikha_admin.shared"
    val BASE_URI: Uri = Uri.parse("content://$AUTHORITY/records")
    private const val MATCH_RECORDS = 1
  }
  private lateinit var helper: StoreDb
  private val matcher = UriMatcher(UriMatcher.NO_MATCH).apply { addURI(AUTHORITY, "records", MATCH_RECORDS) }

  override fun onCreate(): Boolean { helper = StoreDb(context!!); return true }
  override fun getType(uri: Uri) = "vnd.android.cursor.dir/vnd.alshaikha.record"
  override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
    require(matcher.match(uri) == MATCH_RECORDS)
    val table = uri.getQueryParameter("table") ?: "members"
    return helper.readableDatabase.query("records", arrayOf("id", "table_name", "payload", "updated_at"),
      if (table == "*") null else "table_name=?", if (table == "*") null else arrayOf(table), null, null, "updated_at DESC")
  }
  override fun insert(uri: Uri, values: ContentValues?): Uri {
    require(matcher.match(uri) == MATCH_RECORDS)
    val table = values?.getAsString("table_name") ?: error("table_name required")
    val id = values.getAsString("id") ?: java.util.UUID.randomUUID().toString()
    val payload = values.getAsString("payload") ?: "{}"
    val row = ContentValues().apply { put("id", id); put("table_name", table); put("payload", payload); put("updated_at", System.currentTimeMillis()) }
    helper.writableDatabase.insertWithOnConflict("records", null, row, SQLiteDatabase.CONFLICT_REPLACE)
    context?.contentResolver?.notifyChange(BASE_URI, null)
    return BASE_URI.buildUpon().appendPath(id).build()
  }
  override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int {
    insert(uri, values); return 1
  }
  override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int {
    val table = uri.getQueryParameter("table") ?: return 0
    val id = uri.getQueryParameter("id") ?: return 0
    val count = helper.writableDatabase.delete("records", "table_name=? AND id=?", arrayOf(table, id))
    context?.contentResolver?.notifyChange(BASE_URI, null); return count
  }
}

private class StoreDb(context: android.content.Context) : SQLiteOpenHelper(context, "al_sheikha_shared.db", null, 1) {
  override fun onCreate(db: SQLiteDatabase) {
    db.execSQL("CREATE TABLE records (id TEXT NOT NULL, table_name TEXT NOT NULL, payload TEXT NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY(table_name,id))")
    db.execSQL("CREATE INDEX records_table_idx ON records(table_name)")
  }
  override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}
}
