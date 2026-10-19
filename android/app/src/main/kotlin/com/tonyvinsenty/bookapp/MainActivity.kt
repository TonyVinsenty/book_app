package com.tonyvinsenty.bookapp

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

// Channel and method names are checked against Dart by test/guards.
class MainActivity : FlutterActivity() {
    private val filesChannel = "com.tonyvinsenty.bookapp/files"
    private val screenChannel = "com.tonyvinsenty.bookapp/screen"
    private val pickBooksRequest = 4101
    private var pendingPick: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, filesChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickBooks" -> pickBooks(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setKeepOn" -> {
                        val flag = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        if (call.arguments == true) window.addFlags(flag) else window.clearFlags(flag)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickBooks(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "A file picker is already open", null)
            return
        }
        pendingPick = result
        // FB2 has no standard MIME type, so every file is offered.
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        startActivityForResult(intent, pickBooksRequest)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickBooksRequest) return
        val result = pendingPick ?: return
        pendingPick = null
        val uris = if (resultCode == Activity.RESULT_OK) pickedUris(data) else emptyList()
        io.execute {
            val paths = copyToCache(uris)
            main.post { result.success(paths) }
        }
    }

    private fun pickedUris(data: Intent?): List<Uri> {
        val clip = data?.clipData
        if (clip != null) return (0 until clip.itemCount).map { clip.getItemAt(it).uri }
        return listOfNotNull(data?.data)
    }

    // Copies into cacheDir/picked/<n>/<display name>; files that can't be
    // read are skipped. The previous pick is removed first.
    private fun copyToCache(uris: List<Uri>): List<String> {
        val root = File(cacheDir, "picked")
        root.deleteRecursively()
        return uris.mapIndexedNotNull { i, uri ->
            try {
                val dir = File(root, i.toString()).apply { mkdirs() }
                val file = File(dir, displayName(uri))
                contentResolver.openInputStream(uri)?.use { input ->
                    file.outputStream().use { input.copyTo(it) }
                } ?: return@mapIndexedNotNull null
                file.absolutePath
            } catch (e: Exception) {
                null
            }
        }
    }

    private fun displayName(uri: Uri): String {
        val name = contentResolver.query(
            uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null
        )?.use { if (it.moveToFirst()) it.getString(0) else null }
        val safe = name?.replace(Regex("[/\\\\\\u0000]"), "_")?.trim()
        return if (safe.isNullOrEmpty()) "book" else safe
    }
}
