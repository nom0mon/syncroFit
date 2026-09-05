package com.example.synchrofit

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "com.synchrofit.app/media_permissions"
        const val CAMERA_PERMISSION_REQUEST = 4101
        const val CAMERA_REQUESTED_PREFERENCE = "camera_permission_requested"
    }

    private var pendingCameraPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkCameraPermission" -> result.success(cameraPermissionStatus())
                    "requestCameraPermission" -> requestCameraPermission(result)
                    "openAppSettings" -> result.success(openAppSettings())
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestCameraPermission(result: MethodChannel.Result) {
        if (pendingCameraPermissionResult != null) {
            result.error(
                "request_in_progress",
                "A camera permission request is already in progress.",
                null,
            )
            return
        }

        if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            result.success("granted")
            return
        }

        pendingCameraPermissionResult = result
        getPreferences(MODE_PRIVATE)
            .edit()
            .putBoolean(CAMERA_REQUESTED_PREFERENCE, true)
            .apply()
        requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CAMERA_PERMISSION_REQUEST) return

        val result = pendingCameraPermissionResult ?: return
        pendingCameraPermissionResult = null
        result.success(cameraPermissionStatus())
    }

    private fun cameraPermissionStatus(): String {
        if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            return "granted"
        }

        val wasRequested = getPreferences(MODE_PRIVATE)
            .getBoolean(CAMERA_REQUESTED_PREFERENCE, false)
        return if (
            wasRequested &&
            !shouldShowRequestPermissionRationale(Manifest.permission.CAMERA)
        ) {
            "permanentlyDenied"
        } else {
            "denied"
        }
    }

    private fun openAppSettings(): Boolean {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", packageName, null),
        )
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
