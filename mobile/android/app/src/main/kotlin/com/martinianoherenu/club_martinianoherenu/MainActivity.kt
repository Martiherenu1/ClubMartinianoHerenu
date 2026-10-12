package com.martinianoherenu.club_martinianoherenu

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        crearCanalDeRecordatorios()
    }

    /**
     * Canal de los avisos de reservas (Android 8+). Con importancia alta el aviso
     * aparece como banner; es el canal que el manifiesto declara por defecto para FCM.
     */
    private fun crearCanalDeRecordatorios() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val canal = NotificationChannel(
            "recordatorios",
            "Recordatorios de reservas",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Avisos 24 horas y 1 hora antes de cada reserva, y cancelaciones."
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(canal)
    }
}
