package com.example.al_sheikha_client

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    createAlshaikhaNotificationChannel()
    super.onCreate(savedInstanceState)
  }

  private fun createAlshaikhaNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val manager = getSystemService(NotificationManager::class.java)
      if (manager.getNotificationChannel("alshaikha_alerts_v2") == null) {
        val channel = NotificationChannel(
          "alshaikha_alerts_v2",
          "إشعارات الشيخة",
          NotificationManager.IMPORTANCE_HIGH
        ).apply {
          description = "رسائل العملاء والحجوزات والتحديثات"
          enableVibration(true)
          setShowBadge(true)
        }
        manager.createNotificationChannel(channel)
      }
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    ClientSharedStoreChannel(this).attach(flutterEngine)
  }
}
