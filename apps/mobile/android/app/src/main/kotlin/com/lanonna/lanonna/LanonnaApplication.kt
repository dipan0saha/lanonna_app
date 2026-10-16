package com.lanonna.lanonna

import android.app.Application

class LanonnaApplication : Application() {
    override fun onCreate() {
        AppCheckDebugSecretSeeder.seedIfConfigured(this)
        super.onCreate()
    }
}
