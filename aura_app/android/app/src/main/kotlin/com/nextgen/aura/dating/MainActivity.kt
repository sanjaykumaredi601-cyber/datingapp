package com.nextgen.aura.dating

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SECURITY_CHANNEL = "com.auraapp.aura_app/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val isDebuggable = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val isEmulator = android.os.Build.HARDWARE.contains("goldfish") || android.os.Build.HARDWARE.contains("ranchu")
        if (!isDebuggable && !isEmulator) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onResume() {
        super.onResume()
        val isEmulator = android.os.Build.HARDWARE.contains("goldfish") || android.os.Build.HARDWARE.contains("ranchu")
        if (isEmulator || intent.getBooleanExtra("disable_flag_secure", false)) {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val isEmulator = android.os.Build.HARDWARE.contains("goldfish") || android.os.Build.HARDWARE.contains("ranchu")
        if (isEmulator || intent.getBooleanExtra("disable_flag_secure", false)) {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureMode" -> {
                    val isEmulator = android.os.Build.HARDWARE.contains("goldfish") || android.os.Build.HARDWARE.contains("ranchu")
                    if (!isEmulator) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(true)
                }
                "disableSecureMode" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
