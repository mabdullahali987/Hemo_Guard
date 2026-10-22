package com.shah.hemo_guard

import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var appearanceChannel: MethodChannel? = null

    private fun isNightMode(): Boolean =
        (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appearanceChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hemoguard/system_appearance"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDarkMode" -> result.success(isNightMode())
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        appearanceChannel?.invokeMethod("appearanceChanged", isNightMode())
    }
}
