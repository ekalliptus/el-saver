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

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn?.packageName != "id.dana") return
        val extras = sbn.notification.extras
        val text = listOf(
            extras.getCharSequence(Notification.EXTRA_TEXT),
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT),
            extras.getCharSequence(Notification.EXTRA_TITLE),
        ).firstNotNullOfOrNull { it }?.toString() ?: return

        val amount = extractRupiah(text) ?: return
        if (amount < 1000) return
        if (RelayCore.isDuplicate(this, amount)) return
        Thread { RelayCore.postWebhook(this, amount) }.start()
    }

    /** "Rp15.027" / "Rp 15.027,00" -> 15027 */
    private fun extractRupiah(text: String): Long? {
        val m = Regex("Rp\\s?([\\d.,]+)").find(text) ?: return null
        val digits = m.groupValues[1]
            .replace(Regex("[.,](\\d{1,2})$"), "") // trailing cents
            .replace("[.,]".toRegex(), "")           // thousand separators
        return digits.toLongOrNull()
    }
}
