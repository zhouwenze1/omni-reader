package com.example.reader_mobile

import android.content.Context
import android.os.BatteryManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "reader_mobile/device_status",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBatteryLevel" -> result.success(readBatteryLevel())
                else -> result.notImplemented()
            }
        }
    }

    private fun readBatteryLevel(): Int? {
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val capacity = batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            ?: return null
        return capacity.takeIf { it >= 0 }
    }
}
