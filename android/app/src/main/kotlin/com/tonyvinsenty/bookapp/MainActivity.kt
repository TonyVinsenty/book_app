package com.tonyvinsenty.bookapp

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
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
    private var files: MethodChannel? = null

    // Files the app was started with, kept until Dart asks for them;
    // null once it has (later files go straight to Dart).
    private var initialUris: MutableList<Uri>? = mutableListOf()
    private var incomingCount = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        // Each start has its own Dart side, so nothing still uses old copies.
        io.execute { File(cacheDir, "incoming").deleteRecursively() }
        // A restored activity or one opened from Recents carries the old intent.
        val fresh = savedInstanceState == null &&
            intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY == 0
        if (fresh) initialUris?.addAll(incomingUris(intent))
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val uris = incomingUris(intent)
        val waiting = initialUris
        if (waiting != null) {
            // A new intent before Dart asked: the activity was recreated for
            // it, and getIntent() is the task's old root intent (an earlier
            // file, already handled). Only the new one counts.
            waiting.clear()
            waiting.addAll(uris)
            return
        }
        if (uris.isNotEmpty()) sendIncoming(uris)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        files = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, filesChannel)
            .apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "pickBooks" -> pickBooks(result)
                        "hasInitialFiles" -> hasInitialFiles(result)
                        else -> result.notImplemented()
                    }
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

    // Answers at once, so the first screen doesn't wait for big copies;
    // the files follow through onIncomingFiles.
    private fun hasInitialFiles(result: MethodChannel.Result) {
        val uris = initialUris.orEmpty().toList()
        initialUris = null
        result.success(uris.isNotEmpty())
        if (uris.isNotEmpty()) sendIncoming(uris)
    }

    private fun sendIncoming(uris: List<Uri>) {
        io.execute {
            val paths = copyIncoming(uris)
            main.post { files?.invokeMethod("onIncomingFiles", paths) }
        }
    }

    // "Open with" (VIEW) and "Share" (SEND, SEND_MULTIPLE); ADR 0005.
    private fun incomingUris(intent: Intent): List<Uri> = when (intent.action) {
        Intent.ACTION_VIEW -> listOfNotNull(intent.data)
        Intent.ACTION_SEND -> listOfNotNull(
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
        )
        Intent.ACTION_SEND_MULTIPLE -> (
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }
        ).orEmpty().filterNotNull()
        else -> emptyList()
    }

    // Runs on io: each file gets its own folder, as earlier ones may still
    // wait in the Dart import queue (it deletes each copy when done). A file
    // that can't be read still gets a path, with nothing there: the importer
    // then tells the user it couldn't open it.
    private fun copyIncoming(uris: List<Uri>): List<String> {
        val root = File(cacheDir, "incoming")
        return uris.map {
            val dir = File(root, (incomingCount++).toString())
            copy(it, dir) ?: File(dir, displayName(it)).absolutePath
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
        return uris.mapIndexedNotNull { i, uri -> copy(uri, File(root, i.toString())) }
    }

    // Copies into dir/<display name>; null when the file can't be read
    // (a partial copy is removed).
    private fun copy(uri: Uri, dir: File): String? {
        dir.mkdirs()
        val file = File(dir, displayName(uri))
        return try {
            contentResolver.openInputStream(uri)?.use { input ->
                file.outputStream().use { input.copyTo(it) }
                file.absolutePath
            }
        } catch (e: Exception) {
            file.delete()
            null
        }
    }

    private fun displayName(uri: Uri): String {
        val name = try {
            contentResolver.query(
                uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null
            )?.use { if (it.moveToFirst()) it.getString(0) else null }
        } catch (e: Exception) {
            null
        } ?: uri.lastPathSegment
        val safe = name?.replace(Regex("[/\\\\\\u0000]"), "_")?.trim()
        return if (safe.isNullOrEmpty()) "book" else safe
    }
}
