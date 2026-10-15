package com.ekalliptus.payrelay

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class MainActivity : Activity() {

    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val pad = (resources.displayMetrics.density * 16).toInt()
        status = TextView(this).apply { textSize = 13f }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad, pad, pad)
        }
        root.addView(Button(this).apply {
            text = "1. Izinkan Akses Notifikasi"
            setOnClickListener {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
            }
        })
        root.addView(Button(this).apply {
            text = "2. Kirim Webhook Tes"
            setOnClickListener {
                Thread {
                    RelayCore.postWebhook(this@MainActivity, 12345)
                    runOnUiThread { refresh() }
                }.start()
            }
        })
        root.addView(Button(this).apply {
            text = "3. Kecualikan dari Optimasi Baterai"
            setOnClickListener {
                // ROM battery savers are the #1 killer of the listener at
                // night; the exemption keeps money-in notifications flowing.
                try {
                    @Suppress("BatteryLife")
                    val intent = Intent(
                        android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        android.net.Uri.parse("package:$packageName"))
                    startActivity(intent)
                } catch (_: Exception) {
                    startActivity(Intent(
                        android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                }
            }
        })
        root.addView(status)

        setContentView(ScrollView(this).apply { addView(root) })
        refresh()
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    private fun refresh() {
        val enabled = NotificationListenerCompat.isListenerEnabled(this)
        val secretOk = BuildConfig.WEBHOOK_SECRET.isNotEmpty()
        val log = getSharedPreferences("relay", MODE_PRIVATE).getString("log", "") ?: ""
        status.text = buildString {
            append("Akses notifikasi: ").append(if (enabled) "AKTIF ✓" else "BELUM AKTIF ✗").append('\n')
            append("Secret: ").append(if (secretOk) "terpasang ✓" else "KOSONG ✗").append('\n')
            append("Webhook: ").append(BuildConfig.WEBHOOK_URL).append("\n\n")
            append("Log peristiwa:\n").append(if (log.isEmpty()) "(belum ada)" else log)
        }
    }
}
