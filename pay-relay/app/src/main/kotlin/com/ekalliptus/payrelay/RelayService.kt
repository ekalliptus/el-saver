package com.ekalliptus.payrelay

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Reads DANA money-in notifications on the merchant's phone and posts a
 * signed webhook so the EL-Saver server can auto-activate the matching
 * pending order (unique whole-rupiah amounts, <48h matching window).
 */
class RelayService : NotificationListenerService() {

    /// Money-in notifications come from every QRIS wallet app, not just
    /// DANA — blu/BCA, GoPay, OVO, ShopeePay, bank apps. Amount-pattern +
    /// incoming-keyword guards below still filter the noise.
    private val walletPackages = setOf(
        "id.dana",                        // DANA
        "com.bca.cba",                    // blu by BCA
        "com.gojek.app",                  // Gojek/GoPay
        "com.shopeepay.indonesia",        // ShopeePay
        "id.ovo.android",                 // OVO
        "com.telkomsel.tcash",            // LinkAja
        "com.bmri.digital",               // Livin' by Mandiri
        "com.bni",                        // BNI Mobile
        "com.bcadigital",                 // myBCA
        "com.bri.brimo",                  // BRImo
        "com.bankmandiri.mandirionline",  // Livin'
    )

    override fun onListenerConnected() {
        super.onListenerConnected()
        // Battery optimizers on many ROMs kill the listener overnight.
        // Whatever money-in notifications survived in the shade get
        // replayed here so the webhook still fires (dedup guards repeats).
        try {
            activeNotifications?.forEach { onNotificationPosted(it) }
        } catch (_: Exception) {
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val pkg = sbn?.packageName ?: return
        if (pkg !in walletPackages) return
        val extras = sbn.notification.extras
        val text = listOf(
            extras.getCharSequence(Notification.EXTRA_TEXT),
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT),
            extras.getCharSequence(Notification.EXTRA_TITLE),
        ).firstNotNullOfOrNull { it }?.toString() ?: return

        // Only money-IN notifications; wallets also notify about promos,
        // balances and outgoing transfers which must NOT fire the webhook.
        val lower = text.lowercase()
        val incoming = listOf(
            "masuk", "diterima", "berhasil", "received",
        ).any { lower.contains(it) } &&
            !lower.contains("keluar") &&
            !lower.contains("terkirim")
        if (!incoming) return
        val amount = extractRupiah(text) ?: return
        if (amount < 1000) return
        if (RelayCore.isDuplicate(this, amount)) return
        Thread { RelayCore.postWebhook(this, amount) }.start()
    }

    /**
     * "Rp15.027", "Rp 39.027,00", "Rp39.027.00" -> 39027.
     * Strips a trailing 1-2 digit group (cents) but keeps 3-digit groups
     * (thousand chunks) so "39.027" never loses its ".027".
     */
    private fun extractRupiah(text: String): Long? {
        val m = Regex("Rp\\s?([\\d.,]+)").find(text) ?: return null
        val raw = m.groupValues[1]
        val cents = Regex("[.,](\\d{1,2})$").find(raw)?.value
        val cleaned = if (cents != null) raw.dropLast(cents.length) else raw
        val digits = cleaned.replace("[.,]".toRegex(), "")
        return digits.toLongOrNull()
    }

}
