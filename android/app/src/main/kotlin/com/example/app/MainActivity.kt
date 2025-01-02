package com.example.app

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.safelaunch/app_launcher"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    val apps = getInstalledApps()
                    result.success(apps)
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        launchApp(packageName, result)
                    } else {
                        result.error("INVALID_PACKAGE", "Package name is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null)
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)
        
        val apps = mutableListOf<Map<String, Any>>()
        val resolveInfos = pm.queryIntentActivities(mainIntent, PackageManager.MATCH_ALL)

        // Önce tüm app bilgilerini toplayalım
        val appsList = resolveInfos.map { resolveInfo ->
            try {
                val appInfo = resolveInfo.activityInfo.applicationInfo
                val name = pm.getApplicationLabel(appInfo).toString()
                val packageName = appInfo.packageName
                Pair(appInfo, name)
            } catch (e: Exception) {
                null
            }
        }.filterNotNull()
        .sortedBy { it.second } // İsimlere göre sırala

        // Sonra ikonları yükleyelim
        appsList.forEach { (appInfo, name) ->
            try {
                val icon = appInfo.loadIcon(pm)
                val iconBytes = drawableToByteArray(icon)

                val appData = mapOf(
                    "name" to name,
                    "packageName" to appInfo.packageName,
                    "icon" to iconBytes
                )
                apps.add(appData)
            } catch (e: Exception) {
                println("Error loading app icon: ${e.message}")
            }
        }

        return apps
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val width = 48  // Sabit boyut kullan
            val height = 48
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, width, height)
            drawable.draw(canvas)
            bitmap
        }

        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream) // Kaliteyi düşür
        return stream.toByteArray()
    }

    private fun launchApp(packageName: String, result: MethodChannel.Result) {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(true)
            } else {
                result.error("APP_NOT_FOUND", "Could not find app with package name: $packageName", null)
            }
        } catch (e: Exception) {
            result.error("LAUNCH_ERROR", "Error launching app: ${e.message}", null)
        }
    }
}
