package com.tonyvinsenty.bookapp

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.provider.OpenableColumns
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.util.concurrent.Executors

// Channel and method names are checked against Dart by test/guards.
class MainActivity : FlutterActivity() {
    private val filesChannel = "com.tonyvinsenty.bookapp/files"
    private val screenChannel = "com.tonyvinsenty.bookapp/screen"
    private val shareChannel = "com.tonyvinsenty.bookapp/share"
    private val pickBooksRequest = 4101
    private val pickFolderRequest = 4102
    private var pendingPick: MethodChannel.Result? = null
    private var pendingFolder: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()

    // Folder listings may be long; incoming files don't wait for them.
    private val folderIo = Executors.newSingleThreadExecutor()
    private var folderCopyCount = 0
    private val maxFolderDepth = 8
    private val main = Handler(Looper.getMainLooper())
    private var files: MethodChannel? = null

    // Files the app was started with, kept until Dart asks for them;
    // null once it has (later files go straight to Dart).
    private var initialUris: MutableList<Uri>? = mutableListOf()
    private var incomingCount = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        // Each start has its own Dart side, so nothing still uses old copies.
        io.execute { File(cacheDir, "incoming").deleteRecursively() }
        folderIo.execute { File(cacheDir, "folders").deleteRecursively() }
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
                        "pickFolder" -> pickFolder(result)
                        "listFolder" -> listFolder(call.arguments as String, result)
                        "copyFolderFiles" -> copyFolderFiles(
                            call.argument<String>("ref")!!,
                            call.argument<List<String>>("keys").orEmpty(),
                            result,
                        )
                        "releaseFolder" -> releaseFolder(call.arguments as String, result)
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareFile" -> shareFile(
                        call.argument<String>("path")!!,
                        call.argument<String>("mime")!!,
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    // The file is in the cache's share/ folder (res/xml/share_paths.xml);
    // the receiving app gets read access to it for the chooser's lifetime.
    private fun shareFile(path: String, mime: String, result: MethodChannel.Result) {
        try {
            val uri = FileProvider.getUriForFile(this, "$packageName.share", File(path))
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = ClipData.newRawUri(null, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(send, null)
            // Not back into this app: it would only open the same book.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                chooser.putExtra(
                    Intent.EXTRA_EXCLUDE_COMPONENTS,
                    arrayOf(ComponentName(this, MainActivity::class.java)),
                )
            }
            startActivity(chooser)
            result.success(null)
        } catch (e: Exception) {
            result.error("share", e.message, null)
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
        if (requestCode == pickFolderRequest) {
            folderPicked(if (resultCode == Activity.RESULT_OK) data?.data else null)
            return
        }
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

    // ADR 0007: a picked folder is its tree URI with a lasting read
    // permission. Android 11+ won't offer the storage root or Downloads.
    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingFolder != null) {
            result.error("busy", "A folder picker is already open", null)
            return
        }
        pendingFolder = result
        try {
            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), pickFolderRequest)
        } catch (e: ActivityNotFoundException) {
            pendingFolder = null
            result.error("unavailable", "No folder picker", null)
        }
    }

    private fun folderPicked(tree: Uri?) {
        val result = pendingFolder ?: return
        pendingFolder = null
        if (tree == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(tree, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (e: SecurityException) {
            result.error("denied", e.message, null)
            return
        }
        folderIo.execute {
            val name = folderName(tree)
            main.post { result.success(mapOf("ref" to tree.toString(), "name" to name)) }
        }
    }

    private fun folderName(tree: Uri): String {
        val id = DocumentsContract.getTreeDocumentId(tree)
        val name = try {
            contentResolver.query(
                DocumentsContract.buildDocumentUriUsingTree(tree, id),
                arrayOf(Document.COLUMN_DISPLAY_NAME), null, null, null
            )?.use { if (it.moveToFirst()) it.getString(0) else null }
        } catch (e: Exception) {
            null
        }
        return name ?: id.substringAfterLast('/').substringAfter(':')
    }

    // Any failure is "lost": the permission or the folder is gone.
    private fun listFolder(ref: String, result: MethodChannel.Result) {
        folderIo.execute {
            val files = try {
                listTree(Uri.parse(ref))
            } catch (e: Exception) {
                null
            }
            main.post {
                if (files != null) result.success(mapOf("files" to files))
                else result.error("lost", "No access to the folder", null)
            }
        }
    }

    // Book files of the tree, subfolders included (8 levels, as in Dart),
    // one query per folder; hidden files and folders are skipped. The key
    // is the document id, which is what copyFolderFiles takes.
    private fun listTree(tree: Uri): List<Map<String, Any>> {
        val granted = contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isReadPermission
        }
        if (!granted) throw SecurityException("No permission for $tree")
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val exists = contentResolver.query(
            DocumentsContract.buildDocumentUriUsingTree(tree, rootId),
            arrayOf(Document.COLUMN_DOCUMENT_ID), null, null, null
        )?.use { it.moveToFirst() } ?: false
        if (!exists) throw FileNotFoundException(rootId)
        val columns = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE,
            Document.COLUMN_SIZE,
            Document.COLUMN_LAST_MODIFIED,
        )
        val files = mutableListOf<Map<String, Any>>()
        val dirs = ArrayDeque(listOf(rootId to 0))
        while (dirs.isNotEmpty()) {
            val (dir, depth) = dirs.removeFirst()
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, dir)
            val cursor = contentResolver.query(children, columns, null, null, null)
                ?: throw FileNotFoundException(dir)
            cursor.use {
                while (it.moveToNext()) {
                    val id = it.getString(0)
                    val name = it.getString(1)
                    if (id == null || name == null || name.startsWith(".")) {
                        // Hidden, or nothing to go by.
                    } else if (it.getString(2) == Document.MIME_TYPE_DIR) {
                        if (depth < maxFolderDepth) dirs.add(id to depth + 1)
                    } else if (isBookName(name)) {
                        files.add(
                            mapOf(
                                "key" to id,
                                "name" to name,
                                "size" to (if (it.isNull(3)) 0L else it.getLong(3)),
                                "modified" to (if (it.isNull(4)) 0L else it.getLong(4)),
                            )
                        )
                    }
                }
            }
        }
        return files
    }

    // As isBookFileName in Dart; the importer tells the format by content.
    private fun isBookName(name: String): Boolean {
        val lower = name.lowercase()
        return listOf(".fb2", ".epub", ".txt", ".zip").any {
            lower.endsWith(it) && lower.length > it.length
        }
    }

    // Copies into cacheDir/folders/<n>/<display name>, each file in its own
    // folder (the Dart import queue deletes it when done); one that can't be
    // read gets a path with nothing there.
    private fun copyFolderFiles(ref: String, keys: List<String>, result: MethodChannel.Result) {
        folderIo.execute {
            val tree = Uri.parse(ref)
            val root = File(cacheDir, "folders")
            val paths = keys.map {
                val uri = DocumentsContract.buildDocumentUriUsingTree(tree, it)
                val dir = File(root, (folderCopyCount++).toString())
                copy(uri, dir) ?: File(dir, displayName(uri)).absolutePath
            }
            main.post { result.success(paths) }
        }
    }

    private fun releaseFolder(ref: String, result: MethodChannel.Result) {
        try {
            contentResolver.releasePersistableUriPermission(
                Uri.parse(ref), Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (e: SecurityException) {
            // Not held any more.
        }
        result.success(null)
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
