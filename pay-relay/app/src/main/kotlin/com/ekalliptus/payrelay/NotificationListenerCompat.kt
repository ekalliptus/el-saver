package com.ekalliptus.payrelay

import android.content.ComponentName
import android.content.Context
import android.provider.Settings

object NotificationListenerCompat {
    fun isListenerEnabled(context: Context): Boolean {
        val flat = Settings.Secure.getString(
            context.contentResolver, "enabled_notification_listeners"
        ) ?: return false
        return flat.split(":").any { entry ->
            ComponentName.unflattenFromString(entry)?.packageName ==
                context.packageName
        }
    }
}
