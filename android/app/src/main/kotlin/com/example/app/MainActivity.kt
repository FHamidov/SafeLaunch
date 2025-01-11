package com.example.app

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.provider.Settings
import android.app.AppOpsManager
import android.os.Process
import android.os.Bundle
import android.net.Uri
import android.view.KeyEvent
import android.app.ActivityManager
import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import android.app.Application
import android.app.Activity
import android.view.WindowManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.safelaunch/app_launcher"
    private var isLocked = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // İlk başlatmada icazələri yoxla
        checkAndRequestPermissions()
        
        // Block notifications from opening apps when locked
        blockNotificationOpening()
        
        // Make sure we are always the default home app
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_HOME)
        intent.addCategory(Intent.CATEGORY_DEFAULT)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        packageManager.setComponentEnabledSetting(
            componentName,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        return if (isLocked) {
            when (keyCode) {
                KeyEvent.KEYCODE_HOME,
                KeyEvent.KEYCODE_BACK,
                KeyEvent.KEYCODE_APP_SWITCH,
                KeyEvent.KEYCODE_MENU -> true
                else -> super.onKeyDown(keyCode, event)
            }
        } else {
            super.onKeyDown(keyCode, event)
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (isLocked && !hasFocus) {
            // If app loses focus while locked, bring it back to front
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun checkAndRequestPermissions() {
        // Usage Stats icazəsini yoxla
        if (!checkUsageStatsPermission()) {
            requestUsageStatsPermission()
        }

        // System Alert icazəsini yoxla
        if (!Settings.canDrawOverlays(this)) {
            requestSystemAlertPermission()
        }
    }

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
                "openHomeSettings" -> {
                    openHomeSettings()
                    result.success(true)
                }
                "checkUsageStatsPermission" -> {
                    result.success(checkUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    requestUsageStatsPermission()
                    result.success(true)
                }
                "checkSystemAlertPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestSystemAlertPermission" -> {
                    requestSystemAlertPermission()
                    result.success(true)
                }
                "setLockState" -> {
                    val locked = call.argument<Boolean>("locked") ?: false
                    isLocked = locked
                    
                    if (isLocked) {
                        // Close all running apps and clear recent tasks when locked
                        closeAllRunningApps()
                        // Enable stronger notification blocking
                        enableStrongNotificationBlocking()
                    } else {
                        // Remove all blocks when unlocked
                        removeAllBlocks()
                    }
                    result.success(true)
                }
                "bringToFront" -> {
                    bringAppToFront()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun closeAllRunningApps() {
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            
            // Get list of running apps
            val runningApps = am.runningAppProcesses
            
            // Kill all apps except our own
            runningApps?.forEach { processInfo ->
                if (processInfo.processName != packageName) {
                    Process.killProcess(processInfo.pid)
                }
            }
            
            // Clear recent tasks
            am.appTasks.forEach { task ->
                if (task.taskInfo.baseActivity?.packageName != packageName) {
                    task.finishAndRemoveTask()
                }
            }
            
            // Bring our app to front
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // Add notification blocking when locked
    private fun blockNotificationOpening() {
        try {
            // Register activity lifecycle callbacks
            application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
                override fun onActivityStarted(activity: Activity) {
                    if (isLocked && activity.javaClass != MainActivity::class.java) {
                        // If screen is locked and trying to open another app, redirect back to our app
                        val intent = Intent(this@MainActivity, MainActivity::class.java)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        activity.finish()
                    }
                }

                override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
                override fun onActivityResumed(activity: Activity) {}
                override fun onActivityPaused(activity: Activity) {}
                override fun onActivityStopped(activity: Activity) {}
                override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
                override fun onActivityDestroyed(activity: Activity) {}
            })
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null)
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)
        
        val apps = mutableListOf<Map<String, Any>>()
        val resolveInfos = pm.queryIntentActivities(mainIntent, PackageManager.MATCH_ALL)

        resolveInfos.forEach { resolveInfo ->
            try {
                val appInfo = resolveInfo.activityInfo.applicationInfo
                val name = pm.getApplicationLabel(appInfo).toString()
                val packageName = appInfo.packageName
                val icon = appInfo.loadIcon(pm)
                val iconBytes = drawableToByteArray(icon)

                val appData = mapOf(
                    "name" to name,
                    "packageName" to packageName,
                    "icon" to iconBytes
                )
                apps.add(appData)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        return apps
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val width = 48
            val height = 48
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, width, height)
            drawable.draw(canvas)
            bitmap
        }

        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
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

    private fun openHomeSettings() {
        val intent = Intent(Settings.ACTION_HOME_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    private fun checkUsageStatsPermission(): Boolean {
        try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
            return mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun requestUsageStatsPermission() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
            try {
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun requestSystemAlertPermission() {
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            ).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun bringAppToFront() {
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            am.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_WITH_HOME)
            
            // Also bring activity to front
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or 
                          Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun removeAllBlocks() {
        try {
            // Clear window flags
            val window = window
            window.clearFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE)
            window.clearFlags(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE)
            
            // Clear activity lifecycle callbacks
            application.unregisterActivityLifecycleCallbacks(activityLifecycleCallback)
            
            // Allow task switching
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            am.appTasks.forEach { task ->
                task.setExcludeFromRecents(false)
            }
            
            // Reset window parameters
            window.attributes = window.attributes.apply {
                flags = flags and (
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                ).inv()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private val activityLifecycleCallback = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityStarted(activity: Activity) {
            if (isLocked && activity.javaClass != MainActivity::class.java) {
                val intent = Intent(this@MainActivity, MainActivity::class.java)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                activity.finish()
            }
        }

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
        override fun onActivityResumed(activity: Activity) {}
        override fun onActivityPaused(activity: Activity) {}
        override fun onActivityStopped(activity: Activity) {}
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
        override fun onActivityDestroyed(activity: Activity) {}
    }

    private fun enableStrongNotificationBlocking() {
        try {
            // Set as top activity
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            am.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_WITH_HOME)
            
            // Keep app in foreground
            val serviceIntent = Intent(this, MainActivity::class.java)
            serviceIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or 
                                 Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                 Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(serviceIntent)
            
            // Register activity lifecycle callbacks
            application.registerActivityLifecycleCallbacks(activityLifecycleCallback)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
