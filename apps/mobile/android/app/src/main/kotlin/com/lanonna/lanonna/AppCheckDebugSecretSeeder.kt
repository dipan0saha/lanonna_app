package com.lanonna.lanonna

import android.content.Context
import com.google.firebase.FirebaseApp

/**
 * Pins the Firebase App Check Android debug secret so reinstall / pm clear does not
 * rotate the UUID. Empty on prod release; set for debug and non-prod release builds.
 */
object AppCheckDebugSecretSeeder {
    private const val PREFS_TEMPLATE = "com.google.firebase.appcheck.debug.store.%s"
    private const val DEBUG_SECRET_KEY = "com.google.firebase.appcheck.debug.DEBUG_SECRET"

    private val uuidRegex =
        Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

    fun seedIfConfigured(context: Context) {
        val token = BuildConfig.APP_CHECK_DEBUG_TOKEN.trim()
        if (token.isEmpty() || !uuidRegex.matches(token)) {
            return
        }
        val app = FirebaseApp.getInstance()
        val prefsName = PREFS_TEMPLATE.format(app.persistenceKey)
        context.applicationContext
            .getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit()
            .putString(DEBUG_SECRET_KEY, token)
            .apply()
    }
}
