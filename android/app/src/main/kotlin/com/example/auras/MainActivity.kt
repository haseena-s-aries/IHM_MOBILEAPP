package com.example.auras

import android.Manifest
import android.annotation.TargetApi
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "auras/phone_gallery"
    private val storagePermissionRequest = 7301

    // Saves waiting for the storage permission (Android 9 and below only).
    private val pendingSaves = mutableListOf<PendingSave>()

    private data class PendingSave(
        val bytes: ByteArray,
        val fileName: String,
        val folder: String,
        val result: MethodChannel.Result,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName")
                // Relative to the phone's Pictures folder, e.g. "IHM/2026-11-27".
                val folder = call.argument<String>("folder")
                if (bytes == null || fileName.isNullOrBlank() || folder.isNullOrBlank()) {
                    result.error("bad_args", "bytes, fileName and folder are required", null)
                    return@setMethodCallHandler
                }
                saveImage(PendingSave(bytes, fileName, folder, result))
            }
    }

    private fun saveImage(save: PendingSave) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(save)
            return
        }
        // Android 6-9 need the storage permission to write to Pictures.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pendingSaves.add(save)
            if (pendingSaves.size == 1) {
                requestPermissions(
                    arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    storagePermissionRequest,
                )
            }
            return
        }
        saveToLegacyStorage(save)
    }

    // Android 10+: no permission needed for images the app creates.
    @TargetApi(Build.VERSION_CODES.Q)
    private fun saveWithMediaStore(save: PendingSave) {
        try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, save.fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/${save.folder}",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            if (uri == null) {
                save.result.error("save_failed", "Could not create the image in Pictures", null)
                return
            }
            resolver.openOutputStream(uri).use { stream ->
                if (stream == null) throw IllegalStateException("No output stream")
                stream.write(save.bytes)
            }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            save.result.success("${Environment.DIRECTORY_PICTURES}/${save.folder}/${save.fileName}")
        } catch (error: Exception) {
            save.result.error("save_failed", error.message, null)
        }
    }

    private fun saveToLegacyStorage(save: PendingSave) {
        try {
            @Suppress("DEPRECATION")
            val pictures = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_PICTURES,
            )
            val directory = File(pictures, save.folder)
            if (!directory.exists() && !directory.mkdirs()) {
                save.result.error("save_failed", "Could not create ${directory.path}", null)
                return
            }
            val file = File(directory, save.fileName)
            FileOutputStream(file).use { it.write(save.bytes) }
            // Make it appear in the Gallery straight away.
            MediaScannerConnection.scanFile(this, arrayOf(file.path), arrayOf("image/jpeg"), null)
            save.result.success(file.path)
        } catch (error: Exception) {
            save.result.error("save_failed", error.message, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != storagePermissionRequest) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        val saves = pendingSaves.toList()
        pendingSaves.clear()
        for (save in saves) {
            if (granted) {
                saveToLegacyStorage(save)
            } else {
                save.result.error("permission_denied", "Storage permission was denied", null)
            }
        }
    }
}
