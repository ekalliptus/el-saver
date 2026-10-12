package com.ekalliptus.payrelay

import android.content.Context
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Shared webhook logic used by both the listener service and the test UI. */
object RelayCore {

    fun log(context: Context, line: String) {
        val prefs = context.getSharedPreferences("relay", Context.MODE_PRIVATE)
        val stamp = SimpleDateFormat("MM-dd HH:mm:ss", Locale.US).format(Date())
        val log = prefs.getString("log", "") ?: ""
        prefs.edit()
            .putString("log", "[$stamp] $line\n" + log.take(4000))
            .apply()
    }

    /** Dedup guard for re-posted/summarized notifications of the same amount. */
    fun isDuplicate(context: Context, amount: Long): Boolean {
        val prefs = context.getSharedPreferences("relay", Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val lastAt = prefs.getLong("amt_${amount}_at", 0L)
        if (now - lastAt < 10 * 60 * 1000L) return true
        prefs.edit().putLong("amt_${amount}_at", now).apply()
        return false
    }

    fun postWebhook(context: Context, amount: Long): Pair<Int, String> {
        val secret = BuildConfig.WEBHOOK_SECRET
        if (secret.isEmpty()) {
            log(context, "GAGAL: WEBHOOK_SECRET kosong")
            return -1 to "WEBHOOK_SECRET belum diisi di build"
        }
        val ts = System.currentTimeMillis() / 1000
        // Server contract: HMAC-SHA256 over "order_id|gross_amount|timestamp".
        val msg = "|$amount|$ts"
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(), "HmacSHA256"))
        val sig = mac.doFinal(msg.toByteArray()).joinToString("") { "%02x".format(it) }
        val body = """{"gross_amount":"$amount","timestamp":$ts,"signature":"$sig"}"""
        val result = try {
            val conn = URL(BuildConfig.WEBHOOK_URL).openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 10000
            conn.readTimeout = 15000
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json")
            // Cloudflare bot rules block generic client UAs; set our own.
            conn.setRequestProperty("User-Agent", "EL-Saver-PayRelay/1.0")
            conn.outputStream.use { it.write(body.toByteArray()) }
            val code = conn.responseCode
            val resp = (if (code in 200..299) conn.inputStream else conn.errorStream)
                ?.bufferedReader()?.use { it.readText() } ?: ""
            code to resp.take(200)
        } catch (e: Exception) {
            0 to (e.message ?: "network error")
        }
        log(context, "Rp$amount -> ${result.first} ${result.second}")
        return result
    }
}
